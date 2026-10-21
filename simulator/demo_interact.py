"""Drive a car around with WASD.

W throttle, S brake (reverses once stopped), A/D steer, SPACE handbrake,
R reset, ESC quit.

The motor curve, Ackermann linkage and brake logic live here rather than in
car_model, which takes a raw steer angle and torque per wheel. Note that brake
torque is shaped by tanh(omega) so it opposes rotation instead of driving the
wheel backwards, and drive torque falls off with wheel speed; a constant torque
would spin a wheel up without bound.
"""

import numpy as np
import jax
import jax.numpy as jnp
import pygame

from car_model import (Action, default_params, init_state, quat_to_mat, step,
                       wheel_centres)

DT = 1e-3
SUBSTEPS = 20
SIZE = (1100, 720)

WHEELBASE = 0.33
TRACK = 0.24
MAX_STEER = 0.35
STEER_RATE = 2.5
MOTOR_TORQUE = 0.35
MOTOR_OMEGA = 300.0
BRAKE_TORQUE = 0.5
BRAKE_OMEGA = 3.0   # rad/s, brake blend width; too tight is stiff for RK4

BG = (16, 18, 24)
GRID = (42, 46, 58)
BODY = (235, 238, 245)
TEXT = (170, 176, 190)
NEAR = 0.1
FOCAL = 950.0


@jax.jit
def advance(state, action, params):
    return jax.lax.scan(lambda s, _: (step(s, action, params, DT), None),
                        state, None, length=SUBSTEPS)[0]


def control(state, keys, steer):
    """Map key state to a per-wheel steer angle and torque."""
    throttle = float(keys[pygame.K_w])
    braking = float(keys[pygame.K_s])
    target = MAX_STEER * (float(keys[pygame.K_a]) - float(keys[pygame.K_d]))
    steer = steer + np.clip(target - steer, -STEER_RATE * DT * SUBSTEPS,
                            STEER_RATE * DT * SUBSTEPS)

    t = np.tan(steer)
    left = np.arctan(WHEELBASE * t / (WHEELBASE - 0.5 * TRACK * t))
    right = np.arctan(WHEELBASE * t / (WHEELBASE + 0.5 * TRACK * t))

    omega = np.asarray(state.wheel_omega[0])
    forward = np.asarray(quat_to_mat(state.quat[0]))[:, 0]
    speed = float(np.asarray(state.vel[0]) @ forward)
    drive = MOTOR_TORQUE * np.clip(1.0 - np.abs(omega) / MOTOR_OMEGA, 0.0, 1.0)

    torque = np.zeros(4)
    torque[2:] = throttle * drive[2:]
    if braking:
        # Signed speed, so holding S reverses instead of chattering at a stop.
        if speed > 0.3:
            torque -= BRAKE_TORQUE * np.tanh(omega / BRAKE_OMEGA)
        else:
            torque[2:] -= 0.5 * drive[2:]
    if keys[pygame.K_SPACE]:
        torque[2:] -= BRAKE_TORQUE * np.tanh(omega[2:] / BRAKE_OMEGA)

    action = Action(steer=jnp.array([[left, right, 0.0, 0.0]]),
                    torque=jnp.array(torque)[None])
    return action, steer, throttle, braking


def look_at(eye, target):
    f = target - eye
    f /= np.linalg.norm(f)
    r = np.cross(f, (0.0, 0.0, 1.0))
    r /= np.linalg.norm(r)
    return np.stack([r, np.cross(r, f), f])


def draw_lines(surf, segs, cam, eye, colour, width=1):
    """Project (N, 2, 3) world segments, clipping against the near plane."""
    c = ((segs.reshape(-1, 3) - eye) @ cam.T).reshape(-1, 2, 3)
    c = c[(c[:, 0, 2] > NEAR) | (c[:, 1, 2] > NEAR)]
    if not len(c):
        return
    a, b = c[:, 0].copy(), c[:, 1].copy()
    for p, q in ((a, b), (b, a)):
        m = p[:, 2] <= NEAR
        if m.any():
            t = (NEAR - p[m, 2]) / (q[m, 2] - p[m, 2])
            p[m] += t[:, None] * (q[m] - p[m])
    sa, sb = to_screen(a), to_screen(b)
    for i in range(len(sa)):
        pygame.draw.line(surf, colour, sa[i], sb[i], width)


def to_screen(c):
    return np.stack([SIZE[0] / 2 + FOCAL * c[:, 0] / c[:, 2],
                     SIZE[1] / 2 - FOCAL * c[:, 1] / c[:, 2]], axis=1)


def grid_segs(centre, extent=24.0, spacing=2.0):
    cx, cy = np.round(np.asarray(centre[:2]) / spacing) * spacing
    t = np.arange(-extent, extent + spacing, spacing)
    v = np.stack([np.stack([cx + t, np.full_like(t, cy - extent), np.zeros_like(t)], 1),
                  np.stack([cx + t, np.full_like(t, cy + extent), np.zeros_like(t)], 1)], 1)
    h = np.stack([np.stack([np.full_like(t, cx - extent), cy + t, np.zeros_like(t)], 1),
                  np.stack([np.full_like(t, cx + extent), cy + t, np.zeros_like(t)], 1)], 1)
    return np.concatenate([v, h])


BOX_LO = np.array([-0.19, -0.09, -0.015])
BOX_HI = np.array([0.19, 0.09, 0.065])
CORNERS = np.array([[x, y, z] for x in (0, 1) for y in (0, 1) for z in (0, 1)])
EDGES = np.array([(i, j) for i in range(8) for j in range(i + 1, 8)
                  if np.sum(CORNERS[i] != CORNERS[j]) == 1])


FRONT = np.array([(4, 5), (4, 6), (5, 7), (6, 7)])


def draw_car(surf, state, params, cam, eye, steer, angles):
    R = np.asarray(quat_to_mat(state.quat[0]))
    pos = np.asarray(state.pos[0])
    body = pos + (BOX_LO + CORNERS * (BOX_HI - BOX_LO)) @ R.T
    draw_lines(surf, body[EDGES], cam, eye, BODY, 2)
    draw_lines(surf, body[FRONT], cam, eye, (90, 150, 255), 3)

    centres = np.asarray(wheel_centres(jax.tree.map(lambda x: x[0], state), params))
    radius = np.asarray(params.wheel_radius)
    omega = np.asarray(state.wheel_omega[0])
    forward = np.asarray(quat_to_mat(state.quat[0]))[:, 0]
    speed = float(np.asarray(state.vel[0]) @ forward)
    th = np.linspace(0, 2 * np.pi, 17)

    for i in range(4):
        u = R @ (np.cos(steer[i]), np.sin(steer[i]), 0.0)
        v = R @ (0.0, 0.0, 1.0)
        ring = centres[i] + radius[i] * (np.cos(th)[:, None] * u + np.sin(th)[:, None] * v)
        slip = min(abs(omega[i] * radius[i] - speed) / max(abs(speed), 1.0), 1.0)
        colour = (int(90 + 165 * slip), int(200 - 140 * slip), int(120 - 80 * slip))
        draw_lines(surf, np.stack([ring[:-1], ring[1:]], 1), cam, eye, colour, 2)
        spoke = radius[i] * (np.cos(angles[i]) * u + np.sin(angles[i]) * v)
        draw_lines(surf, np.array([[centres[i] - spoke, centres[i] + spoke]]),
                   cam, eye, colour, 2)


def main():
    pygame.init()
    surf = pygame.display.set_mode(SIZE)
    pygame.display.set_caption("car_model - WASD")
    font = pygame.font.SysFont("menlo,consolas,monospace", 15)
    clock = pygame.time.Clock()

    params = default_params()
    state = jax.tree.map(lambda x: x[None], init_state(params))
    steer, cam_yaw, angles = 0.0, 0.0, np.zeros(4)

    while True:
        for e in pygame.event.get():
            if e.type == pygame.QUIT or (e.type == pygame.KEYDOWN and e.key == pygame.K_ESCAPE):
                pygame.quit()
                return
            if e.type == pygame.KEYDOWN and e.key == pygame.K_r:
                state = jax.tree.map(lambda x: x[None], init_state(params))
                steer, angles = 0.0, np.zeros(4)

        keys = pygame.key.get_pressed()
        action, steer, throttle, braking = control(state, keys, steer)
        state = advance(state, action, params)
        angles = (angles + np.asarray(state.wheel_omega[0]) * DT * SUBSTEPS) % (2 * np.pi)

        pos = np.asarray(state.pos[0])
        R = np.asarray(quat_to_mat(state.quat[0]))
        yaw = np.arctan2(R[1, 0], R[0, 0])
        cam_yaw += np.arctan2(np.sin(yaw - cam_yaw), np.cos(yaw - cam_yaw)) * 0.12
        eye = pos + (-2.3 * np.cos(cam_yaw), -2.3 * np.sin(cam_yaw), 0.95)
        cam = look_at(eye, pos + (0.0, 0.0, 0.15))

        surf.fill(BG)
        draw_lines(surf, grid_segs(pos), cam, eye, GRID)
        draw_car(surf, state, params, cam, eye, np.asarray(action.steer[0]), angles)

        vel = np.asarray(state.vel[0])
        fwd = float(vel @ R[:, 0])
        lat = float(vel @ R[:, 1])
        lines = [
            f"speed  {np.linalg.norm(vel):6.2f} m/s   ({fwd:+.2f} fwd {lat:+.2f} lat)",
            f"slip   {np.degrees(np.arctan2(lat, max(abs(fwd), 0.1))):+6.1f} deg",
            f"steer  {np.degrees(steer):+6.1f} deg    yaw rate {state.ang_vel[0, 2]:+.2f} rad/s",
            f"wheels {' '.join(f'{w * 0.05:6.2f}' for w in state.wheel_omega[0])} m/s",
            f"height {pos[2] * 1000:6.1f} mm",
            "",
            f"W {'#' if throttle else '.'}  S {'#' if braking else '.'}  "
            f"SPACE {'#' if keys[pygame.K_SPACE] else '.'}   R reset   ESC quit",
            f"{clock.get_fps():.0f} fps",
        ]
        for i, line in enumerate(lines):
            surf.blit(font.render(line, True, TEXT), (16, 14 + 19 * i))

        pygame.display.flip()
        clock.tick(50)


if __name__ == "__main__":
    main()
