import itertools
import math
import platform
import time
from typing import Callable

import pandas as pd
import tensordict as td
import torch
from matplotlib import pyplot as plt
from torchrl.envs.utils import ExplorationType, set_exploration_type

from environment import RoboRacerEnv
from model import ActorValueAuxOperator, make_model
from visualize import LidarVisualiser, RewardVisualiser

# curl -F "reqtype=fileupload" -F "time=24h" -F "fileToUpload=@Archiv.zip" https://litterbox.catbox.moe/resources/internals/api.php

# Must match train.py's gamma/lmbda -- not stored in the checkpoint, so kept in sync by hand.
GAMMA = 0.995
LMBDA = 0.97


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
    lidar_visualiser = LidarVisualiser()
    reward_visualiser = RewardVisualiser(gamma=GAMMA)
    with torch.no_grad(), set_exploration_type(ExplorationType.DETERMINISTIC):
        for _ in itertools.count() if num_steps is None else range(num_steps):
            step_result = env.step(model.get_policy_operator()(tensordict))
            lidar_visualiser.render(step_result[("agents", "stacked_lidar")])
            reward_visualiser.render(step_result[("next", "agents", "reward")], step_result[("next", "agents", "done")])
            steps.append(step_result)
            if on_step is not None:
                on_step(step_result)
            tensordict = env.step_mdp(step_result)
    return torch.stack(steps, dim=0)


def scalar_observation_keys(env) -> list[td.NestedKey]:
    """The ("agents", ...) observation leaves that hold one number per car.

    Read off the spec rather than hand-listed, because environment.py's
    SplitVector layout is the one place the vector observation's contents are
    named: a lookahead distance or a wheel-slip channel added there becomes a
    column here without infer.py having to be touched. The scalars are picked
    out by rank -- a per-car scalar is (*batch_size, 1), where the lidar carries
    two further dims (frames, rays) -- which also drops the lidar without
    having to name it.
    """
    spec = env.observation_spec
    return [
        key for key in spec.keys(True, True)
        # keys(True, True) yields a bare string for a leaf at the top level and
        # a tuple only for a nested one, so the isinstance check comes first --
        # key[0] on a string would compare its first character
        if isinstance(key, tuple) and key[0] == "agents"
        and spec[key].ndim == len(env.batch_size) + 1
        and spec[key].shape[-1] == 1
    ]


if __name__ == "__main__":
    checkpoint = torch.load("checkpoints/conv1d_try_3_no_norm.pt", map_location="cpu")
    model_config = checkpoint["model_config"]

    is_mac = platform.system() == "Darwin"
    env = RoboRacerEnv(
        file_name="TestUnityProject/Test speed/build.app" if is_mac
        else "linux_build/linux_build.x86_64",
        num_stacked_frames=model_config["num_stacked_lidar_frames"],
        # Watched rather than raced: graphics on, and the engine held to
        # wall-clock time, so the ms/frame printed below is the real per-step
        # cost of driving one car rather than a figure inflated by time_scale.
        no_graphics=False,
        time_scale=1.0,
        num_areas=1,
        seed=43,
    )
    tensordict = env.reset()

    model = make_model(**model_config)
    model.load_state_dict(checkpoint["model"])

    obs_keys = scalar_observation_keys(env)
    collected_steps: list[td.TensorDict] = []

    start_time = time.perf_counter_ns()

    try:
        run_rollout(model, env, tensordict,
                    on_step=collected_steps.append)
    except KeyboardInterrupt:
        pass
    finally:
        env.close()
        end_time = time.perf_counter_ns()
        # on_step collects as it goes, so an interrupted run still writes out
        # the steps it did get through instead of losing the lot
        if collected_steps:
            print(f"ms per frame: "
                  f"{(end_time - start_time) / (len(collected_steps) * 1e6)}")

            rollout = torch.stack(collected_steps, dim=0)
