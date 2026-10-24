from torchrl.envs import UnityMLAgentsEnv, check_env_specs
from mlagents_envs.side_channel.engine_configuration_channel import EngineConfigurationChannel
import time
from environment import RoboRacerEnv, RoboRacerParallelEnvs
from visualize import LidarVisualiser, RewardVisualiser
import torch


if __name__ == "__main__":
    env = RoboRacerEnv(
        # num_envs=1,
        file_name=None,  # "TestUnityProject/Test speed/build.app",
        num_stacked_frames=50,
        no_graphics=False,
        num_areas=1,
        time_scale=1.0,
        seed=0,
    )

    td = env.reset()

    c = 0
    start = time.perf_counter_ns()
    lidar_visualiser = LidarVisualiser()
    # gamma only scales the return curve here; matched to train.py's
    reward_visualiser = RewardVisualiser(gamma=0.995)
    try:
        while True:
            td["action", "throttle"] = torch.Tensor([
                [0.1]
            ])
            td["action", "steering"] = torch.Tensor([
                [0.0]
            ])
            td = env.step(td)
            # print(td)
            if td[("next", "agents", "done")].any():
                print("DONE")
            lidar_visualiser.render(td[("next", "agents", "stacked_lidar")])
            reward_visualiser.render(td[("next", "agents", "reward")],
                                     td[("next", "agents", "done")])
            c += 1
    except KeyboardInterrupt:
        pass
    finally:
        env.close()
        print(f"FPS: {c / ((time.perf_counter_ns() - start) / 1e9)}")
        print("Number of steps: ", c)
        print(f"ms per step: {(time.perf_counter_ns() - start) / 1e6 / c}")
