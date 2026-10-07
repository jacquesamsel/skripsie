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
import pandas as pd

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


def plot_observation_histograms(rollout: td.TensorDict, obs_keys, bins: int = 50,
                                out_path: str = "obs_histograms.png"):
    """One histogram per observation leaf (as declared by env.observation_spec),
    flattened over every batch dim (time, env, agent, ...)."""
    cols = 4
    rows = math.ceil(len(obs_keys) / cols)
    fig, axes = plt.subplots(rows, cols, figsize=(
        4 * cols, 3 * rows), squeeze=False)

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
        steps = run_rollout(model, env, tensordict,
                            num_steps=1000, on_step=count_frame)
    except KeyboardInterrupt:
        pass
    finally:
        env.close()
        end_time = time.perf_counter_ns()
        print(f"ms per frame: {(end_time - start_time) / (frame_count * 1e6)}")
        # agents group is batched over (env, agent); both are fixed to size 1 in
        # this script (num_envs=1, num_agents_per_env=1), and lidar additionally
        # carries a size-1 frame dim from UnsqueezeTransform -- squeeze() drops
        # all of those, leaving (num_steps,) for scalar fields and
        # (num_steps, n_components) for vector fields, regardless of exactly how
        # many size-1 batch dims the env wrapper produced.
        agents = steps["agents"]

        def feat(key):
            return agents[key].squeeze()

        pos = feat("pos")
        wheel_ticks = feat("wheel_ticks")
        wheel_angles = feat("wheel_angles")
        orientation_quaternion = feat("orientation_quaternion")
        euler_angles = feat("euler_angles")
        linear_acceleration = feat("linear_acceleration")
        wheel_slips = feat("wheel_slips")  # (num_steps, 4, 2): FL, FR, RL, RR
        curvature = feat("curvature")  # (num_steps, 3): 0.5m, 1.0m, 2.0m lookahead

        # lidar block layout is [Tag_1, Tag_2, Miss, Distance] (see LIDAR_BLOCK
        # in environment.py) -- index -1 selects the distance channel.
        lidar_distance = agents["lidar"].squeeze()[:, -1, :]

        df = pd.DataFrame({
            "speed": feat("speed").numpy(),
            "cur_steering_angle": feat("cur_steering_angle").numpy(),
            "cur_throttle": feat("cur_throttle").numpy(),
            "pos_x": pos[:, 0].numpy(),
            "pos_y": pos[:, 1].numpy(),
            "pos_z": pos[:, 2].numpy(),
            "wheel_ticks_left": wheel_ticks[:, 0].numpy(),
            "wheel_ticks_right": wheel_ticks[:, 1].numpy(),
            "wheel_angle_left": wheel_angles[:, 0].numpy(),
            "wheel_angle_right": wheel_angles[:, 1].numpy(),
            "orientation_quaternion_x": orientation_quaternion[:, 0].numpy(),
            "orientation_quaternion_y": orientation_quaternion[:, 1].numpy(),
            "orientation_quaternion_z": orientation_quaternion[:, 2].numpy(),
            "orientation_quaternion_w": orientation_quaternion[:, 3].numpy(),
            "euler_angle_x": euler_angles[:, 0].numpy(),
            "euler_angle_y": euler_angles[:, 1].numpy(),
            "euler_angle_z": euler_angles[:, 2].numpy(),
            "angular_velocity_x": feat("angular_velocity_x").numpy(),
            "angular_velocity_z": feat("angular_velocity_z").numpy(),
            "yaw_rate": feat("yaw_rate").numpy(),
            "linear_acceleration_x": linear_acceleration[:, 0].numpy(),
            "linear_acceleration_y": linear_acceleration[:, 1].numpy(),
            "linear_acceleration_z": linear_acceleration[:, 2].numpy(),
            "wheel_slip_fl_forward": wheel_slips[:, 0, 0].numpy(),
            "wheel_slip_fl_sideways": wheel_slips[:, 0, 1].numpy(),
            "wheel_slip_fr_forward": wheel_slips[:, 1, 0].numpy(),
            "wheel_slip_fr_sideways": wheel_slips[:, 1, 1].numpy(),
            "wheel_slip_rl_forward": wheel_slips[:, 2, 0].numpy(),
            "wheel_slip_rl_sideways": wheel_slips[:, 2, 1].numpy(),
            "wheel_slip_rr_forward": wheel_slips[:, 3, 0].numpy(),
            "wheel_slip_rr_sideways": wheel_slips[:, 3, 1].numpy(),
            "velocity_forward": feat("velocity_forward").numpy(),
            "velocity_lateral": feat("velocity_lateral").numpy(),
            "progress": feat("progress").numpy(),
            "curvature_0_5m": curvature[:, 0].numpy(),
            "curvature_1_0m": curvature[:, 1].numpy(),
            "curvature_2_0m": curvature[:, 2].numpy(),
            **{f"lidar_{ray_idx}": lidar_distance[:, ray_idx].numpy() for ray_idx in range(lidar_distance.shape[-1])},
        })
        df.to_csv("rollout_data.csv", index=False)
        df.describe().to_csv("rollout_summary.csv")
