import platform
import time

import pandas as pd
import tensordict as td
import torch
from utils import get_aux_head_true_values
import tqdm
from environment import RoboRacerEnv, RoboRacerParallelEnvs, FollowTheGap
from model import load_model, make_model
from visualize import LidarVisualiser, OccupancyGridVisualiser, RewardVisualiser
from model import ActorValueAuxOperator


def do_rollout(
        env: RoboRacerEnv | RoboRacerParallelEnvs,
        model: ActorValueAuxOperator | FollowTheGap,
        num_steps: int = 512,
        hide_progress: bool = False,
        select_keys: list[td.NestedKey] | None = None,
        visualise_lidar: bool = False,
        visualise_occupancy_grid: bool = False
) -> td.TensorDict:
    tensordict = env.reset()
    steps: list[td.TensorDict] = []

    lidar_visualiser = LidarVisualiser() if visualise_lidar else None
    occupancy_grid_visualiser = OccupancyGridVisualiser() if visualise_occupancy_grid else None

    with torch.no_grad():
        for step in tqdm.trange(num_steps, disable=hide_progress):
            tensordict = model.get_policy_operator()(tensordict)
            tensordict = env.step(tensordict)
            if visualise_lidar:
                lidar_visualiser.render(tensordict["agents", "stacked_lidar"])
            if visualise_occupancy_grid:
                occupancy_grid_visualiser.render(tensordict["agents", "occupancy_grid"])
            steps.append(
                tensordict if select_keys is None else tensordict.select(*select_keys))
            tensordict = env.step_mdp(tensordict)
    return torch.stack(steps, dim=0)  # (n_steps, ...)


if __name__ == "__main__":
    model, model_config, _, _ = load_model("checkpoints/baseline_w0_s0/iteration_00600.pt")

    is_mac = platform.system() == "Darwin"
    env = RoboRacerEnv(
        file_name=None,#"TestUnityProject/Test speed/build.app" if is_mac
        #else "linux_build/linux_build.x86_64",
        num_stacked_frames=model_config["num_stacked_lidar_frames"],
        no_graphics=False,
        time_scale=1.0,
        num_areas=2,
        seed=45,
    )
    try:
        rollout = do_rollout(env, model, num_steps=4086)
    except KeyboardInterrupt:
        pass
    finally:
        env.close()
