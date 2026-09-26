from mlagents_envs.side_channel.engine_configuration_channel import EngineConfigurationChannel
from torchrl.envs import set_exploration_type
from torchrl.envs.utils import ExplorationType, step_mdp
from torchrl.objectives import ClipPPOLoss
from torchrl.objectives.value import GAE
import tensordict as td
from torchrl.modules import ActorValueOperator
from torchrl.data import ReplayBuffer, LazyTensorStorage, SamplerWithoutReplacement
from environment import make_envs
from model import actor, critic, trunk_tensordict_model, aux, ActorValueAuxOperator
import time
import torch
import os
from torch.utils.tensorboard import SummaryWriter


def main():
    writer = SummaryWriter(log_dir=f"runs/torchrl_ppo")

    torch.set_num_threads(16)

    checkpoint_path = "checkpoints/latest.pt"
    os.makedirs(os.path.dirname(checkpoint_path), exist_ok=True)

    device = torch.device("cpu")
    print(f"Using device: {device}")
    num_envs = 1
    num_agents_per_env = 1
    agents = [f"agent_{i}" for i in range(num_agents_per_env)]

    env = make_envs(num_envs=num_envs, num_agents_per_env=num_agents_per_env)

    gamma = 0.99
    lmbda = 0.95
    clip_epsilon = 0.2
    entropy_epsilon = 0.001
    frames_per_batch = 512
    sub_batch_size = 128

    model: ActorValueAuxOperator = ActorValueAuxOperator(
        trunk_tensordict_model,
        actor,
        critic,
        aux,
    ).to(device)

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
        average_gae=True
    )
    gae.set_keys(
        reward=("agents", "reward"),
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
        reward=("agents", "reward"),
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
            minibatches_per_epoch = rows_per_iter // sub_batch_size
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
                    tensordict = step_mdp(tensordict)
                total_time_ns = time.time_ns() - start_time
                print(
                    f"Time taken for {frames_per_batch} frames: {total_time_ns / 1e9:.3f} seconds = {total_time_ns / frames_per_batch/1e6:.3f} ms/frame")
                print(f"  forward: {forward_time_ns / 1e9:.3f}s ({forward_time_ns / frames_per_batch / 1e6:.3f} ms/frame), "
                      f"env.step: {env_time_ns / 1e9:.3f}s ({env_time_ns / frames_per_batch / 1e6:.3f} ms/frame)")

            rollout = torch.stack(frames, dim=0)

            start_gradient_time = time.time_ns()
            data_view = gae(rollout.to(device), time_dim=0).reshape(-1)
            model.get_aux_operator().forward(data_view.to(device))
            batch.extend(data_view)

            for epoch in range(2):
                for sub_batch in range(minibatches_per_epoch):
                    subdata = batch.sample(sub_batch_size)
                    print(subdata)
                    ppo_loss_vals = loss_module(subdata.to(device))

                    loss_val = (
                        ppo_loss_vals["loss_objective"]
                        + ppo_loss_vals["loss_critic"]
                        + ppo_loss_vals["loss_entropy"]
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
            writer.add_scalar("loss/total", loss_val.item(), i)
            writer.add_scalar("rollout/mean_reward",
                              rollout["agents", "reward"].mean().item(), i)
            for kind in ("progress", "forward_velocity", "step_penalty", "collision"):
                writer.add_scalar(
                    f"reward_components/{kind}",
                    rollout["agents", "reward_components", kind].mean().item(), i)
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
    main()
