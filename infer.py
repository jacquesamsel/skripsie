import csv
import itertools
import math

import torch
from collections import deque
from typing import Callable
import time
import tensordict as td
from matplotlib import pyplot as plt
from torchrl.envs.utils import ExplorationType, set_exploration_type
from torchrl.objectives.value import GAE

from environment import make_envs
from model import ActorValueAuxOperator, make_model

# curl -F "reqtype=fileupload" -F "time=24h" -F "fileToUpload=@Archiv.zip" https://litterbox.catbox.moe/resources/internals/api.php

# Must match train.py's gamma/lmbda -- not stored in the checkpoint, so kept in sync by hand.
GAMMA = 0.99
LMBDA = 0.95


def discounted_return(rewards: torch.Tensor, gamma: float) -> float:
    """Backward-accumulated discounted return from realised rewards (no bootstrap).

    The ground-truth counterpart to the GAE value_target: compare the two to see
    whether the critic's return estimate is actually calibrated to what happened.
    """
    g = 0.0
    for r in reversed(rewards.tolist()):
        g = r + gamma * g
    return g


def run_rollout(
    model: ActorValueAuxOperator,
    env,
    tensordict: td.TensorDict,
    num_steps: int | None = None,
    on_step: Callable[[td.TensorDict], None] | None = None,
) -> td.TensorDict:
    """Runs the policy deterministically and returns the stacked rollout.

    num_steps=None runs until interrupted (e.g. KeyboardInterrupt from a caller
    doing live visualisation); on_step, if given, is called with each step's
    tensordict as it's produced (e.g. to feed a Visualiser).
    """
    steps = []
    with torch.no_grad(), set_exploration_type(ExplorationType.DETERMINISTIC):
        for _ in itertools.count() if num_steps is None else range(num_steps):
            step_result = env.step(model.get_policy_operator()(tensordict))
            steps.append(step_result)
            if on_step is not None:
                on_step(step_result)
            tensordict = env.step_mdp(step_result)
    return torch.stack(steps, dim=0)


def rollout_stats(rollout: td.TensorDict) -> dict[str, float]:
    """Summary stats for a rollout from run_rollout, mirroring train.py's reward/* logs."""
    return {
        "reward_mean": rollout["next", "agents", "reward"].mean().item(),
        "velocity_forward_mean": rollout["agents", "velocity_forward"].mean().item(),
        "progress_mean": rollout["agents", "progress"].mean().item(),
        "collision_rate": rollout["agents", "terminated"].float().mean().item(),
    }


def plot_observation_histograms(rollout: td.TensorDict, obs_keys, bins: int = 50,
                                 out_path: str = "obs_histograms.png"):
    """One histogram per observation leaf (as declared by env.observation_spec),
    flattened over every batch dim (time, env, agent, ...)."""
    cols = 4
    rows = math.ceil(len(obs_keys) / cols)
    fig, axes = plt.subplots(rows, cols, figsize=(4 * cols, 3 * rows), squeeze=False)

    for ax, key in zip(axes.flat, obs_keys):
        full_key = ("next", *key) if isinstance(key, tuple) else ("next", key)
        values = rollout[full_key].flatten().numpy()
        ax.hist(values, bins=bins)
        ax.set_title(key if isinstance(key, str) else ".".join(key))
    for ax in axes.flat[len(obs_keys):]:
        ax.axis("off")

    fig.tight_layout()
    fig.savefig(out_path)
    plt.show()


if __name__ == "__main__":
    checkpoint = torch.load("checkpoints/conv1d.pt", map_location="cpu")
    model_config = checkpoint["model_config"]

    num_envs = 1
    num_agents_per_env = 1
    env = make_envs(
        num_envs=num_envs,
        num_agents_per_env=num_agents_per_env,
        time_scale=1.0,
        num_stacked_frames=model_config["num_stacked_lidar_frames"],
        width=1280,
        height=720,
    )
    tensordict = env.reset()

    model = make_model(**model_config)
    model.load_state_dict(checkpoint["model"])

    obs_keys = list(env.observation_spec.keys(True, True))
    collected_steps = []

    start_time = time.perf_counter_ns()
    frame_count = 0

    def count_frame(step_result: td.TensorDict):
        global frame_count
        frame_count += 1
        collected_steps.append(step_result)

    try:
        run_rollout(model, env, tensordict, num_steps=None, on_step=count_frame)
    except KeyboardInterrupt:
        pass
    finally:
        env.close()
        end_time = time.perf_counter_ns()
        print(f"ms per frame: {(end_time - start_time) / (frame_count * 1e6)}")
        if collected_steps:
            plot_observation_histograms(torch.stack(collected_steps, dim=0), obs_keys)
