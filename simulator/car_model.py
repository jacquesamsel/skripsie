"""RK4 rigid-body car simulator in JAX.

Chassis is a single 6-DOF rigid body. Each of the four wheels is attached by a
linear spring/damper strut acting along the body up-axis, carries its own spin
state, and generates tyre forces from Pacejka magic-formula curves. Ground is a
flat plane at z = 0. Wheel order is FL, FR, RL, RR.

Contact is found by casting each strut along the body up-axis, so a car rolled
past ~90 degrees has no wheel contact at all; terminate rollovers upstream.
Rolling resistance is a moment on each wheel proportional to its normal load;
aerodynamic drag is a quadratic force on the chassis at the centre of mass.
"""

import jax
import jax.numpy as jnp
from flax import struct


@struct.dataclass
class CarParams:
    mass: jax.Array
    inertia: jax.Array          # (3,) body-frame inertia diagonal
    mounts: jax.Array           # (4, 3) strut mounts in body frame
    wheel_radius: jax.Array     # (4,)
    wheel_inertia: jax.Array    # (4,) N/(m^2) moment of inertia
    spring_k: jax.Array         # (4,) N/m
    damper_c: jax.Array         # (4,) N/(m/s)
    rest_length: jax.Array      # (4,) m
    mu: jax.Array               # (4,)
    roll_res: jax.Array         # (4,) resisting moment coefficient, Crr
    b_long: jax.Array           # (4,) Pacejka stiffness factor
    c_long: jax.Array           # (4,) shape factor
    e_long: jax.Array           # (4,) curvature factor
    b_lat: jax.Array
    c_lat: jax.Array
    e_lat: jax.Array
    drag: float = 0.0           # N/(m/s)^2, lumped 0.5 * rho * Cd * A
    gravity: float = -9.81
    v_eps: float = 1.0          # slip-denominator floor, m/s
    omega_eps: float = 1.0      # rad/s, smooths rolling resistance through zero


@struct.dataclass
class DrivetrainParams:
    driven: jax.Array           # (4,) 1.0 for driven wheels
    gear: float                 # motor revolutions per wheel revolution
    kt: float                   # Nm/A
    ke: float                   # V.s/rad (equal to kt in SI units)
    resistance: float           # ohm
    volts: float                # pack voltage
    max_current: float          # A, ESC limit
    drag_brake: float           # 0-1, bridge duty at zero throttle
    friction: float             # Nm per driven wheel, gear mesh and cogging
    omega_eps: float = 1.0      # rad/s, smooths friction through zero


@struct.dataclass
class CarState:
    pos: jax.Array              # (3,) world
    quat: jax.Array             # (4,) body->world, wxyz
    vel: jax.Array              # (3,) world
    ang_vel: jax.Array          # (3,) body frame
    wheel_omega: jax.Array      # (4,) rad/s


@struct.dataclass
class Action:
    steer: jax.Array            # (4,) rad, about body up-axis
    torque: jax.Array           # (4,) Nm at the wheel


def quat_to_mat(q):
    w, x, y, z = q
    return jnp.array([
        [1 - 2 * (y * y + z * z), 2 * (x * y - w * z), 2 * (x * z + w * y)],
        [2 * (x * y + w * z), 1 - 2 * (x * x + z * z), 2 * (y * z - w * x)],
        [2 * (x * z - w * y), 2 * (y * z + w * x), 1 - 2 * (x * x + y * y)],
    ])


def quat_mul(a, b):
    aw, ax, ay, az = a
    bw, bx, by, bz = b
    return jnp.array([
        aw * bw - ax * bx - ay * by - az * bz,
        aw * bx + ax * bw + ay * bz - az * by,
        aw * by - ax * bz + ay * bw + az * bx,
        aw * bz + ax * by - ay * bx + az * bw,
    ])


def quat_from_yaw(yaw):
    return jnp.array([jnp.cos(yaw / 2), 0.0, 0.0, jnp.sin(yaw / 2)])


def pacejka(slip, b, c, d, e):
    bs = b * slip
    return d * jnp.sin(c * jnp.arctan(bs - e * (bs - jnp.arctan(bs))))


def wheel_force(mount, radius, inertia, k, c, rest, mu, roll_res,
                b_long, c_long, e_long, b_lat, c_lat, e_lat,
                steer, torque, wheel_omega, pos, vel, ang_vel, R, v_eps, omega_eps):
    """Forces/torques from one wheel. Returns world force, body torque, wheel accel."""
    up = R[:, 2]
    mount_w = pos + R @ mount
    omega_w = R @ ang_vel

    # Strut length that would place the wheel bottom on the ground.
    free = (mount_w[2] - radius) / jnp.maximum(up[2], 1e-3)
    length = jnp.clip(free, 0.0, rest)
    compression = rest - length
    contact = free < rest

    r_mount = R @ mount
    v_mount = vel + jnp.cross(omega_w, r_mount)
    fz = k * compression - c * (v_mount @ up)
    fz = jnp.where(contact, jnp.maximum(fz, 0.0), 0.0)

    # Tyre forces act at the contact patch.
    r_contact = r_mount - length * up - radius * jnp.array([0.0, 0.0, 1.0])
    v_contact = vel + jnp.cross(omega_w, r_contact)

    # Tyre forces act in the ground plane, not the body plane, or the drive
    # force gains a vertical component as the chassis pitches.
    heading = R @ jnp.array([jnp.cos(steer), jnp.sin(steer), 0.0])
    forward = heading.at[2].set(0.0)
    forward = forward / jnp.sqrt(forward @ forward + 1e-12)
    lateral = jnp.cross(jnp.array([0.0, 0.0, 1.0]), forward)
    vx = v_contact @ forward
    vy = v_contact @ lateral
    vx_safe = jnp.maximum(jnp.abs(vx), v_eps)

    kappa = (wheel_omega * radius - vx) / vx_safe
    alpha = -jnp.arctan(vy / vx_safe)
    fx = pacejka(kappa, b_long, c_long, mu * fz, e_long)
    fy = pacejka(alpha, b_lat, c_lat, mu * fz, e_lat)

    # Friction circle.
    limit = mu * fz
    mag = jnp.sqrt(fx * fx + fy * fy + 1e-12)
    scale = jnp.minimum(1.0, limit / mag)
    fx, fy = fx * scale, fy * scale

    force = fx * forward + fy * lateral + fz * up
    body_torque = R.T @ jnp.cross(r_contact, force)
    resist = roll_res * fz * radius * jnp.tanh(wheel_omega / omega_eps)
    omega_dot = (torque - fx * radius - resist) / inertia
    return force, body_torque, omega_dot


_wheel_forces = jax.vmap(
    wheel_force,
    in_axes=(0,) * 17 + (None,) * 6,
)


def dynamics(state, action, params):
    R = quat_to_mat(state.quat)
    force, body_torque, omega_dot = _wheel_forces(
        params.mounts, params.wheel_radius, params.wheel_inertia,
        params.spring_k, params.damper_c, params.rest_length, params.mu,
        params.roll_res,
        params.b_long, params.c_long, params.e_long,
        params.b_lat, params.c_lat, params.e_lat,
        action.steer, action.torque, state.wheel_omega,
        state.pos, state.vel, state.ang_vel, R, params.v_eps, params.omega_eps,
    )

    gravity = jnp.array([0.0, 0.0, params.gravity])
    # Softened norm: jnp.linalg.norm has a NaN gradient at exactly zero speed.
    drag = -params.drag * jnp.sqrt(state.vel @ state.vel + 1e-12) * state.vel
    acc = (force.sum(0) + drag) / params.mass + gravity
    net_torque = body_torque.sum(0)
    ang_acc = (net_torque - jnp.cross(state.ang_vel, params.inertia * state.ang_vel)) / params.inertia
    quat_dot = 0.5 * quat_mul(state.quat, jnp.concatenate([jnp.zeros(1), state.ang_vel]))

    return CarState(
        pos=state.vel,
        quat=quat_dot,
        vel=acc,
        ang_vel=ang_acc,
        wheel_omega=omega_dot,
    )


def rk4_step(state, action, params, dt):
    def add(a, b, s):
        return jax.tree.map(lambda x, y: x + s * y, a, b)

    k1 = dynamics(state, action, params)
    k2 = dynamics(add(state, k1, dt / 2), action, params)
    k3 = dynamics(add(state, k2, dt / 2), action, params)
    k4 = dynamics(add(state, k3, dt), action, params)

    slope = jax.tree.map(lambda a, b, c, d: (a + 2 * b + 2 * c + d) / 6, k1, k2, k3, k4)
    out = add(state, slope, dt)
    return out.replace(quat=out.quat / jnp.linalg.norm(out.quat))


# Advance a batch of cars sharing one CarParams: step(states, actions, params, dt).
step = jax.jit(jax.vmap(rk4_step, in_axes=(0, 0, None, None)))


def drivetrain(throttle, wheel_omega, p):
    """Per-wheel torque from a DC motor through a gearbox and an open diff.

    Stateless: the electrical time constant is far below any usable timestep.
    An open diff splits torque equally whatever the wheel speeds, so the only
    coupling is back-EMF, which sees the mean speed of the driven wheels. At
    zero throttle this returns a torque proportional to -omega, which is the
    drivetrain drag that slows a real car when you lift off.

    How hard the motor brakes off-throttle depends on how much the bridge is
    connected: full duty gives the textbook torque-speed curve, zero duty
    leaves only drag_brake of it. Shorting the bridge outright (drag_brake=1)
    brakes hard enough to lock the driven wheels.

    Gear mesh and cogging add a Coulomb term, which unlike back-EMF does not
    fade with speed and so is what actually brings the car to a stop.
    """
    n = p.driven.sum()
    omega_motor = p.gear * (wheel_omega * p.driven).sum() / n
    connected = p.drag_brake + (1.0 - p.drag_brake) * jnp.abs(throttle)
    current = (p.volts * throttle - connected * p.ke * omega_motor) / p.resistance
    current = jnp.clip(current, -p.max_current, p.max_current)
    torque = p.driven * p.gear * p.kt * current / n
    return torque - p.friction * p.driven * jnp.tanh(wheel_omega / p.omega_eps)


def default_drivetrain():
    """Rear-wheel drive, 2200 kv motor on 3S through a 7:1 reduction."""
    return DrivetrainParams(
        driven=jnp.array([0.0, 0.0, 1.0, 1.0]),
        gear=7.0,
        kt=0.00434,
        ke=0.00434,
        resistance=0.06,
        volts=11.1,
        max_current=35.0,
        drag_brake=0.12,
        friction=0.03,
    )


def wheel_centres(state, params):
    """World position of each wheel centre, for rendering."""
    R = quat_to_mat(state.quat)
    up = R[:, 2]
    mounts = state.pos + params.mounts @ R.T
    free = (mounts[:, 2] - params.wheel_radius) / jnp.maximum(up[2], 1e-3)
    length = jnp.clip(free, 0.0, params.rest_length)
    return mounts - length[:, None] * up


def default_params():
    """Roughly a 1/10-scale RoboRacer car."""
    four = jnp.ones(4)
    return CarParams(
        mass=jnp.array(3.5),
        inertia=jnp.array([0.02, 0.05, 0.045]),
        mounts=jnp.array([
            [0.165, 0.12, 0.03],
            [0.165, -0.12, 0.03],
            [-0.165, 0.12, 0.03],
            [-0.165, -0.12, 0.03],
        ]),
        wheel_radius=0.05 * four,
        # Driven wheels also carry the motor's reflected inertia, gear^2 *
        # I_rotor, shared by the two wheels the open diff feeds.
        wheel_inertia=jnp.array([1.25e-4, 1.25e-4, 4.9e-4, 4.9e-4]),
        spring_k=600.0 * four,
        damper_c=18.0 * four,
        rest_length=0.05 * four,
        mu=1.0 * four,
        roll_res=0.05 * four,
        b_long=10.0 * four,
        c_long=1.9 * four,
        e_long=0.97 * four,
        b_lat=14.0 * four,
        c_lat=1.4 * four,
        e_lat=-0.2 * four,
        drag=0.0165,
    )


def init_state(params, pos=jnp.zeros(3), yaw=0.0):
    """State resting at the static ride height, with x/y/yaw from the arguments."""
    sag = params.mass * abs(params.gravity) / (4 * params.spring_k.mean())
    height = (params.wheel_radius.mean() + params.rest_length.mean() - sag
              - params.mounts[:, 2].mean())
    return CarState(
        pos=jnp.asarray(pos).at[2].add(height),
        quat=quat_from_yaw(jnp.asarray(yaw)),
        vel=jnp.zeros(3),
        ang_vel=jnp.zeros(3),
        wheel_omega=jnp.zeros(4),
    )
