from torchrl.envs import UnityMLAgentsEnv, check_env_specs
from mlagents_envs.side_channel.engine_configuration_channel import EngineConfigurationChannel
import time
from environment import RoboRacerEnv, RoboRacerParallelEnvs
from visualize import LidarVisualiser


if __name__ == "__main__":
    env = RoboRacerParallelEnvs(
        num_envs=2,
        file_name="TestUnityProject/Test speed/build.app",
        num_stacked_frames=50,
        no_graphics=True,
        num_areas=2,
        time_scale=100.0,
        seed=0,
    )

    env.reset()


    c = 0
    start = time.perf_counter_ns()
    #visualiser = LidarVisualiser()
    try:
        while True:
            td = env.step(env.rand_action())
            #print(td)
            if td[("next", "agents", "done")].any():
                print("DONE")
            #visualiser.render(td[("next", "agents", "stacked_lidar")])
            c += 1
    except KeyboardInterrupt:
        pass
    finally:
        env.close()
        print(f"FPS: {c / ((time.perf_counter_ns() - start) / 1e9)}")
        print("Number of steps: ", c)
        print(f"ms per step: {(time.perf_counter_ns() - start) / 1e6 / c}")
