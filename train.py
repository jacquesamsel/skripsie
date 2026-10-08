from typing import Literal

from torch.utils.tensorboard import SummaryWriter
import time
from model import ActorValueAuxOperator, curvature_aux_name, make_model
from environment import (
    CURVATURE_LOOKAHEAD_DISTANCES,
    RoboRacerParallelEnvs,
    track_curvature_key,
)
from stats import rollout_stats
import tensordict as td
from torchrl.objectives.value import GAE
from torchrl.objectives import ClipPPOLoss
from torchrl.envs.utils import ExplorationType, step_mdp
from torchrl.envs import set_exploration_type
from torch.nn.functional import smooth_l1_loss
from mlagents_envs.side_channel.engine_configuration_channel import EngineConfigurationChannel
import os
import platform
import random
import torch
import itertools
import pandas as pd

# rollout_data.csv's column names for each aux target, pooled where a target
# is predicted separately for two wheels that should nonetheless share one
# normalisation scale (front: fl+fr, rear: rl+rr).
AUX_TARGET_COLUMNS = dict(
    velocity_forward=["velocity_forward"],
    velocity_lateral=["velocity_lateral"],
    angular_velocity_y=["yaw_rate"],
    curvature_05m=["curvature_0_5m"],
    curvature_10m=["curvature_1_0m"],
    curvature_20m=["curvature_2_0m"],
    wheel_slip_front_forward=["wheel_slip_fl_forward", "wheel_slip_fr_forward"],
    wheel_slip_front_lateral=["wheel_slip_fl_sideways", "wheel_slip_fr_sideways"],
    wheel_slip_rear_forward=["wheel_slip_rl_forward", "wheel_slip_rr_forward"],
    wheel_slip_rear_lateral=["wheel_slip_rl_sideways", "wheel_slip_rr_sideways"],
)

def train(
        env,
        velocity_forward_weight: float,
        velocity_lateral_weight: float,
        curvature_weights: dict[float, float],
        wheel_slip_front_forward_weight: float,
        wheel_slip_front_lateral_weight: float,
        wheel_slip_rear_forward_weight: float,
        wheel_slip_rear_lateral_weight: float,
        angular_velocity_y_weight: float,
        num_stacked_lidar_frames: int,
        n_rays: int,
        lidar_conv: Literal["conv1d", "conv2d"],
        ray_kernel: int,
        ray_stride: int,
        name: str,
        seed: int,
        time_kernel: int | None = None,
        time_stride: int | None = None,
        max_iters: int | None = None,
        num_threads: int = 16,
) -> tuple[ActorValueAuxOperator, dict[str, float]]:
    torch.set_num_threads(num_threads)

    # Fixes model init, action sampling, and minibatch shuffling so that
    # trials/runs using the same seed are only distinguished by their
    # hyperparameters, not by incidental RNG noise.
    random.seed(seed)
    torch.manual_seed(seed)

    # Keyed by lookahead distance in metres; a distance left out of
    # curvature_weights gets weight 0, i.e. its head is left untrained.
    unknown_distances = sorted(
        set(curvature_weights) - set(CURVATURE_LOOKAHEAD_DISTANCES))
    if unknown_distances:
        raise ValueError(
            f"curvature_weights has no such lookahead distances: {unknown_distances}. "
            f"Known distances (metres): {CURVATURE_LOOKAHEAD_DISTANCES}")

    aux_weights = {
        "velocity_forward": velocity_forward_weight,
        "velocity_lateral": velocity_lateral_weight,
        **{curvature_aux_name(metres): curvature_weights.get(metres, 0.0)
           for metres in CURVATURE_LOOKAHEAD_DISTANCES},
        "wheel_slip_lf_forward": wheel_slip_front_forward_weight,
        "wheel_slip_rf_forward": wheel_slip_front_forward_weight,
        "wheel_slip_lf_lateral": wheel_slip_front_lateral_weight,
        "wheel_slip_rf_lateral": wheel_slip_front_lateral_weight,
        "wheel_slip_lr_forward": wheel_slip_rear_forward_weight,
        "wheel_slip_rr_forward": wheel_slip_rear_forward_weight,
        "wheel_slip_lr_lateral": wheel_slip_rear_lateral_weight,
        "wheel_slip_rr_lateral": wheel_slip_rear_lateral_weight,
        "angular_velocity_y": angular_velocity_y_weight,
    }

    writer = SummaryWriter(log_dir=f"runs/{name}")

    checkpoint_path = f"checkpoints/{name}.pt"
    os.makedirs(os.path.dirname(checkpoint_path), exist_ok=True)

    device = torch.device("cpu")
    print(f"Using device: {device}")

    gamma = 0.995
    lmbda = 0.97
    clip_epsilon = 0.2
    entropy_coeff = 0.0005
    frames_per_rollout = 512
    batch_size = 2048

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

    gae = GAE(
        gamma=gamma,
        lmbda=lmbda,
        value_network=model.get_value_operator(),
        average_gae=True,
        vectorized=True,
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
        entropy_bonus=entropy_coeff > 0,
        entropy_coeff=entropy_coeff,
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
    stats_history: list[dict[str, float]] = []
    try:
        # env.reset() lives inside this try (not before it) so a failure
        # here still reaches the finally below and closes the env instead
        # of orphaning its Unity worker subprocesses.
        tensordict: td.TensorDict = env.reset()

        # infinite loop until interrupted, unless max_iters bounds it
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

            print("Rollout batch size:", rollout.batch_size)

            save_rollout_buffer_start = time.perf_counter_ns()

            # flatten [T, num_envs, num_agents] into T * num_envs * num_agents samples
            flat_rollout = rollout.reshape(-1)

            print(flat_rollout.batch_size)
            num_samples = flat_rollout.shape[0]

            epochs_start = time.perf_counter_ns()

            loss_logs = []
            grad_norms = []
            for epochs in range(4):  # epochs
                shuffled = flat_rollout[torch.randperm(num_samples)]
                for batch_start in range(0, num_samples, batch_size):
                    minibatch = shuffled[batch_start:batch_start + batch_size]
                    optim.zero_grad()

                    minibatch = model.get_trunk_operator()(minibatch)

                    # compute the auxiliary losses and add them to the rollout
                    aux_head = model.get_aux_head()
                    minibatch = aux_head(minibatch)

                    loss: td.TensorDict = loss_module(minibatch)

                    aux_losses = td.TensorDict(dict(
                        velocity_forward=smooth_l1_loss(
                            minibatch["aux", "velocity_forward"], minibatch["agents", "velocity_forward"]),
                        velocity_lateral=smooth_l1_loss(
                            minibatch["aux", "velocity_lateral"], minibatch["agents", "velocity_lateral"]),
                        **{
                            curvature_aux_name(metres): smooth_l1_loss(
                                minibatch["aux", curvature_aux_name(metres)],
                                minibatch[track_curvature_key(metres)])
                            for metres in CURVATURE_LOOKAHEAD_DISTANCES
                        },
                        wheel_slip_lf_forward=smooth_l1_loss(
                            minibatch["aux", "wheel_slip_lf_forward"], minibatch["agents", "wheel_slip_forward_front_left"]),
                        wheel_slip_lf_lateral=smooth_l1_loss(
                            minibatch["aux", "wheel_slip_lf_lateral"], minibatch["agents", "wheel_slip_lateral_front_left"]),
                        wheel_slip_lr_forward=smooth_l1_loss(
                            minibatch["aux", "wheel_slip_lr_forward"], minibatch["agents", "wheel_slip_forward_back_left"]),
                        wheel_slip_lr_lateral=smooth_l1_loss(
                            minibatch["aux", "wheel_slip_lr_lateral"], minibatch["agents", "wheel_slip_lateral_back_left"]),
                        wheel_slip_rf_forward=smooth_l1_loss(
                            minibatch["aux", "wheel_slip_rf_forward"], minibatch["agents", "wheel_slip_forward_front_right"]),
                        wheel_slip_rf_lateral=smooth_l1_loss(
                            minibatch["aux", "wheel_slip_rf_lateral"], minibatch["agents", "wheel_slip_lateral_front_right"]),
                        wheel_slip_rr_forward=smooth_l1_loss(
                            minibatch["aux", "wheel_slip_rr_forward"], minibatch["agents", "wheel_slip_forward_back_right"]),
                        wheel_slip_rr_lateral=smooth_l1_loss(
                            minibatch["aux", "wheel_slip_rr_lateral"], minibatch["agents", "wheel_slip_lateral_back_right"]),
                        angular_velocity_y=smooth_l1_loss(
                            minibatch["aux", "angular_velocity_y"], minibatch["agents", "angular_velocity_y"])
                    ))

                    ppo_loss = loss["loss_entropy"] + \
                        loss["loss_critic"] + loss["loss_objective"]
                    aux_loss = sum(
                        0.5 * (
                            aux_weights[k] * aux_losses[k].mean(0)
                        ).sum()
                        for k in aux_weights
                    )

                    total_loss = (ppo_loss + aux_loss).mean()
                    total_loss.backward()
                    grad_norm = torch.nn.utils.clip_grad_norm_(
                        model.parameters(), 3.0).item()
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

            stats = rollout_stats(rollout)
            stats_history.append(stats)
            writer.add_scalar("reward/mean", stats["reward_mean"], i)
            writer.add_scalar(
                "reward/mean_forward_velocity", stats["velocity_forward_mean"], i)
            writer.add_scalar("reward/progress", stats["progress_mean"], i)
            writer.add_scalar("reward/collision_rate",
                              stats["collision_rate"], i)

            # every sampled action of this rollout (all steps, envs and agents)
            for action_name in ("throttle", "steering"):
                writer.add_histogram(
                    f"action/{action_name}", rollout["action", action_name].flatten(), i)

            if i % 10 == 0:
                save_checkpoint(i)

            if max_iters is not None and i - start_iter + 1 >= max_iters:
                break
    except KeyboardInterrupt:
        print("Interrupted — saving checkpoint before exit")
    finally:
        save_checkpoint(i)
        print(f"Checkpoint saved at iteration {i}")
        env.close()

    trailing = stats_history[-10:]
    avg_stats = {k: sum(d[k] for d in trailing) / len(trailing)
                 for k in trailing[0]} if trailing else {}

    # Time-normalised area under the reward-per-iteration curve (mean over
    # every iteration, not just the trailing window) -- rewards hyperparameters
    # that learn fast across the whole run, not just ones with a good final
    # plateau that got there slowly.
    all_rewards = [s["reward_mean"] for s in stats_history]
    avg_stats["reward_auc"] = sum(
        all_rewards) / len(all_rewards) if all_rewards else 0.0
    if all_rewards:
        writer.add_scalar("reward/auc", avg_stats["reward_auc"], i)

    return model, avg_stats


if __name__ == "__main__":
    SEED = 42
    is_mac = platform.system() == "Darwin"
    env = RoboRacerParallelEnvs(
        num_envs=2,
        file_name="TestUnityProject/Test Speed/build.app" if is_mac else "linux_build/build_linux.x86_64",
        num_stacked_frames=50,
        no_graphics=True,
        num_areas=4,
        time_scale=100.0,
        seed=SEED,
    )
    train(
        env,
        velocity_forward_weight=0.0,
        velocity_lateral_weight=0.0,
        curvature_weights={metres: 0.0
                           for metres in CURVATURE_LOOKAHEAD_DISTANCES},
        wheel_slip_front_forward_weight=0.0,
        wheel_slip_front_lateral_weight=0.0,
        wheel_slip_rear_forward_weight=0.0,
        wheel_slip_rear_lateral_weight=0.0,
        angular_velocity_y_weight=0.0,
        num_stacked_lidar_frames=50,  # 25Hz => 2s of history
        n_rays=101,
        lidar_conv="conv1d",
        ray_kernel=8,
        ray_stride=1,
        name="conv1d",
        seed=SEED,
    )
