from functools import reduce

from torchrl.envs.transforms import Transform, Stack, UnaryTransform, ExcludeTransform, RenameTransform, UnsqueezeTransform
from torchrl.envs import CatFrames, TransformedEnv, UnityMLAgentsEnv, MarlGroupMapType, ParallelEnv, Compose
from torchrl.data import Bounded, Unbounded, UnboundedContinuous
import torch
from mlagents_envs.side_channel.engine_configuration_channel import EngineConfigurationChannel
import tensordict as td
from tensordict import is_tensor_collection
import platform


def make_env(worker_id: int, num_agents: int, time_scale: float, quality_level=0):
    engine_channel = EngineConfigurationChannel()
    engine_channel.set_configuration_parameters(
        time_scale=time_scale, quality_level=quality_level)
    env = UnityMLAgentsEnv(
        file_name="AutoDrive/build.app" if platform.system() == "Darwin" else "linux_build/build_linux.x86_64",
        no_graphics=platform.system() != "Darwin",
        side_channels=[engine_channel],
        num_areas=num_agents,
        group_map=MarlGroupMapType.ALL_IN_ONE_GROUP,
        # each Unity instance needs its own port (base_port 5005 + worker_id)
        worker_id=worker_id,
    )
    return env


def make_envs(num_envs: int, num_agents_per_env: int, num_stacked_frames: int, time_scale: float, quality_level: int = 0):
    agents = [f"agent_{i}" for i in range(num_agents_per_env)]
    env = ParallelEnv(
        num_envs, make_env,
        create_env_kwargs=[
            {
                "worker_id": k,
                "num_agents": num_agents_per_env,
                "time_scale": time_scale,
                "quality_level": quality_level
            } for k in range(num_envs)],
    ) if num_envs > 1 else make_env(0, num_agents_per_env, time_scale, quality_level)

    LIDAR_NUM_TAGS = 2
    LIDAR_BLOCK = LIDAR_NUM_TAGS + 2  # [Tag_1..Tag_n, Miss, Distance]

    done_stack = Stack(
        in_keys=[("agents", a, "done") for a in agents],
        out_key=("agents", "done"), dim=-2, del_keys=True,
        in_key_inv=("agents", "_reset"),
        out_keys_inv=[("agents", a, "_reset") for a in agents],
    )
    # also run the unstack on reset, not just on step
    done_stack.enable_inv_on_reset = True

    return TransformedEnv(
        env,
        Compose(
            *[
                Stack(in_keys=[("agents", a, key) for a in agents],
                      out_key=("agents", key), dim=-2, del_keys=True)
                for key in ["LIDAR1", "VectorSensor_size37"]
            ],
            done_stack,  # also unstacks the "_reset" flag per agent on reset
            *[
                Stack(in_keys=[("agents", a, key) for a in agents],
                      out_key=("agents", key), dim=-2, del_keys=True)
                for key in ["terminated", "truncated"]
            ],
            # Unity's own reward is only used as the crash signal (see ComposeReward)
            StackIfPresent(in_keys=[("agents", a, "reward") for a in agents],
                           out_key=("agents", "unity_reward"), dim=-2, del_keys=True),
            RenameTransform(in_keys=[("agents", "VectorSensor_size37")], out_keys=[
                            ("agents", "vector")]),
            # de-interleave the lidar tensor so that it can be processed by Conv1d
            UnaryTransform(
                in_keys=[("agents", "LIDAR1")],
                out_keys=[("agents", "lidar")],
                # (..., n_rays * block) -> (..., n_rays, block) -> (..., block, n_rays)
                fn=lambda x: x.unflatten(
                    -1,
                    (-1, LIDAR_BLOCK)
                ).transpose(-1, -2),
            ),
            ExcludeTransform(
                ("agents", "LIDAR1"),
                *[("agents", agent, "group_reward") for agent in agents],
            ),
            SplitVector(
                layout=[
                    (("agents", "speed"), torch.Size([1])),
                    (("agents", "cur_steering_angle"), torch.Size([1])),
                    (("agents", "cur_throttle"), torch.Size([1])),
                    (("agents", "pos"), torch.Size([3])),
                    (("agents", "wheel_ticks"), torch.Size([2])),
                    (("agents", "wheel_angles"), torch.Size([2])),
                    (("agents", "orientation_quaternion"), torch.Size([4])),
                    (("agents", "euler_angles"), torch.Size([3])),
                    (("agents", "angular_velocity"), torch.Size([3])),
                    (("agents", "linear_acceleration"), torch.Size([3])),
                    (("agents", "wheel_slips"), torch.Size(
                        [4, 2])),  # [FL_fw, FL_lat, ...]
                    (("agents", "velocity_forward"), torch.Size([1])),
                    (("agents", "velocity_lateral"), torch.Size([1])),
                    (("agents", "progress"), torch.Size([1])),
                    (("agents", "curvature"), torch.Size([3])),
                ],
                in_key=("agents", "vector"),
                delete_vector=True
            ),
            ComposeReward(
                progress_weight=1.0,
                forward_velocity_weight=0.0,
                step_penalty=0.002,
                collision_penalty=0.2
            ),
            ExcludeTransform(("agents", "unity_reward")),
            # Add an extra dim to the lidar tensor so that it can be stacked with CatFrames
            UnsqueezeTransform(
                dim=-3,
                in_keys=[("agents", "lidar")],
                out_keys=[("agents", "lidar")]
            ),
            CatFrames(N=num_stacked_frames,
                      dim=-3,
                      in_keys=[("agents", "lidar")],
                      out_keys=[("agents", "stacked_lidar")],
                      done_key=("agents", "done"),
                      reset_key=("agents", "_reset")
                      ),
            PackActions(agents=agents),
            # Must stay last: declares the "agents" group as batched over the agents
            AgentBatch(num_agents_per_env),
        )
    )


class SplitVector(Transform):
    def __init__(self, layout: list[tuple[td.NestedKey, torch.Size]], in_key: td.NestedKey, delete_vector: bool = False):
        super().__init__(in_keys=[in_key], out_keys=[key for key, _ in layout])
        self.layout = layout
        self.delete_vector = delete_vector
        self.in_key = in_key

    def _call(self, tensordict: td.TensorDict) -> td.TensorDict:
        offset = 0
        vector = tensordict[self.in_key]
        for key, shape in self.layout:
            # find length of block
            end = offset + reduce(lambda x, y: x * y, shape)
            data = vector[..., offset:end]
            if len(shape) > 1:
                data = data.reshape(*data.shape[:-1], *shape)
            tensordict.set(key, data)
            offset = end
        if self.delete_vector:
            del tensordict[self.in_key]
        return tensordict

    def _reset(self, tensordict: td.TensorDict, tensordict_reset: td.TensorDict) -> td.TensorDict:
        return self._call(tensordict_reset)

    def transform_observation_spec(self, observation_spec):
        vector_spec = observation_spec[self.in_key]
        batch = vector_spec.shape[:-1]
        if self.delete_vector:
            del observation_spec[self.in_key]
        observation_spec.update({
            key: UnboundedContinuous(
                shape=(*batch, *shape), dtype=vector_spec.dtype, device=vector_spec.device)
            for key, shape in self.layout
        })
        return observation_spec


class ComposeReward(Transform):
    """Shaped per-agent reward. A car has crashed when Unity's own reward for it is negative."""

    def __init__(
            self,
            progress_weight: float,
            forward_velocity_weight: float,
            step_penalty: float,
            collision_penalty: float):
        super().__init__(
            in_keys=[
                ("agents", "velocity_forward"),
                ("agents", "progress"),
                ("agents", "unity_reward"),
            ],
            out_keys=[("agents", "reward")],
        )
        self.progress_weight = progress_weight
        self.forward_velocity_weight = forward_velocity_weight
        self.step_penalty = step_penalty
        self.collision_penalty = collision_penalty

    def _call(self, tensordict: td.TensorDict) -> td.TensorDict:
        forward_velocity = tensordict["agents", "velocity_forward"].squeeze(-1)
        progress_delta = tensordict["agents", "progress"].squeeze(-1)
        crashed = (
            tensordict["agents", "unity_reward"].squeeze(-1) < 0).float()
        progress_reward = progress_delta * \
            self.progress_weight * (1.0 - crashed)
        forward_velocity_reward = forward_velocity * self.forward_velocity_weight
        step_penalty = torch.full((), -self.step_penalty)
        collision_penalty = -self.collision_penalty * crashed
        shaped = progress_reward + forward_velocity_reward + \
            step_penalty + collision_penalty
        tensordict["agents", "reward"] = shaped.unsqueeze(-1)
        return tensordict

    def transform_output_spec(self, output_spec):
        output_spec = output_spec.clone()
        obs = output_spec["full_observation_spec",
                          "agents", "velocity_forward"]
        output_spec["full_reward_spec", "agents", "reward"] = Unbounded(
            shape=(*obs.shape[:-1], 1), dtype=torch.float32, device=obs.device)
        return output_spec


class StackIfPresent(Stack):
    """Stack that leaves the reset output alone when none of its keys are there.

    Unity's reset output has no reward, and a plain Stack would call torch.stack([]) on it.
    """

    def _reset(self, tensordict, tensordict_reset):
        if all(tensordict_reset.get(key, None) is None for key in self.in_keys):
            return tensordict_reset
        return super()._reset(tensordict, tensordict_reset)


class AgentBatch(Transform):
    """Makes the whole env batched over agents: env batch size [N] -> [N, num_agents].

    Must be the last transform in the Compose. Every entry the transforms before it produce
    has the agent dim right after the env dim, so from the outside every tensor (observations,
    reward, done, and the policy's actions/values/log-probs) shares the batch [N, num_agents].
    Inverses run in reverse order, so its inverse runs first and hands the transforms before it
    (and the wrapped ParallelEnv) plain [N]-batched data again.
    """
    enable_inv_on_reset = True

    def __init__(self, num_agents: int):
        super().__init__()
        self.num_agents = num_agents

    def transform_env_batch_size(self, batch_size):
        return torch.Size([*batch_size, self.num_agents])

    @staticmethod
    def _set_batch_size(tensordict, batch_size):
        """Sets the batch size of a tensordict and every tensordict nested in it (in place)."""
        grow = len(batch_size) > len(tensordict.batch_size)
        if not grow:  # a parent can't be larger than its children, so shrink top-down
            tensordict.batch_size = batch_size
        for key in list(tensordict.keys()):
            child = tensordict.get(key)
            if is_tensor_collection(child):
                AgentBatch._set_batch_size(child, batch_size)
        if grow:  # ... and grow bottom-up
            tensordict.batch_size = batch_size
        return tensordict

    def _call(self, next_tensordict):
        return self._set_batch_size(
            next_tensordict, torch.Size([*next_tensordict.batch_size, self.num_agents]))

    def _reset(self, tensordict, tensordict_reset):
        return self._call(tensordict_reset)

    def _inv_call(self, tensordict):
        return self._set_batch_size(
            tensordict.copy(), torch.Size(tensordict.batch_size[:-1]))

    def _label_spec(self, spec):
        spec.shape = (*spec.shape, self.num_agents)
        return spec

    def transform_observation_spec(self, observation_spec):
        return self._label_spec(observation_spec)

    def transform_reward_spec(self, reward_spec):
        return self._label_spec(reward_spec)

    def transform_done_spec(self, done_spec):
        return self._label_spec(done_spec)

    def transform_output_spec(self, output_spec):
        output_spec = super().transform_output_spec(output_spec)
        return self._label_spec(output_spec)

    def transform_input_spec(self, input_spec):
        self._label_spec(input_spec["full_action_spec"])
        self._label_spec(input_spec["full_state_spec"])
        return self._label_spec(input_spec)


class PackActions(Transform):
    """Policy throttle/steering [.., N] -> per-agent ("agents", a, "continuous_action") [.., 2]."""

    def __init__(self, agents: list[str]):
        super().__init__()
        self.agents = agents

    def _inv_call(self, tensordict):
        packed = torch.stack(
            [tensordict["action", "throttle"], tensordict["action", "steering"]], dim=-1)  # [.., N, 2]
        tensordict = tensordict.copy()
        for i, agent in enumerate(self.agents):
            tensordict.set(
                ("agents", agent, "continuous_action"), packed[..., i, :])
        return tensordict

    def transform_input_spec(self, input_spec):
        action_spec = input_spec["full_action_spec"]
        ref = action_spec["agents", self.agents[0], "continuous_action"]
        shape = (*ref.shape[:-1], len(self.agents))
        low, high = ref.space.low, ref.space.high
        del action_spec["agents"]
        action_spec["action", "throttle"] = Bounded(
            low=float(low[..., 0].min()), high=float(high[..., 0].max()), shape=shape, dtype=ref.dtype)
        action_spec["action", "steering"] = Bounded(
            low=float(low[..., 1].min()), high=float(high[..., 1].max()), shape=shape, dtype=ref.dtype)
        return input_spec
