from torchrl.envs import UnityMLAgentsEnv, check_env_specs
from mlagents_envs.side_channel.engine_configuration_channel import EngineConfigurationChannel
import time
from environment import RoboRacerEnv
from visualize import LidarVisualiser


env = RoboRacerEnv(
    file_name="TestUnityProject/Test speed/build.app",
    num_stacked_frames=50,
    no_graphics=True,
    num_areas=2,
    time_scale=100.0,
    seed=0,
)

env.reset()

print(env.action_spec)
exit(0)

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
