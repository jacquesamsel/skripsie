import tensordict

from environment import RoboRacerParallelEnvs
from model import is_recurrent, load_model
import torch
from infer import do_rollout
import os
from utils import AUX_HEAD_KEYS
from sklearn.linear_model import LinearRegression
import pandas as pd
from sklearn.model_selection import train_test_split
# import seaborn as sns
from sklearn.metrics import r2_score, mean_absolute_error
from matplotlib import pyplot as plt
import math
import platform
from pathlib import Path
import tqdm
from concurrent.futures import ProcessPoolExecutor
import multiprocessing as mp


torch.set_num_threads(32)
TRAIN_PATH = "results/baseline_rollout_train.pt"
TEST_PATH = "results/baseline_rollout_test.pt"
TRAIN_PROP = 0.8
# Steps per agent in the saved rollouts. They are saved flat in time-major
# order, (T * n_agents), so this is needed to recover each agent's trajectory
ROLLOUT_STEPS = 2048
# The forward passes are bound by cache/memory bandwidth rather than cores, so
# more workers past this point slows things down (measured: 32x2 ~0.56s/job,
# 64x1 ~0.81s/job on the 64-core Threadripper)
NUM_WORKERS = 32
THREADS_PER_WORKER = 2
# Forward in small chunks so each worker's activations stay in cache, rather
# than allocating GBs per pass and contending for memory bandwidth
FORWARD_CHUNK_SIZE = 256

_train_data = None
_test_data = None


def init_worker():
    # mmap so every worker reads the same page-cached copy instead of each
    # holding its own ~1.3 GB
    global _train_data, _test_data
    torch.set_num_threads(THREADS_PER_WORKER)
    torch.serialization.add_safe_globals(
        [tensordict._td.TensorDict, tensordict._reductions._make_td])
    _train_data = torch.load(TRAIN_PATH, mmap=True)
    _test_data = torch.load(TEST_PATH, mmap=True)


def episode_starts(split_data) -> torch.Tensor:
    """(n_agents, T, 1) bool, True on the first step of each episode.

    The saved rollouts don't store done flags, but CatFramesResetOnDone flushes
    the lidar stack on the first step of a new episode. Otherwise every step
    shifts the stack along by exactly one frame, so a step whose stack isn't the
    previous one shifted along is an episode start. The first step is one too,
    as do_rollout starts from an env.reset()."""
    lidar = split_data["agents", "stacked_lidar"]
    lidar = lidar.reshape(ROLLOUT_STEPS, -1, *lidar.shape[1:])
    shifted = (lidar[1:, :, :-1] == lidar[:-1, :, 1:]).flatten(2).all(-1)
    is_init = torch.cat(
        [torch.ones_like(shifted[:1]), ~shifted], dim=0)  # (T, n_agents)
    return is_init.T.unsqueeze(-1)


def get_trunk_input(model, split_data):
    """The observations the trunk reads, cut down to its lidar stack length.

    The rollouts were collected with a longer lidar stack than some models use
    (e.g. the recurrent ones), so keep only the newest frames, which are last."""
    n_frames = model.get_trunk_operator().module.encoder.num_stacked_lidar_frames \
        if is_recurrent(model) else model.get_trunk_operator().module.num_stacked_lidar_frames
    obs = split_data.select(("agents", "stacked_lidar"),
                            ("agents", "steering_angle"), ("agents", "throttle"))
    obs["agents", "stacked_lidar"] = obs["agents", "stacked_lidar"][..., -n_frames:, :]
    return obs


def get_hidden_layer_recurrent(model, split_data):
    """Unrolls the GRU over each agent's whole rollout, resetting it between
    episodes, and returns hidden_layer in split_data's (time-major) order."""
    trunk = model.get_trunk_operator()
    hidden_size = trunk.module.hidden_size
    # split_data is (T * n_agents) in time-major order; the trunk wants time as
    # the last batch dim, so make it (n_agents, T)
    obs = get_trunk_input(model, split_data)
    obs = obs.reshape(ROLLOUT_STEPS, -1).permute(1, 0)
    obs["is_init"] = episode_starts(split_data)
    n_agents = obs.shape[0]

    # Unroll in chunks of time, carrying the GRU state across them
    h = torch.zeros(n_agents, hidden_size)
    chunk_len = max(1, FORWARD_CHUNK_SIZE // n_agents)
    outs = []
    for t in range(0, ROLLOUT_STEPS, chunk_len):
        chunk = obs[:, t:t + chunk_len].clone()
        # only rnn_h[:, 0] is read, as the state before the chunk's first step
        chunk["rnn_h"] = h.unsqueeze(1).expand(-1, chunk.shape[1], -1)
        chunk = trunk(chunk)
        h = chunk["rnn_h_out"][:, -1]
        outs.append(chunk["hidden_layer"])
    # back to (T, n_agents) -> (T * n_agents) to line up with the targets
    return torch.cat(outs, dim=1).transpose(0, 1).reshape(-1, hidden_size)


def get_xy(model, split_data):
    trunk = model.get_trunk_operator()
    with torch.inference_mode():
        if is_recurrent(model):
            x = get_hidden_layer_recurrent(model, split_data).numpy()
        else:
            obs = get_trunk_input(model, split_data)
            x = torch.cat([
                trunk(obs[i:i + FORWARD_CHUNK_SIZE])["hidden_layer"]
                for i in range(0, len(obs), FORWARD_CHUNK_SIZE)
            ]).numpy()
    y = pd.DataFrame({
        key: split_data[("agents", key)].numpy().flatten() for key in AUX_HEAD_KEYS
    })
    return x, y


def score_checkpoint(job: tuple[str, str]) -> pd.DataFrame | None:
    iter_name, model_name = job
    weights_file_name = f"iteration_{iter_name}.pt"
    model_path = Path("checkpoints") / model_name / weights_file_name

    if not model_path.exists():
        print(
            f"Checkpoint for {model_name} at iteration {iter_name} not found.")
        return None

    model, model_config, _, _ = load_model(model_path)

    # Do forward pass to get the aux head outputs
    train_x, train_y = get_xy(model, _train_data)
    test_x, test_y = get_xy(model, _test_data)

    lr = LinearRegression(n_jobs=32)
    lr.fit(train_x, train_y)

    test_y_hat = lr.predict(test_x)

    return pd.DataFrame({
        "model_name": model_name,
        "target": test_y.columns,
        "iteration": int(iter_name),
        "r2_score": [r2_score(test_y.iloc[:, i], test_y_hat[:, i]) for i in range(len(test_y.columns))],
        "mae": [mean_absolute_error(test_y.iloc[:, i], test_y_hat[:, i]) for i in range(len(test_y.columns))],
        "target_stddev": [test_y.iloc[:, i].std() for i in range(len(test_y.columns))],
    })


if __name__ == "__main__":
    if not (os.path.exists(TRAIN_PATH) and os.path.exists(TEST_PATH)):
        is_mac = platform.system() == "Darwin"
        try:
            model, model_config, _, _ = load_model(
                "checkpoints/baseline_w0_s0/iteration_00600.pt")
            env = RoboRacerParallelEnvs(
                num_envs=8,
                time_scale=100.0,
                file_name="TestUnityProject/Test speed/build.app" if is_mac else "linux_build/linux_build.x86_64",
                num_stacked_frames=model_config["num_stacked_lidar_frames"],
                no_graphics=True,
                num_areas=4,
                seed=0
            )

            data = do_rollout(
                env,
                model,
                num_steps=ROLLOUT_STEPS,
                select_keys=[*[("agents", key) for key in ["stacked_lidar", "steering_angle", "throttle", *AUX_HEAD_KEYS]]])
            # (n_steps, num_envs, num_areas) -> (n_steps, n_agents), so each car is
            # wholly in either train or test and the split doesn't leak trajectories
            data = data.reshape(data.shape[0], -1)
            n_agents = data.shape[1]
            agent_perm = torch.randperm(
                n_agents, generator=torch.Generator().manual_seed(0))
            n_train_agents = int(n_agents * TRAIN_PROP)

            print(f"Train agents: {n_train_agents} / {n_agents}")
            train_data = data[:, agent_perm[:n_train_agents]].reshape(-1)
            test_data = data[:, agent_perm[n_train_agents:]].reshape(-1)
            for split_data, split_path in [(train_data, TRAIN_PATH), (test_data, TEST_PATH)]:
                torch.save(split_data, split_path)
                print(
                    f"Saved {len(split_data)} steps to {split_path}, {split_data.bytes() / 1024 / 1024:.2f} MB")
        except KeyboardInterrupt:
            pass
        finally:
            env.close()

    def get_iter_name(i: int):
        return f"{i:05d}"

    ITERATIONS = [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100,
                  150, 200, 250, 300, 350, 400, 450, 500, 550, 600]
    COMPLETED_MODELS = []
    existing_scores = pd.DataFrame()
    if os.path.exists("results/aux_head_regression_scores.csv"):
        existing_scores = pd.read_csv("results/aux_head_regression_scores.csv")
        COMPLETED_MODELS = existing_scores["model_name"].unique().tolist()
        print(
            f"Found {len(COMPLETED_MODELS)} completed models: {COMPLETED_MODELS}")
    MODEL_NAMES = set(f for f in os.listdir("checkpoints")
                      if f not in COMPLETED_MODELS)

    all_scores = []

    trainings_to_do = [
        (get_iter_name(iteration), model_name) for iteration in ITERATIONS for model_name in MODEL_NAMES
    ]
    print(trainings_to_do)

    with ProcessPoolExecutor(
            max_workers=NUM_WORKERS,
            mp_context=mp.get_context("spawn"),
            initializer=init_worker) as executor:
        for scores in tqdm.tqdm(executor.map(score_checkpoint, trainings_to_do), total=len(trainings_to_do)):
            if scores is not None:
                all_scores.append(scores)

    scores = pd.concat([existing_scores] + all_scores,
                       ignore_index=True)   # <-- include old rows
    scores.to_csv("results/aux_head_regression_scores.csv", index=False)
