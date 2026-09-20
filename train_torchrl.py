from mlagents_envs.side_channel.engine_configuration_channel import EngineConfigurationChannel
from torchrl.envs import TransformedEnv, UnityMLAgentsEnv, MarlGroupMapType
from torchrl.envs.utils import step_mdp
from torchrl.envs.transforms import Compose
from torchrl.envs.transforms import Transform
from torchrl.objectives import ClipPPOLoss
from torchrl.objectives.value import GAE
import tensordict as td
from torchrl.modules import ActorValueOperator
from torchrl.data import ReplayBuffer, LazyTensorStorage, SamplerWithoutReplacement
from model import actor, critic, trunk_tensordict_model
from visualize import LidarAndOccupancyGridVisualisation
import time
import torch
import os
from torch.utils.tensorboard import SummaryWriter

writer = SummaryWriter(log_dir=f"runs/torchrl_ppo")

torch.set_num_threads(8)

checkpoint_path = "checkpoints/latest.pt"
os.makedirs(os.path.dirname(checkpoint_path), exist_ok=True)

device = torch.device("cpu")
print(f"Using device: {device}")

num_agents = 24
agents = [f"agent_{i}" for i in range(num_agents)]


engine_channel = EngineConfigurationChannel()
engine_channel.set_configuration_parameters(time_scale=20.0, quality_level=0)
env = UnityMLAgentsEnv(
    file_name="linux_build/build_linux.x86_64",
    no_graphics=True,
    side_channels=[engine_channel],
    num_areas=num_agents,
    group_map=MarlGroupMapType.ALL_IN_ONE_GROUP
)


class StackAgents(Transform):
    def __init__(self, agents: list[str], lidar_num_tags, obs_keys=None, action_keys=("throttle", "steering")):
        if obs_keys is None:
            obs_keys = {
                "LIDAR1": "lidar",
                "VectorSensor_size40": "vector",
                # "GridSensor-OneHot": "occupancy_grid",
            }
        self.agents = agents
        self.obs_keys = obs_keys
        # not always present (e.g. missing on reset) — stacked opportunistically in _call
        self.extra_keys = (
            ("reward", env.reward_spec["agents", "agent_0", "reward"]),
            ("done", env.done_spec["agents", "agent_0", "done"]),
            # Counter-intuitive, I know...
            ("terminated", env.done_spec["agents", "agent_0", "terminated"]),
            ("truncated", env.done_spec["agents", "agent_0", "truncated"])
        )
        # RayPerceptionSensor emits [T_1..T_n, Miss, Distance] per ray, interleaved ray-by-ray
        self.lidar_num_tags = lidar_num_tags
        self.lidar_block_size = lidar_num_tags + 2
        # order matters — matches continuous_action dim order
        self.action_keys = action_keys

        in_keys = [("agents", agent, raw)
                   for agent in agents for raw in obs_keys]
        out_keys = [("agents", new) for new in obs_keys.values()]

        in_keys_inv = [("action", k) for k in action_keys]
        out_keys_inv = [("agents", agent, "continuous_action")
                        for agent in agents]

        super().__init__(
            in_keys=in_keys, out_keys=out_keys,
            in_keys_inv=in_keys_inv, out_keys_inv=out_keys_inv,
        )

    def _deinterleave_lidar(self, x):
        *batch, n = x.shape
        x = x.view(*batch, n // self.lidar_block_size, self.lidar_block_size)
        return x.movedim(-1, -2)

    def _call(self, tensordict):
        stack_dim = tensordict.batch_dims
        for raw, new in self.obs_keys.items():
            values = [tensordict["agents", agent, raw]
                      for agent in self.agents]
            if raw == "LIDAR1":
                values = [self._deinterleave_lidar(v) for v in values]
            stacked = torch.stack(values, dim=stack_dim)
            tensordict.set(("agents", new), stacked)

        for key, spec in self.extra_keys:
            stacked = torch.zeros(
                (len(self.agents), *spec.shape), dtype=spec.dtype, device=spec.device)
            for idx, agent in enumerate(self.agents):
                if ("agents", agent, key) in tensordict.keys(True, True):
                    stacked[idx, ...] = tensordict["agents", agent, key]
            tensordict.set(("agents", key), stacked)
        return tensordict

    def _reset(self, tensordict, tensordict_reset):
        return self._call(tensordict_reset)

    def _inv_call(self, tensordict):
        # tensordict["action", k] has shape (n_agents,) — stack into (n_agents, n_action_dims)
        actions = torch.stack(
            [tensordict["action", k] for k in self.action_keys], dim=-1
        )
        for i, agent in enumerate(self.agents):
            tensordict.set(("agents", agent, "continuous_action"), actions[i])
        return tensordict

    def transform_observation_spec(self, observation_spec):
        stack_dim = len(observation_spec.shape)
        for raw, new in self.obs_keys.items():
            per_agent_spec = observation_spec["agents", self.agents[0], raw]
            new_shape = list(per_agent_spec.shape)
            if raw == "LIDAR1":
                new_shape = new_shape[:-1] + \
                    [self.lidar_block_size, new_shape[-1] // self.lidar_block_size]
            new_shape.insert(stack_dim, len(self.agents))
            observation_spec["agents", new] = per_agent_spec.__class__(
                shape=torch.Size(new_shape),
                dtype=per_agent_spec.dtype,
                device=per_agent_spec.device,
            )
        return observation_spec


class ComposeReward(Transform):
    """Composes the per-step reward from raw values reported in the vector
    obs — F1TenthRacing.cs no longer calls AddReward for progress/speed
    shaping, it just exposes the raw numbers (unsigned forward speed at
    index 0, signed forward velocity at index 37, progress delta along the
    centerline spline at the last index).
    """

    # Track is 31.34 m long, so progress_weight=0.3 makes a full lap worth ~9.4.
    # collision_penalty (on top of Unity's -0.05) must dominate the discounted
    # sum of step penalties (0.0005 / (1 - gamma) = 0.05), otherwise crashing
    # early is as good as idling.
    def __init__(self, progress_weight=0.3, forward_velocity_weight=0.005, step_penalty=0.0005,
                 collision_penalty=1.0):
        super().__init__(
            in_keys=[
                ("agents", "reward"),
                ("agents", "vector"),
                ("agents", "terminated"),
            ],
            out_keys=[("agents", "reward")],
        )
        self.progress_weight = progress_weight
        self.forward_velocity_weight = forward_velocity_weight
        self.step_penalty = step_penalty
        self.collision_penalty = collision_penalty

    def _call(self, tensordict):
        vector = tensordict["agents", "vector"]
        forward_velocity = vector[..., 37]
        progress_delta = vector[..., -1]
        env_reward = tensordict["agents", "reward"].squeeze(-1)
        terminated = tensordict["agents", "terminated"].squeeze(-1).float()
        # on a collision step Unity returns before updating ProgressDelta, so
        # the value is stale — don't reward it
        progress_reward = progress_delta * self.progress_weight * (1.0 - terminated)
        forward_velocity_reward = forward_velocity * self.forward_velocity_weight
        step_penalty = torch.full_like(env_reward, -self.step_penalty)
        collision_penalty = -self.collision_penalty * terminated
        shaped = progress_reward + forward_velocity_reward + step_penalty + collision_penalty
        tensordict["agents", "reward"] = tensordict["agents",
                                                    "reward"] + shaped.unsqueeze(-1)
        tensordict["agents", "reward_components", "env"] = env_reward
        tensordict["agents", "reward_components", "progress"] = progress_reward
        tensordict["agents", "reward_components",
                   "forward_velocity"] = forward_velocity_reward
        tensordict["agents", "reward_components",
                   "step_penalty"] = step_penalty
        tensordict["agents", "reward_components",
                   "collision"] = collision_penalty
        return tensordict

    def _reset(self, tensordict, tensordict_reset):
        return self._call(tensordict_reset)


class PrintActions(Transform):
    def _inv_call(self, tensordict):
        print("Action sent to Unity:", tensordict["agents"]["agent_0"]
              ["continuous_action"], tensordict["agents"]["agent_1"]["continuous_action"])
        return tensordict


env = TransformedEnv(env, Compose(
    # PrintActions(),
    StackAgents(agents, lidar_num_tags=2),
    ComposeReward(),
))

gamma = 0.99
lmbda = 0.95
clip_epsilon = 0.2
entropy_epsilon = 0.01
frames_per_batch = 512
sub_batch_size = 256

model: ActorValueOperator = ActorValueOperator(
    trunk_tensordict_model,
    actor,
    critic,
).to(device)


optim = torch.optim.Adam(model.parameters(), lr=3e-4)

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
    loss_critic_type="smooth_l1",
)

loss_module.set_keys(
    reward=("agents", "reward"),
    done=("agents", "done"),
    terminated=("agents", "terminated"),
)

# viz = LidarAndOccupancyGridVisualisation(
#     lidar_shape=env.observation_spec["agents", "lidar"].shape,
#     velocity_shape=torch.Size((num_agents, 2)),
# )
# viz.show()


def save_checkpoint(iter_num):
    torch.save({
        "model": model.state_dict(),
        "optim": optim.state_dict(),
        "iter": iter_num,
    }, checkpoint_path)


i = start_iter - 1
try:
    for i in range(start_iter, 10000):
        batch = ReplayBuffer(
            storage=LazyTensorStorage(max_size=frames_per_batch * num_agents),
            sampler=SamplerWithoutReplacement(),
        )
        frames = []
        with torch.no_grad():
            print(f"Iteration {i} — collecting {frames_per_batch} frames...")
            # Run the environment for a number of frames
            start_time = time.time_ns()
            forward_time_ns = 0
            env_time_ns = 0
            for frame in range(frames_per_batch):
                per_agent_keys = [("agents", agent) for agent in agents] + \
                    [("next", "agents", agent) for agent in agents]

                t0 = time.time_ns()
                tensordict = model.get_policy_operator().forward(tensordict.to(device))
                if device.type != "cpu":
                    # forward pass is queued async on mps/cuda — force it to
                    # finish here so the timing isn't attributed to env.step
                    getattr(torch, device.type).synchronize()
                t1 = time.time_ns()
                tensordict = env.step(tensordict.cpu())
                t2 = time.time_ns()

                forward_time_ns += t1 - t0
                env_time_ns += t2 - t1

                # if frame % 10 == 0:
                #     viz.update(lidar=tensordict["agents", "lidar"], velocity=tensordict["agents", "vector"][:, 37:39])

                frames.append(tensordict.exclude(*per_agent_keys))
                tensordict = step_mdp(tensordict)
            total_time_ns = time.time_ns() - start_time
            print(
                f"Time taken for {frames_per_batch} frames: {total_time_ns / 1e9:.3f} seconds = {total_time_ns / frames_per_batch/1e6:.3f} ms/frame")
            print(f"  forward: {forward_time_ns / 1e9:.3f}s ({forward_time_ns / frames_per_batch / 1e6:.3f} ms/frame), "
                  f"env.step: {env_time_ns / 1e9:.3f}s ({env_time_ns / frames_per_batch / 1e6:.3f} ms/frame)")
        # (frames_per_batch, num_agents, ...)
        rollout = torch.stack(frames, dim=0)

        grad_norm = None
        for epoch in range(4):

            # (frames_per_batch * num_agents, ...) - i.e. flattened across time and *agents*
            data_view = gae(rollout.to(device), time_dim=0).reshape(-1)
            batch.extend(data_view)

            for sub_batch in range((frames_per_batch * num_agents) // sub_batch_size):
                subdata = batch.sample(sub_batch_size)
                loss_vals = loss_module(subdata.to(device))

                loss_val = (loss_vals["loss_objective"]
                            + loss_vals["loss_critic"]
                            + loss_vals["loss_entropy"])

                loss_val.backward()
                grad_norm = torch.nn.utils.clip_grad_norm_(
                    loss_module.parameters(), 1.0)
                optim.step()
                optim.zero_grad()

        writer.add_scalar("loss/objective",
                          loss_vals["loss_objective"].item(), i)
        writer.add_scalar("loss/critic", loss_vals["loss_critic"].item(), i)
        writer.add_scalar("loss/entropy", loss_vals["loss_entropy"].item(), i)
        writer.add_scalar("loss/total", loss_val.item(), i)
        writer.add_scalar("grad_norm", grad_norm.item(), i)
        writer.add_scalar("rollout/mean_reward",
                          rollout["agents", "reward"].mean().item(), i)
        for kind in ("env", "progress", "forward_velocity", "step_penalty", "collision"):
            writer.add_scalar(
                f"reward_components/{kind}",
                rollout["agents", "reward_components", kind].mean().item(), i)
        writer.add_scalar("rollout/avg_speed",
                          rollout["agents", "vector"][..., 0].mean().item(), i)
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
        v = rollout["agents", "vector"]          # (T, agents, 40)
        for k in range(v.shape[-1]):
            writer.add_scalar(f"obs_vector/mean_{k}", v[..., k].mean().item(), i)
            writer.add_scalar(f"obs_vector/std_{k}", v[..., k].std().item(), i)

        if i % 50 == 0:
            save_checkpoint(i)
except KeyboardInterrupt:
    print("Interrupted — saving checkpoint before exit")
finally:
    save_checkpoint(i)
    print(f"Checkpoint saved at iteration {i}")
    env.close()
