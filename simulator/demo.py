"""Roll out a batch of cars and plot the result."""

import time

import jax
import jax.numpy as jnp
import matplotlib.pyplot as plt

from car_model import Action, default_params, init_state, step

DT = 1e-3
STEPS = 4000
STEER = jnp.array([0.0, 0.08, 0.16, 0.24, -0.16])
TORQUE = 0.6


def rollout(params, states, actions, dt, steps):
    def body(s, _):
        s = step(s, actions, params, dt)
        return s, s

    return jax.lax.scan(body, states, None, length=steps)[1]


def main():
    params = default_params()
    n = STEER.shape[0]

    states = jax.vmap(init_state, in_axes=(None, 0, 0))(
        params, jnp.zeros((n, 3)), jnp.zeros(n)
    )
    actions = Action(
        steer=jnp.stack([STEER, STEER, jnp.zeros(n), jnp.zeros(n)], axis=1),
        torque=jnp.tile(jnp.array([0.0, 0.0, TORQUE, TORQUE]), (n, 1)),
    )

    run = jax.jit(lambda s: rollout(params, s, actions, DT, STEPS))
    traj = jax.block_until_ready(run(states))

    t0 = time.perf_counter()
    traj = jax.block_until_ready(run(states))
    elapsed = time.perf_counter() - t0
    print(f"{n} cars x {STEPS} steps in {elapsed:.3f}s "
          f"({n * STEPS / elapsed / 1e3:.0f}k car-steps/s)")

    t = jnp.arange(STEPS) * DT
    speed = jnp.linalg.norm(traj.vel, axis=-1)
    print(f"final speeds: {speed[-1]}")
    print(f"ride height:  {traj.pos[-1, :, 2]}")

    fig, ax = plt.subplots(1, 3, figsize=(15, 4.5))
    for i in range(n):
        label = f"steer {STEER[i]:+.2f}"
        ax[0].plot(traj.pos[:, i, 0], traj.pos[:, i, 1], label=label)
        ax[1].plot(t, speed[:, i], label=label)
        ax[2].plot(t, traj.pos[:, i, 2] * 1e3, label=label)

    ax[0].set(xlabel="x [m]", ylabel="y [m]", title="trajectory")
    ax[0].axis("equal")
    ax[1].set(xlabel="t [s]", ylabel="speed [m/s]", title="speed")
    ax[2].set(xlabel="t [s]", ylabel="CoM height [mm]", title="ride height")
    for a in ax:
        a.grid(alpha=0.3)
    ax[0].legend()
    fig.tight_layout()
    fig.savefig("demo.png", dpi=120)
    print("wrote simulator/demo.png")


if __name__ == "__main__":
    main()
