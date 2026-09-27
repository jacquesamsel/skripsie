import environment
import time

if __name__ == "__main__":
    env = environment.make_envs(2, 3)
    time_start = time.perf_counter()
    rollout = env.rollout(max_steps=1000, break_when_any_done=False)
    print("Finished in ", time.perf_counter() - time_start, "seconds")
    print(rollout)
    print("Done rollout!")
    