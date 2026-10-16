import tqdm
from torch.utils.tensorboard import SummaryWriter
import time
from model import ActorValueAuxOperator, make_or_load_model, save_model
from environment import (
    RoboRacerEnv,
    RoboRacerParallelEnvs
)
import tensordict as td
from torchrl.objectives.value import GAE
from torchrl.objectives import ClipPPOLoss
from torchrl.envs.utils import ExplorationType
from torchrl.envs import set_exploration_type
import platform
import random
import torch
import itertools
import pandas as pd
from utils import AUX_HEAD_KEYS, gen_aux_losses, gen_aux_weights_default_zero, get_aux_head_r2_scores, load_aux_head_scaling_factors, rollout_stats
from dataclasses import dataclass

@dataclass(frozen=True)
class TrainParams:
    aux_weights: dict[str, float]
    seed: int
    num_threads: int
    name: str | None
    num_stacked_lidar_frames: int = 50
    n_rays: int = 101
    ray_kernel: int = 8
    ray_stride: int = 1
    max_iters: int | None = None
    show_rollout_progress: bool = False
    rollout_length: int = 512

def train(
        env: RoboRacerEnv | RoboRacerParallelEnvs,
        params: TrainParams
) -> ActorValueAuxOperator:
    torch.set_num_threads(params.num_threads)
    random.seed(params.seed)
    torch.manual_seed(params.seed)

    if any(params.aux_weights.get(name) == None for name in AUX_HEAD_KEYS):
        raise ValueError(
            f"aux_weights must contain all keys in AUX_HEAD_KEYS: {AUX_HEAD_KEYS}")

    writer = SummaryWriter(log_dir=f"runs/{params.name}") if params.name else None

    gamma = 0.995
    lmbda = 0.97
    clip_epsilon = 0.2
    entropy_coeff = 0.0005
    batch_size = 2048
    model, model_config, start_iter, optim_state_dict = make_or_load_model(
        name=params.name,
        num_stacked_lidar_frames=params.num_stacked_lidar_frames,
        n_rays=params.n_rays,
        ray_kernel=params.ray_kernel,
        ray_stride=params.ray_stride,
    )
    optim = torch.optim.Adam(model.parameters(), lr=1e-4)
    if optim_state_dict is not None:
        optim.load_state_dict(optim_state_dict)

    gae = GAE(
        gamma=gamma,
        lmbda=lmbda,
        value_network=None,
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

    aux_weights_scaling_factors = load_aux_head_scaling_factors(
        "results/aux_head_scaling_factors.json")

    tensordict: td.TensorDict = env.reset()
    start_time = time.perf_counter_ns()

    save_every = 10
    if params.name is not None:
        save_model(model, model_config, optim.state_dict(), start_iter, params.name)

    for i in itertools.count(start=start_iter) if params.max_iters is None else range(start_iter, params.max_iters):
        # Collect the rollout
        steps = []

        rollout_start = time.perf_counter_ns()
        with torch.no_grad(), set_exploration_type(ExplorationType.RANDOM):
            for frame in tqdm.trange(params.rollout_length, disable=not params.show_rollout_progress, desc=f"Rollout {i}"):
                tensordict = env.step(
                    model.get_policy_operator()(tensordict))

                # Don't store next-step observations in the rollout
                steps.append(tensordict.exclude(
                    ("next", "agents", "stacked_lidar"), ("next", "agents", "lidar")))
                tensordict = env.step_mdp(tensordict)

        stack_rollout_start = time.perf_counter_ns()
        # [T, num_envs, num_agents, ...]
        rollout = torch.stack(steps, dim=0)
        print(f"Rollout size: {rollout.bytes()} bytes")
        gae_start = time.perf_counter_ns()

        with torch.no_grad():
            value_op = model.get_value_operator()
            # V(s_t) for t = 0..T-1
            values = value_op(rollout.select(*value_op.in_keys))["state_value"]
            # V(s_T): the observation after the last step is the root of `tensordict`
            last_value = value_op(tensordict.select(*value_op.in_keys))["state_value"]

            rollout["state_value"] = values
            rollout["next", "state_value"] = torch.cat([values[1:], last_value.unsqueeze(0)], dim=0)
            rollout = gae(rollout)
        print("Rollout batch size:", rollout.batch_size)

        save_rollout_buffer_start = time.perf_counter_ns()

        # flatten [T, num_envs, num_agents] into T * num_envs * num_agents samples
        flat_rollout = rollout.reshape(-1)
        num_samples = flat_rollout.shape[0]

        epochs_start = time.perf_counter_ns()

        logs = []
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

                aux_losses = gen_aux_losses(
                    minibatch, aux_weights_scaling_factors)
                r2_scores = get_aux_head_r2_scores(
                    minibatch["aux"], minibatch["agents"], aux_weights_scaling_factors)

                ppo_loss = loss["loss_entropy"] + \
                    loss["loss_critic"] + loss["loss_objective"]
                aux_loss = sum(
                    (
                        params.aux_weights[k] * aux_losses[k]
                    )
                    for k in params.aux_weights if params.aux_weights[k] > 0.0
                )

                total_loss = (ppo_loss + aux_loss).mean()

                grad_logs = {}
                if batch_start == 0:
                    h = minibatch["hidden_layer"]
                    g_policy = torch.autograd.grad(
                        loss["loss_objective"], h, retain_graph=True)[0].flatten()
                    g_value = torch.autograd.grad(
                        loss["loss_critic"], h, retain_graph=True)[0].flatten()
                    grad_logs = {
                        "grad/norm_policy": g_policy.norm().item(),
                        "grad/norm_value": g_value.norm().item(),
                        "grad/cos_value_policy": torch.nn.functional.cosine_similarity(
                            g_value, g_policy, dim=0).item(),
                    }
                    active_aux_keys = [
                        k for k in params.aux_weights if params.aux_weights[k] > 0.0]
                    g_aux_total = torch.zeros_like(g_policy)
                    for k in active_aux_keys:
                        g_aux = torch.autograd.grad(
                            params.aux_weights[k] * aux_losses[k], h, retain_graph=True)[0].flatten()
                        grad_logs |= {
                            f"grad/norm_aux_{k}": g_aux.norm().item(),
                            f"grad/cos_aux_policy_{k}": torch.nn.functional.cosine_similarity(
                                g_aux, g_policy, dim=0).item(),
                            f"grad/cos_aux_value_{k}": torch.nn.functional.cosine_similarity(
                                g_aux, g_value, dim=0).item(),
                        }
                        g_aux_total += g_aux
                    if active_aux_keys:
                        grad_logs |= {
                            "grad/norm_aux": g_aux_total.norm().item(),
                            "grad/cos_aux_policy": torch.nn.functional.cosine_similarity(
                                g_aux_total, g_policy, dim=0).item(),
                            "grad/cos_aux_value": torch.nn.functional.cosine_similarity(
                                g_aux_total, g_value, dim=0).item(),
                        }

                total_loss.backward()
                grad_norm = torch.nn.utils.clip_grad_norm_(
                    model.parameters(), 6.0).item()
                optim.step()

                # Do logging for this minibatch
                logs.append(
                    {
                        "total_loss": total_loss.detach().item(),
                        "grad_norm": grad_norm,
                    }
                    | {f"loss/{k}": loss[k].detach().item() for k in loss.keys(leaves_only=True)}
                    | {
                        f"loss/aux_{k}": aux_losses[k].mean().detach().item() for k in AUX_HEAD_KEYS
                    }
                    | {
                        f"aux/r2_score_{k}": r2_scores[k].detach().item() for k in r2_scores
                    }
                    | grad_logs
                )

        # average the per-minibatch logs over the whole iteration
        avg_logs = pd.DataFrame(logs).mean().to_dict()

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
                    f"{seconds * 1e3 / params.rollout_length:9.2f} ms/frame")

        stats = rollout_stats(rollout)
        if writer is not None:
            for stage, seconds in timings.items():
                if stage != "total":
                    writer.add_scalar(f"time/{stage}", seconds, i)
            
            for log in avg_logs:
                writer.add_scalar(log, avg_logs[log], i)
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

        iters_done = i + 1
        if iters_done % save_every == 0 and params.name is not None:
            save_model(model, model_config, optim.state_dict(), iters_done, params.name)
    return time.perf_counter_ns() - start_time



if __name__ == "__main__":
    SEED = 42
    is_mac = platform.system() == "Darwin"
    env = RoboRacerParallelEnvs(
        num_envs=8,
        file_name="TestUnityProject/Test Speed/build.app" if is_mac else "linux_build/linux_build.x86_64",
        num_stacked_frames=50,
        no_graphics=True,
        num_areas=6,
        time_scale=1000.0,
        start_worker_id=0,
        seed=SEED,
    )
    try:
        train(
            env,
            params=TrainParams(
                aux_weights=gen_aux_weights_default_zero({}),
                name=None,
                seed=SEED,
                rollout_length=512,
                num_threads=16,
                show_rollout_progress=True
            )
        )
    finally:
        env.close()
