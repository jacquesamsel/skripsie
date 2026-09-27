from mlagents_envs.side_channel.engine_configuration_channel import EngineConfigurationChannel
from torchrl.envs import set_exploration_type
from torchrl.envs.utils import ExplorationType, step_mdp
from torchrl.objectives import ClipPPOLoss
from torchrl.objectives.value import GAE
import tensordict as td
from torchrl.modules import ActorValueOperator
from torchrl.data import ReplayBuffer, LazyTensorStorage, SamplerWithoutReplacement
from environment import make_envs
from model import ActorValueAuxOperator, make_model
import time
import torch
import os
from torch.utils.tensorboard import SummaryWriter


def world_to_local(vector: torch.Tensor, quaternion: torch.Tensor) -> torch.Tensor:
    """Rotates a world-frame vector into the local frame of a Unity (x, y, z, w) quaternion."""
    # inverse rotation of a unit quaternion is its conjugate: negate the vector part
    u = -quaternion[..., :3]
    w = quaternion[..., 3:]
    uv = torch.linalg.cross(u, vector, dim=-1)
    return vector + 2 * w * uv + 2 * torch.linalg.cross(u, uv, dim=-1)


def compute_pos_delta(data: td.TensorDict) -> torch.Tensor:
    """[forward, lateral] displacement over the step, in the car's frame at the start of the step."""
    world_delta = data["next", "agents", "pos"] - data["agents", "pos"]
    local_delta = world_to_local(
        world_delta, data["agents", "orientation_quaternion"])
    # Unity: +z is forward, +x is right
    return torch.stack([local_delta[..., 2], local_delta[..., 0]], dim=-1)


def train(
        forward_velocity_weight: float,
        lateral_velocity_weight: float,
        curvature_weight: torch.Tensor,
        pos_delta_weight: torch.Tensor,
        wheel_slips_weight: torch.Tensor,
        yaw_rate_weight: float,
        num_stacked_lidar_frames: int,
        num_envs: int,
        num_agents_per_env: int,
        name: str
):
    # per-element weights broadcast against the target, so tensors let each
    # component (e.g. each curvature horizon, each wheel/axis) be weighted separately
    aux_weights = {
        "velocity_forward": torch.as_tensor(forward_velocity_weight),
        "velocity_lateral": torch.as_tensor(lateral_velocity_weight),
        "curvature": torch.as_tensor(curvature_weight),
        "pos_delta": torch.as_tensor(pos_delta_weight),
        "wheel_slips": torch.as_tensor(wheel_slips_weight),
        "yaw_rate": torch.as_tensor(yaw_rate_weight),
    }
    writer = SummaryWriter(log_dir=f"runs/{name}")

    torch.set_num_threads(8)

    checkpoint_path = f"checkpoints/{name}.pt"
    os.makedirs(os.path.dirname(checkpoint_path), exist_ok=True)

    device = torch.device("cpu")
    print(f"Using device: {device}")
    agents = [f"agent_{i}" for i in range(num_agents_per_env)]

    env = make_envs(num_envs=num_envs, num_agents_per_env=num_agents_per_env,
                    num_stacked_frames=num_stacked_lidar_frames)

    gamma = 0.99
    lmbda = 0.95
    clip_epsilon = 0.2
    entropy_epsilon = 0.001
    frames_per_batch = 512
    batch_size = 128

    model: ActorValueAuxOperator = make_model(
        num_stacked_lidar_frames=num_stacked_lidar_frames).to(device)

    optim = torch.optim.Adam(model.parameters(), lr=1e-4)

    start_iter = 0
    if os.path.exists(checkpoint_path):
        checkpoint = torch.load(checkpoint_path, map_location=device)
        model.load_state_dict(checkpoint["model"])
        optim.load_state_dict(checkpoint["optim"])
        start_iter = checkpoint["iter"] + 1
        print(f"Resumed from checkpoint at iteration {start_iter}")

    tensordict: td.TensorDict = env.reset()

    gae = GAE(
        gamma=gamma,
        lmbda=lmbda,
        value_network=model.get_value_operator(),
        average_gae=True,
        deactivate_vmap=True
    )
    gae.set_keys(
        reward=("reward"),
        done=("agents", "done"),
        terminated=("agents", "terminated"),
    )
    loss_module = ClipPPOLoss(
        actor_network=model.get_policy_operator(),
        critic_network=model.get_value_operator(),
        clip_epsilon=clip_epsilon,
        entropy_bonus=entropy_epsilon > 0,
        entropy_coeff=entropy_epsilon,
        critic_coeff=1.0,
        normalize_advantage=True,
        loss_critic_type="smooth_l1",
    )

    loss_module.set_keys(
        reward="reward",
        done=("agents", "done"),
        terminated=("agents", "terminated"),
    )

    def save_checkpoint(iter_num):
        torch.save({
            "model": model.state_dict(),
            "optim": optim.state_dict(),
            "iter": iter_num,
        }, checkpoint_path)

    i = start_iter - 1
    try:
        for i in range(start_iter, 10000):
            rows_per_iter = frames_per_batch * num_envs
            batches_per_epoch = rows_per_iter // batch_size
            batch = ReplayBuffer(
                storage=LazyTensorStorage(max_size=rows_per_iter),
                sampler=SamplerWithoutReplacement(),
            )
            frames = []
            with torch.no_grad(), set_exploration_type(ExplorationType.RANDOM):
                print(
                    f"Iteration {i} — collecting {frames_per_batch} frames..."
                )
                # Run the environment for a number of frames
                start_time = time.time_ns()
                forward_time_ns = 0
                env_time_ns = 0
                for frame in range(frames_per_batch):
                    per_agent_keys = [("agents", agent) for agent in agents] + \
                        [("next", "agents", agent) for agent in agents]

                    t0 = time.time_ns()
                    tensordict = model.get_policy_operator().forward(tensordict.to(device))

                    t1 = time.time_ns()
                    tensordict = env.step(tensordict.cpu())
                    t2 = time.time_ns()

                    forward_time_ns += t1 - t0
                    env_time_ns += t2 - t1

                    frames.append(tensordict.exclude(*per_agent_keys))
                    tensordict = step_mdp(tensordict, done_keys=env.done_keys)
                total_time_ns = time.time_ns() - start_time
                print(
                    f"Time taken for {frames_per_batch} frames: {total_time_ns / 1e9:.3f} seconds = {total_time_ns / frames_per_batch/1e6:.3f} ms/frame")
                print(f"  forward: {forward_time_ns / 1e9:.3f}s ({forward_time_ns / frames_per_batch / 1e6:.3f} ms/frame), "
                      f"env.step: {env_time_ns / 1e9:.3f}s ({env_time_ns / frames_per_batch / 1e6:.3f} ms/frame)")

            rollout = torch.stack(frames, dim=0)

            start_gradient_time = time.time_ns()
            data_view = gae(rollout.to(device), time_dim=0).reshape(-1)
            data_view["agents", "pos_delta"] = compute_pos_delta(data_view)
            # Unity is y-up, so yaw rate is the angular velocity about y
            data_view["agents", "yaw_rate"] = data_view["agents",
                                                        "angular_velocity"][..., 1:2]
            batch.extend(data_view)

            for epoch in range(2):
                for _ in range(batches_per_epoch):
                    batch_data = batch.sample(batch_size).to(device)
                    ppo_loss_vals = loss_module(batch_data)
                    # recompute with the current weights so gradients flow into the aux head and trunk
                    model.get_aux_operator().forward(batch_data)

                    aux_losses: dict[str, torch.Tensor] = {
                        key: (weight.to(
                            device) * (batch_data["agents", key] - batch_data["aux", key]) ** 2).mean()
                        for key, weight in aux_weights.items()
                    }

                    loss_val: torch.Tensor = (
                        ppo_loss_vals["loss_objective"]
                        + ppo_loss_vals["loss_critic"]
                        + ppo_loss_vals["loss_entropy"]
                        + sum(aux_losses.values())
                    )

                    loss_val.backward()
                    optim.step()
                    optim.zero_grad()

            gradient_time_ns = time.time_ns() - start_gradient_time
            print(
                f"Time taken for gradient step: {gradient_time_ns / 1e9:.3f} seconds = {gradient_time_ns / frames_per_batch/1e6:.3f} ms/frame")
            writer.add_scalar("loss/objective",
                              ppo_loss_vals["loss_objective"].item(), i)
            writer.add_scalar(
                "loss/critic", ppo_loss_vals["loss_critic"].item(), i)
            writer.add_scalar(
                "loss/entropy", ppo_loss_vals["loss_entropy"].item(), i)
            for key, value in aux_losses.items():
                writer.add_scalar(f"loss/aux_{key}", value.item(), i)
            writer.add_scalar("loss/total", loss_val.item(), i)
            writer.add_scalar("rollout/mean_reward",
                              rollout["next", "reward"].mean().item(), i)
            # for kind in ("progress", "forward_velocity", "step_penalty", "collision"):
            #     writer.add_scalar(
            #         f"reward_components/{kind}",
            #         rollout["agents", "reward_components", kind].mean().item(), i)
            writer.add_scalar("rollout/avg_speed",
                              rollout["agents", "speed"][..., 0].mean().item(), i)
            writer.add_scalar("rollout/collision_rate",
                              rollout["agents", "terminated"].float().mean().item(), i)
            writer.add_scalar("timing/ms_per_frame",
                              total_time_ns / frames_per_batch / 1e6, i)
            writer.add_scalar("timing/forward_ms_per_frame",
                              forward_time_ns / frames_per_batch / 1e6, i)
            writer.add_scalar("timing/env_ms_per_frame",
                              env_time_ns / frames_per_batch / 1e6, i)
            writer.add_scalar("lr", optim.param_groups[0]["lr"], i)
            writer.add_histogram("actions/throttle",
                                 rollout["action", "throttle"], i)
            writer.add_histogram("actions/steering",
                                 rollout["action", "steering"], i)

            if i % 10 == 0:
                save_checkpoint(i)
    except KeyboardInterrupt:
        print("Interrupted — saving checkpoint before exit")
    finally:
        save_checkpoint(i)
        print(f"Checkpoint saved at iteration {i}")
        env.close()


if __name__ == "__main__":
    train(
        num_envs=8,
        num_agents_per_env=16,
        forward_velocity_weight=0.0,
        lateral_velocity_weight=0.0,
        curvature_weight=torch.tensor([0.0, 0.0, 0.0]),
        pos_delta_weight=torch.tensor([0.0, 0.0]),
        wheel_slips_weight=torch.zeros(4, 2),
        yaw_rate_weight=0.0,
        num_stacked_lidar_frames=4,
        name="no_aux"
    )
