import os
from itertools import groupby

import torch
from tqdm import tqdm
import platform

from environment import RoboRacerParallelEnvs
from model import advance_recurrent_state, initial_recurrent_state, load_model, step_operator

MODELS = sorted(["curvature_close_w1_s1"])
ITERATIONS = [600]
NUM_STEPS = 1500
NUM_ENVS = 1  # Unity processes run side by side
NUM_AREAS = 1  # separate sims inside each Unity process
NUM_SLOTS = NUM_ENVS * NUM_AREAS  # each (env, area) slot runs its own checkpoint
OUT_DIR = "results/trajectories"

# Lidar is dropped to keep the saved files small. rnn_h/rnn_h_out are the
# recurrent state, which isn't part of the trajectory either.
EXCLUDE_KEYS = [
    ("agents", "lidar"), ("agents", "stacked_lidar"),
    ("next", "agents", "lidar"), ("next", "agents", "stacked_lidar"),
    "rnn_h", "rnn_h_out", "is_init",
]


def checkpoint_path(model_name: str, iteration: int) -> str:
    return f"checkpoints/{model_name}/iteration_{iteration:05d}.pt"


def out_path(model_name: str, iteration: int) -> str:
    return f"{OUT_DIR}/{model_name}_{iteration:05d}.pt"


def rollout(env: RoboRacerParallelEnvs, models: list) -> list:
    """Runs models[k] in slot k (env k // NUM_AREAS, area k % NUM_AREAS) and
    returns one (NUM_STEPS, 1) trajectory per model."""
    tensordict = env.reset()  # (NUM_ENVS, NUM_AREAS)
    states = [initial_recurrent_state(model, torch.Size([1])) for model in models]
    policies = [model.get_policy_operator() for model in models]
    trajectories = [[] for _ in models]
    with torch.no_grad():
        for _ in range(NUM_STEPS):
            # Flatten (env, area) into slots, so slot k is just row k
            flat = tensordict.reshape(-1)
            # Each model acts on its own slot. The models can output different
            # extra keys (rnn state, hidden sizes), so only the actions are
            # stitched back into the batch the env steps on.
            outputs = [step_operator(policy, flat[k:k + 1], states[k])
                       for k, policy in enumerate(policies)]
            actions = torch.cat([o["action"] for o in outputs])
            tensordict.set("action", actions.reshape(NUM_ENVS, NUM_AREAS))
            tensordict = env.step(tensordict)
            next_flat = tensordict["next"].reshape(-1)
            for k, output in enumerate(outputs):
                output.set("next", next_flat[k:k + 1])
                states[k] = advance_recurrent_state(states[k], output)
                trajectories[k].append(output.exclude(*EXCLUDE_KEYS))
            tensordict = env.step_mdp(tensordict)
    return [torch.stack(steps, dim=0) for steps in trajectories]


def main():
    checkpoints = [(m, i) for m in MODELS for i in ITERATIONS]
    missing = [checkpoint_path(*c) for c in checkpoints if not os.path.exists(checkpoint_path(*c))]
    if missing:
        raise FileNotFoundError(f"Missing checkpoints: {missing}")
    os.makedirs(OUT_DIR, exist_ok=True)
    # Skip finished ones, so the script resumes after a crash
    todo = [c for c in checkpoints if not os.path.exists(out_path(*c))]

    # Every slot shares one lidar frame-stack size, so group checkpoints by it
    loaded = []
    for c in tqdm(todo, desc="loading"):
        model, config, _, _ = load_model(checkpoint_path(*c))
        loaded.append((c, model.eval(), config["num_stacked_lidar_frames"]))
    loaded.sort(key=lambda x: x[2])

    for frames, group in groupby(loaded, key=lambda x: x[2]):
        group = list(group)
        env = RoboRacerParallelEnvs(
            num_envs=NUM_ENVS,
            file_name=None,
            #file_name="linux_build/linux_build.x86_64" if platform.system() != "Darwin" else "TestUnityProject/Test speed/build.app",
            num_stacked_frames=frames,
            num_areas=NUM_AREAS,
            no_graphics=True,
            time_scale=2.0,
        )
        try:
            for start in tqdm(range(0, len(group), NUM_SLOTS), desc=f"{frames} frames"):
                chunk = group[start:start + NUM_SLOTS]
                # Pad the last chunk so every slot has a model; padding isn't saved
                models = [m for _, m, _ in chunk]
                models += [models[-1]] * (NUM_SLOTS - len(models))
                for (c, _, _), trajectory in zip(chunk, rollout(env, models)):
                    torch.save(trajectory, out_path(*c))
        finally:
            env.close()


if __name__ == "__main__":
    main()
