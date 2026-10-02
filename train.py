from collections import defaultdict
from typing import Literal

from torch.utils.tensorboard import SummaryWriter
import time
from model import ActorValueAuxOperator, make_model
from environment import make_envs
from torchrl.data import ReplayBuffer, LazyTensorStorage, SamplerWithoutReplacement
from torchrl.modules import ActorValueOperator
import tensordict as td
from torchrl.objectives.value import GAE
from torchrl.objectives import ClipPPOLoss
from torchrl.envs.utils import ExplorationType, step_mdp
from torchrl.envs import set_exploration_type
from torch.nn.functional import smooth_l1_loss
from mlagents_envs.side_channel.engine_configuration_channel import EngineConfigurationChannel
import os
import torch
import itertools


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
        curvature_weights: torch.Tensor,
        pos_delta_weights: torch.Tensor,
        wheel_slips_weight: torch.Tensor,
        yaw_rate_weight: float,
        num_stacked_lidar_frames: int,
        n_rays: int,
        lidar_conv: Literal["conv1d", "conv2d"],
        ray_kernel: int,
        ray_stride: int,
        num_envs: int,
        num_agents_per_env: int,
        name: str,
        time_kernel: int | None = None,
        time_stride: int | None = None,
):
    torch.set_num_threads(32)

    # per-element weights broadcast against the target, so tensors let each
    # component (e.g. each curvature horizon, each wheel/axis) be weighted separately
    aux_weights = dict(
        velocity_forward=torch.as_tensor([forward_velocity_weight]),
        velocity_lateral=torch.as_tensor([lateral_velocity_weight]),
        curvature=curvature_weights,
        wheel_slips=wheel_slips_weight,
    )

    writer = SummaryWriter(log_dir=f"runs/{name}")

    checkpoint_path = f"checkpoints/{name}.pt"
    os.makedirs(os.path.dirname(checkpoint_path), exist_ok=True)

    device = torch.device("cpu")
    print(f"Using device: {device}")

    env = make_envs(num_envs=num_envs, num_agents_per_env=num_agents_per_env,
                    num_stacked_frames=num_stacked_lidar_frames, time_scale=20.0)

    gamma = 0.99
    lmbda = 0.95
    clip_epsilon = 0.2
    entropy_epsilon = 0.0005
    frames_per_rollout = 512
    batch_size = 512

    model_config = dict(
        num_stacked_lidar_frames=num_stacked_lidar_frames,
        n_rays=n_rays,
        lidar_conv=lidar_conv,
        ray_kernel=ray_kernel,
        ray_stride=ray_stride,
        time_kernel=time_kernel,
        time_stride=time_stride,
    )
    model: ActorValueAuxOperator = make_model(**model_config)

    optim = torch.optim.Adam(model.parameters(), lr=1e-4)

    start_iter = 0
    if os.path.exists(checkpoint_path):
        checkpoint = torch.load(checkpoint_path, map_location=device)
        if checkpoint["model_config"] != model_config:
            raise ValueError(
                f"Checkpoint was trained with a different model_config.\n"
                f"  checkpoint: {checkpoint['model_config']}\n"
                f"  requested:  {model_config}")
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
        deactivate_vmap=True,
        time_dim=0,  # the rollout is stacked along the first dimension, so time_dim=0
    )
    gae.set_keys(
        reward=("agents", "reward"),
        done=("agents", "done"),
        terminated=("agents", "terminated"),
    )
    loss_module = ClipPPOLoss(
        actor_network=model.get_policy_head(),
        critic_network=model.get_value_head(),
        clip_epsilon=clip_epsilon,
        entropy_bonus=entropy_epsilon > 0,
        entropy_coeff=entropy_epsilon,
        critic_coeff=1.0,
        loss_critic_type="smooth_l1",
    )

    loss_module.set_keys(
        reward=("agents", "reward"),
        done=("agents", "done"),
        terminated=("agents", "terminated"),
    )

    def save_checkpoint(iter_num):
        torch.save({
            "model": model.state_dict(),
            "model_config": model_config,
            "optim": optim.state_dict(),
            "iter": iter_num,
        }, checkpoint_path)

    i = start_iter - 1
    try:
        # to prevent reallocation each iteration
        rollout_buffer = ReplayBuffer(
            storage=LazyTensorStorage(
                max_size=frames_per_rollout*num_envs*num_agents_per_env,
                device=device,
            ),
            sampler=SamplerWithoutReplacement(),
            batch_size=batch_size
        )

        # infinite loop until interrupted
        for i in itertools.count(start=start_iter):
            # Collect the rollout
            steps = []

            rollout_start = time.perf_counter_ns()
            with torch.no_grad(), set_exploration_type(ExplorationType.RANDOM):
                for frame in range(frames_per_rollout):
                    tensordict = env.step(
                        model.get_policy_operator()(tensordict))
                    steps.append(tensordict)
                    tensordict = env.step_mdp(tensordict)

            stack_rollout_start = time.perf_counter_ns()
            # [T, num_envs, num_agents, ...]
            rollout = torch.stack(steps, dim=0)
            print(f"Rollout size: {rollout.bytes()} bytes")
            gae_start = time.perf_counter_ns()
            with torch.no_grad():
                # rollout is [T, num_envs, num_agents, ...], matching time_dim=0 above
                rollout = gae(rollout)

            save_rollout_buffer_start = time.perf_counter_ns()

            rollout_buffer.empty()
            # flatten [T, num_envs, num_agents] into T * num_envs * num_agents samples
            rollout_buffer.extend(rollout.reshape(-1))

            epochs_start = time.perf_counter_ns()

            loss_logs = []
            grad_norms = []
            for epochs in range(4):  # epochs
                for minibatch in rollout_buffer:
                    optim.zero_grad()
                    loss: td.TensorDict = loss_module(minibatch)

                    minibatch = model.get_trunk_operator()(minibatch)

                    # compute the auxiliary losses and add them to the rollout
                    minibatch = model.get_aux_head()(minibatch)

                    aux_losses = td.TensorDict(dict(
                        velocity_forward=smooth_l1_loss(
                            minibatch["aux", "velocity_forward"], minibatch["agents", "velocity_forward"]),
                        velocity_lateral=smooth_l1_loss(
                            minibatch["aux", "velocity_lateral"], minibatch["agents", "velocity_lateral"]),
                        curvature=smooth_l1_loss(
                            minibatch["aux", "curvature"], minibatch["agents", "curvature"]),
                        wheel_slips=smooth_l1_loss(
                            minibatch["aux", "wheel_slips"], minibatch["agents", "wheel_slips"]),
                    ))

                    total_loss = (
                        # PPO loss
                        loss["loss_entropy"] + loss["loss_critic"] +
                        loss["loss_objective"]  # + \
                        # auxiliary losses
                        + sum((aux_weights[k] * aux_losses[k].mean(0)).sum()
                              for k in aux_weights)
                    ).mean()
                    total_loss.backward()
                    grad_norm = torch.nn.utils.clip_grad_norm_(
                        model.parameters(), 1.0).item()
                    optim.step()

                    # log the stuff
                    loss_logs.append(loss.detach().apply(
                        lambda x: x.float().mean(), batch_size=[]))
                    loss_logs[-1]["total_loss"] = total_loss.detach().float()
                    for x in aux_losses.keys():
                        loss_logs[-1][f"aux_{x}"] = aux_losses[x].mean().detach().float()
                    grad_norms.append(grad_norm)

            # average the per-minibatch logs over the whole iteration
            avg_loss = torch.stack(loss_logs).apply(
                lambda x: x.float().mean(dim=0), batch_size=[])

            end_time = time.perf_counter_ns()

            timings = {
                "rollout": (stack_rollout_start-rollout_start)/1e9,
                "stack_rollout": (gae_start-stack_rollout_start)/1e9,
                "gae": (save_rollout_buffer_start-gae_start)/1e9,
                "save_rollout_buffer": (epochs_start-save_rollout_buffer_start)/1e9,
                "epochs": (end_time-epochs_start)/1e9,
            }
            timings["total"] = end_time/1e9 - rollout_start/1e9

            print(f"Timing (iteration {i}):")
            for stage, seconds in timings.items():
                print(f"  {stage:<20}{seconds:8.3f} s"
                      f"{seconds * 1e3 / frames_per_rollout:9.2f} ms/frame")

            for stage, seconds in timings.items():
                if stage != "total":
                    writer.add_scalar(f"time/{stage}", seconds, i)

            writer.add_scalar("loss/total", avg_loss["total_loss"].item(), i)
            writer.add_scalar("loss/entropy", avg_loss["entropy"].item(), i)
            writer.add_scalar(
                "loss/actor", avg_loss["loss_objective"].item(), i)
            writer.add_scalar(
                "loss/critic", avg_loss["loss_critic"].item(), i)
            writer.add_scalar(
                "loss/mean_ratio", avg_loss["mean_ratio"].item(), i)
            writer.add_scalar(
                "loss/clip_fraction", avg_loss["clip_fraction"].item(), i)
            writer.add_scalar(
                "loss/kl_approx", avg_loss["kl_approx"].item(), i)
            writer.add_scalar(
                "loss/max_ratio", avg_loss["max_ratio"].item(), i)

            # log the aux losses
            for key, value in loss_logs[-1].items():
                if key.startswith("aux_"):
                    writer.add_scalar(f"loss/aux/{key[4:]}", value, i)

            # pre-clip norms over all minibatches of this iteration
            writer.add_scalar(
                "grad_norm/mean", sum(grad_norms) / len(grad_norms), i)
            writer.add_scalar("grad_norm/max", max(grad_norms), i)

            writer.add_scalar(
                "reward/mean", rollout["next", "agents", "reward"].mean().item(), i)
            writer.add_scalar("reward/mean_forward_velocity",
                              rollout["agents", "velocity_forward"].mean().item(), i)
            writer.add_scalar("reward/progress",
                              rollout["agents", "progress"].mean().item(), i)
            writer.add_scalar("reward/collision_rate",
                              rollout["agents", "terminated"].float().mean().item(), i)

            # every sampled action of this rollout (all steps, envs and agents)
            for action_name in ("throttle", "steering"):
                writer.add_histogram(
                    f"action/{action_name}", rollout["action", action_name].flatten(), i)

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
        num_agents_per_env=4,
        forward_velocity_weight=0.0,
        lateral_velocity_weight=0.0,
        curvature_weights=torch.tensor([0.0, 0.0, 0.0]),
        pos_delta_weights=torch.tensor([0.0, 0.0]),
        wheel_slips_weight=torch.zeros(4, 2),
        yaw_rate_weight=0.0,
        num_stacked_lidar_frames=50,  # 50Hz
        n_rays=101,
        lidar_conv="conv2d",
        time_kernel=8,
        time_stride=2,
        ray_kernel=8,
        ray_stride=1,
        name="conv2d"
    )
