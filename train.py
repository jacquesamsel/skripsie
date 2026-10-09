from typing import Literal

from torch.utils.tensorboard import SummaryWriter
import time
from model import ActorValueAuxOperator, make_model, make_or_load_model, save_model
from environment import (
    RoboRacerEnv,
    RoboRacerParallelEnvs
)
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

from utils import AUX_HEAD_KEYS, gen_aux_losses, gen_aux_weights_default_zero, load_aux_head_scaling_factors, rollout_stats


def train(
        env: RoboRacerEnv | RoboRacerParallelEnvs,
        aux_weights: dict[str, float],
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
    random.seed(seed)
    torch.manual_seed(seed)

    if any(aux_weights.get(name) == None for name in AUX_HEAD_KEYS):
        raise ValueError(
            f"aux_weights must contain all keys in AUX_HEAD_KEYS: {AUX_HEAD_KEYS}")

    writer = SummaryWriter(log_dir=f"runs/{name}")

    device = torch.device("cpu")
    print(f"Using device: {device}")

    gamma = 0.995
    lmbda = 0.97
    clip_epsilon = 0.2
    entropy_coeff = 0.0005
    frames_per_rollout = 512
    batch_size = 2048

    model, model_config, start_iter, optim_state_dict = make_or_load_model(
        name=name,
        num_stacked_lidar_frames=num_stacked_lidar_frames,
        n_rays=n_rays,
        lidar_conv=lidar_conv,
        ray_kernel=ray_kernel,
        ray_stride=ray_stride,
        time_kernel=time_kernel,
        time_stride=time_stride,
    )
    optim = torch.optim.Adam(model.parameters(), lr=1e-4)
    if optim_state_dict is not None:
        optim.load_state_dict(optim_state_dict)

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

    aux_weights_scaling_factors = load_aux_head_scaling_factors("results/aux_head_scaling_factors.json")

    i = start_iter - 1
    stats_history: list[dict[str, float]] = []
    try:
        tensordict: td.TensorDict = env.reset()

        for i in itertools.count(start=start_iter):
            # Collect the rollout
            steps = []

            rollout_start = time.perf_counter_ns()
            with torch.no_grad(), set_exploration_type(ExplorationType.RANDOM):
                for frame in range(frames_per_rollout):
                    tensordict = env.step(
                        model.get_policy_operator()(tensordict))

                    # Don't store next-step observations in the rollout
                    steps.append(tensordict.exclude(("next", "agents", "lidar_stack"), ("next", "agents", "lidar")))
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
            num_samples = flat_rollout.shape[0]

            epochs_start = time.perf_counter_ns()

            loss_logs = []
            grad_norms = []
            for epochs in range(4):  # epochs

                # randomly shuffle the rollout
                shuffled = flat_rollout[torch.randperm(num_samples)]

                # do minibatch updates
                for batch_start in range(0, num_samples, batch_size):
                    minibatch = shuffled[batch_start:batch_start + batch_size]
                    optim.zero_grad()

                    minibatch = model.get_trunk_operator()(minibatch)

                    # compute the auxiliary losses and add them to the rollout
                    aux_head = model.get_aux_head()
                    minibatch = aux_head(minibatch)

                    loss: td.TensorDict = loss_module(minibatch)

                    aux_losses = gen_aux_losses(minibatch, aux_weights_scaling_factors)

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
                        model.parameters(), 6.0).item()
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

            writer.add_scalar("reward/progress",
                              stats["reward_progress_mean"], i)
            writer.add_scalar(
                "reward/forward_velocity", stats["reward_velocity_forward_mean"], i)
            writer.add_scalar("reward/collision",
                              stats["reward_collision_mean"], i)
            writer.add_scalar(
                "reward/step_penalty", stats["reward_step_penalty_mean"], i)

            writer.add_scalar("observation/progress_metres",
                              stats["progress_mean"], i)
            writer.add_scalar("observation/forward_velocity",
                              stats["velocity_forward_mean"], i)

            writer.add_scalar("collision/per_episode",
                              stats["collision_rate_per_episode"], i)
            writer.add_scalar("collision/per_step",
                              stats["collision_rate_per_step"], i)

            # every sampled action of this rollout (all steps, envs and agents)
            for action_name in ("throttle", "steering"):
                writer.add_histogram(
                    f"action/{action_name}", rollout["action", action_name].flatten(), i)

            if i % 10 == 0:
                save_model(model, model_config, optim.state_dict(), i, name)

            if max_iters is not None and i - start_iter + 1 >= max_iters:
                break
    except KeyboardInterrupt:
        print("Interrupted — saving checkpoint before exit")
    finally:
        save_model(model, model_config, optim.state_dict(), i, name)
        print(f"Checkpoint saved at iteration {i}")
        env.close()
        while not env.is_closed:
            time.sleep(0.1)

    trailing = stats_history[-10:]
    avg_stats = {k: sum(d[k] for d in trailing) / len(trailing)
                 for k in trailing[0]} if trailing else {}


if __name__ == "__main__":
    SEED = 44
    is_mac = platform.system() == "Darwin"
    env = RoboRacerParallelEnvs(
        num_envs=1,
        file_name="TestUnityProject/Test Speed/build.app" if is_mac else "linux_build/linux_build.x86_64",
        num_stacked_frames=50,
        no_graphics=True,
        num_areas=1,
        time_scale=100.0,
        start_worker_id=0,
        seed=SEED,
    )
    train(
        env,
        aux_weights=gen_aux_weights_default_zero({}),
        num_stacked_lidar_frames=50,  # 25Hz => 2s of history
        n_rays=101,
        lidar_conv="conv1d",
        ray_kernel=8,
        ray_stride=1,
        name="conv1d_fixed_lidar_try_2",
        seed=SEED,
    )
