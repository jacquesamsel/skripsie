import tensordict

from environment import RoboRacerParallelEnvs
from model import load_model
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


def get_xy(model, split_data):
    trunk = model.get_trunk_operator()
    with torch.inference_mode():
        x = torch.cat([
            trunk(split_data[i:i + FORWARD_CHUNK_SIZE].select(*trunk.in_keys))["hidden_layer"]
            for i in range(0, len(split_data), FORWARD_CHUNK_SIZE)
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
                num_steps=2048,
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



    ITERATIONS = [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 150, 200, 250, 300, 350, 400, 450, 500, 550, 600]
    MODEL_NAMES = os.listdir("checkpoints")

    all_scores = []

    trainings_to_do = [
        (get_iter_name(iteration), model_name) for iteration in ITERATIONS for model_name in MODEL_NAMES
    ]

    # spawn, not fork: forking after the parent has run torch ops (e.g. the
    # rollout above) deadlocks the workers on the inherited OpenMP state
    with ProcessPoolExecutor(
            max_workers=NUM_WORKERS,
            mp_context=mp.get_context("spawn"),
            initializer=init_worker) as executor:
        for scores in tqdm.tqdm(executor.map(score_checkpoint, trainings_to_do), total=len(trainings_to_do)):
            if scores is not None:
                all_scores.append(scores)

    scores = pd.concat(all_scores, ignore_index=True)
    scores.to_csv("results/aux_head_regression_scores.csv", index=False)
