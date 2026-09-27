import environment

if __name__ == "__main__":
    env = environment.make_envs(2, 3)
    rollout = env.rollout(max_steps=1000)
    print(rollout)
    print("Done rollout!")
    