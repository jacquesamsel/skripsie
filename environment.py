from functools import reduce
from typing import Sequence

from torchrl.envs.transforms import Transform, Stack, UnaryTransform, ExcludeTransform, RenameTransform, UnsqueezeTransform
from torchrl.envs import CatFrames, TransformedEnv, UnityMLAgentsEnv, MarlGroupMapType, ParallelEnv, Compose
from torchrl.data import Unbounded, UnboundedContinuous
import torch
from mlagents_envs.side_channel.engine_configuration_channel import EngineConfigurationChannel
import tensordict as td


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


def make_envs(num_envs: int, num_agents_per_env: int, num_stacked_frames: int = 4):
    agents = [f"agent_{i}" for i in range(num_agents_per_env)]
    env = ParallelEnv(
        num_envs, make_env,
        create_env_kwargs=[
            {"worker_id": k, "num_agents": num_agents_per_env} for k in range(num_envs)],
    )

    LIDAR_NUM_TAGS = 2
    LIDAR_BLOCK = LIDAR_NUM_TAGS + 2  # [Tag_1..Tag_n, Miss, Distance]

    return TransformedEnv(
        env,
        Compose(
            *[
                Stack(in_keys=[
                    ("agents", agent, key) for agent in agents
                ], out_key=("agents", key), dim=-2)
                for key in [
                    "LIDAR1",
                    "VectorSensor_size37",
                    "done",
                    "terminated",
                    "truncated"
                ]
            ],
            RenameTransform(in_keys=[("agents", "VectorSensor_size37")], out_keys=[
                            ("agents", "vector")]),
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
                *[("agents", agent, "reward") for agent in agents],
                *[("agents", agent,  "group_reward") for agent in agents],
                *[(agents, agent)]
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
                    (("agents", "wheel_slips"), torch.Size([8])),
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
            # Add an extra dim to the lidar tensor so that it can be stacked with CatFrames
            UnsqueezeTransform(
                dim=-2,
                in_keys=[("agents", "lidar")],
                out_keys=[("agents", "lidar")]
            ),
            CatFrames(N=num_stacked_frames,
                      dim=-2,
                      in_keys=[("agents", "lidar")],
                      out_keys=[("agents", "stacked_lidar")],
                      done_key=("agents", "done")
                      ),
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
                ("agents", "terminated"),
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
        terminated = tensordict["agents", "terminated"].squeeze(-1).float()
        progress_reward = progress_delta * \
            self.progress_weight * (1.0 - terminated)
        forward_velocity_reward = forward_velocity * self.forward_velocity_weight
        step_penalty = torch.full((), -self.step_penalty)
        collision_penalty = -self.collision_penalty * terminated
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
