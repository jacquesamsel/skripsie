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
        curvature_weight: torch.Tensor,
        pos_delta_weight: torch.Tensor,
        wheel_slips_weight: torch.Tensor,
        yaw_rate_weight: float,
        num_stacked_lidar_frames: int,
        num_envs: int,
        num_agents_per_env: int,
        name: str
):
    torch.set_num_threads(8)

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

    checkpoint_path = f"checkpoints/{name}.pt"
    os.makedirs(os.path.dirname(checkpoint_path), exist_ok=True)

    device = torch.device("cpu")
    print(f"Using device: {device}")
    agents = [f"agent_{i}" for i in range(num_agents_per_env)]

    env = make_envs(num_envs=num_envs, num_agents_per_env=num_agents_per_env,
                    num_stacked_frames=num_stacked_lidar_frames)

    # Confine this process's compute threads to a single L3 cache domain
    # (cpus 0-3,64-67 share one 16MB L3 on this Threadripper) and keep the
    # Unity/ParallelEnv worker subprocesses off of it (see make_env in
    # environment.py). Without this, the scheduler tends to co-locate this
    # process's threads near its own noisy children and the gradient step
    # gets ~3x slower even though the workers are otherwise idle.
    os.sched_setaffinity(0, {0, 1, 2, 3, 64, 65, 66, 67})

    gamma = 0.99
    lmbda = 0.95
    clip_epsilon = 0.2
    entropy_epsilon = 0.001
    frames_per_rollout = 512
    batch_size = 128

    model: ActorValueAuxOperator = make_model(
        num_stacked_lidar_frames=num_stacked_lidar_frames)

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
        deactivate_vmap=True,
        # GAE expects time dimension to be 1, but our rollout is [num_envs, T, num_agents, ...]
        time_dim=1,
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
            for frame in range(frames_per_rollout):
                tensordict = env.step(model.get_policy_operator()(tensordict))
                print(tensordict)
                steps.append(tensordict)
                tensordict = step_mdp(tensordict)

            # [num_envs, T, num_agents, ...]
            rollout = torch.stack(steps, dim=1)
            with torch.no_grad():
                # needs time_dim=1, see below
                rollout = gae(rollout)

            rollout_buffer.empty()
            rollout_buffer.extend(rollout.reshape(-1))   # size = num_envs * T

            # Compute loss and update model
            loss = loss_module(rollout_buffer)

            for epochs in range(4):  # epochs
                for minibatch in rollout_buffer:
                    optim.zero_grad()
                    loss = loss_module(minibatch)
                    loss["loss"].mean().backward()
                    optim.step()

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
