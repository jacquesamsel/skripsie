from torchrl.envs.transforms import Transform
from torchrl.envs import TransformedEnv, UnityMLAgentsEnv, MarlGroupMapType, ParallelEnv, Compose
import torch
from mlagents_envs.side_channel.engine_configuration_channel import EngineConfigurationChannel

def make_env(worker_id: int, num_agents: int):
    engine_channel = EngineConfigurationChannel()
    engine_channel.set_configuration_parameters(
        time_scale=20.0, quality_level=0)
    env = UnityMLAgentsEnv(
        file_name="linux_build/build_linux.x86_64",
        no_graphics=True,
        side_channels=[engine_channel],
        num_areas=num_agents,
        group_map=MarlGroupMapType.ALL_IN_ONE_GROUP,
        # each Unity instance needs its own port (base_port 5005 + worker_id)
        worker_id=worker_id,
    )
    return env


def make_envs(num_envs: int, num_agents_per_env: int):
    agents = [f"agent_{i}" for i in range(num_agents_per_env)]
    env = ParallelEnv(
        num_envs, make_env,
        create_env_kwargs=[
            {"worker_id": k, "num_agents": num_agents_per_env} for k in range(num_envs)],
    )

    return TransformedEnv(
        env,
        Compose(
            # PrintActions(),
            StackAgents(env, agents, lidar_num_tags=2),
            SplitVectorObservation(),
            ComposeReward(),
        )
    )


class StackAgents(Transform):
    def __init__(self, base_env, agents: list[str], lidar_num_tags, obs_keys=None, action_keys=("throttle", "steering")):
        if obs_keys is None:
            obs_keys = {
                "LIDAR1": "lidar",
                "VectorSensor_size37": "vector",
                # "GridSensor-OneHot": "occupancy_grid",
            }
        self.agents = agents
        self.obs_keys = obs_keys
        # not always present (e.g. missing on reset) — stacked opportunistically in _call.
        # Specs of a batched env include the env batch dims, so keep only the
        # per-agent feature shape here; the batch dims are added back in _call.
        n_batch = len(base_env.batch_size)
        specs = (
            ("reward", base_env.reward_spec["agents", "agent_0", "reward"]),
            ("done", base_env.done_spec["agents", "agent_0", "done"]),
            # Counter-intuitive, I know...
            ("terminated",
             base_env.done_spec["agents", "agent_0", "terminated"]),
            ("truncated", base_env.done_spec["agents", "agent_0", "truncated"])
        )
        self.extra_keys = tuple(
            (key, spec.shape[n_batch:], spec.dtype, spec.device)
            for key, spec in specs
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

        batch_size = tensordict.batch_size
        batch_idx = (slice(None),) * len(batch_size)
        for key, feature_shape, dtype, device in self.extra_keys:
            # (*env_batch, n_agents, *feature_shape)
            stacked = torch.zeros(
                (*batch_size, len(self.agents), *feature_shape), dtype=dtype, device=device)
            for idx, agent in enumerate(self.agents):
                if ("agents", agent, key) in tensordict.keys(True, True):
                    stacked[(*batch_idx, idx)
                            ] = tensordict["agents", agent, key]
            tensordict.set(("agents", key), stacked)
        return tensordict

    def _reset(self, tensordict, tensordict_reset):
        return self._call(tensordict_reset)

    def _inv_call(self, tensordict):
        # tensordict["action", k] has shape (*env_batch, n_agents) — stack into
        # (*env_batch, n_agents, n_action_dims)
        actions = torch.stack(
            [tensordict["action", k] for k in self.action_keys], dim=-1
        )
        for i, agent in enumerate(self.agents):
            tensordict.set(("agents", agent, "continuous_action"),
                           actions[..., i, :])
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


class SplitVectorObservation(Transform):
    LAYOUT = (
        ("speed", 1),
        ("cur_steering_angle", 1),
        ("cur_throttle", 1),
        ("pos", 3),
        ("wheel_ticks", 2),
        ("wheel_angles", 2),
        ("orientation_quaternion", 4),
        ("euler_angles", 3),
        ("angular_velocity", 3),
        ("linear_acceleration", 3),
        ("wheel_slips", 8),
        ("velocity_forward", 1),
        ("velocity_lateral", 1),
        ("progress", 1),
        ("curvature", 3),
    )

    def __init__(self, vector_key=("agents", "vector")):
        self.vector_key = tuple(vector_key)
        out_keys = [("agents", name) for name, _ in self.LAYOUT]
        super().__init__(in_keys=[self.vector_key], out_keys=out_keys)

    def _split(self, vector):
        offset = 0
        for name, size in self.LAYOUT:
            value = vector[..., offset:offset + size]
            if name == "wheel_slips":
                value = value.reshape(*value.shape[:-1], 4, 2)
            yield name, value
            offset += size

    def _call(self, tensordict):
        vector = tensordict[self.vector_key]
        for name, value in self._split(vector):
            tensordict.set(("agents", name), value)
        del tensordict[self.vector_key]
        return tensordict

    def _reset(self, tensordict, tensordict_reset):
        return self._call(tensordict_reset)

    def transform_observation_spec(self, observation_spec):
        vector_spec = observation_spec[self.vector_key]
        offset = 0
        for name, size in self.LAYOUT:
            shape = list(vector_spec.shape[:-1]) + [size]
            if name == "wheel_slips":
                shape = shape[:-1] + [4, 2]
            observation_spec["agents", name] = vector_spec.__class__(
                shape=torch.Size(shape),
                dtype=vector_spec.dtype,
                device=vector_spec.device,
            )
            offset += size
        del observation_spec[self.vector_key]
        return observation_spec


class ComposeReward(Transform):
    def __init__(self,
                 progress_weight=1.0,
                 forward_velocity_weight=0.0,
                 step_penalty=0.002,
                 collision_penalty=0.2
                ):
        super().__init__(
            in_keys=[
                ("agents", "reward"),
                ("agents", "velocity_forward"),
                ("agents", "progress"),
                ("agents", "terminated"),
            ],
            out_keys=[("agents", "reward")],
        )
        self.progress_weight = progress_weight
        self.forward_velocity_weight = forward_velocity_weight
        self.step_penalty = step_penalty
        self.collision_penalty = collision_penalty

    def _call(self, tensordict):
        # velocity is [forward, lateral] (signed, m/s); see SplitVectorObservation.LAYOUT
        forward_velocity = tensordict["agents", "velocity_forward"].squeeze(-1)
        progress_delta = tensordict["agents", "progress"].squeeze(-1)
        env_reward = tensordict["agents", "reward"].squeeze(-1)
        terminated = tensordict["agents", "terminated"].squeeze(-1).float()
        # on a collision step Unity returns before updating ProgressDelta, so
        # the value is stale — don't reward it
        progress_reward = progress_delta * \
            self.progress_weight * (1.0 - terminated)
        forward_velocity_reward = forward_velocity * self.forward_velocity_weight
        step_penalty = torch.full_like(env_reward, -self.step_penalty)
        collision_penalty = -self.collision_penalty * terminated
        shaped = progress_reward + forward_velocity_reward + \
            step_penalty + collision_penalty
        tensordict["agents", "reward"] = shaped.unsqueeze(-1)
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
