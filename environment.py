from functools import reduce

from torchrl.envs.transforms import Transform, Stack, UnaryTransform, ExcludeTransform, RenameTransform, UnsqueezeTransform
from torchrl.envs import CatFrames, TransformedEnv, UnityMLAgentsEnv, MarlGroupMapType, ParallelEnv, Compose
from torchrl.data import Bounded, Composite, Unbounded, UnboundedContinuous
import torch
from mlagents_envs.side_channel.engine_configuration_channel import EngineConfigurationChannel
import tensordict as td


# One curvature observation, and so one auxiliary curvature head in model.py,
# per distance in this list.
CURVATURE_LOOKAHEAD_DISTANCES = [0.5 * i for i in range(1, 17)]


def track_curvature_key(metres: float) -> td.NestedKey:
    """Observation key for the centerline curvature `metres` ahead of the car."""
    return ("agents", f"track_curvature_{metres:.2f}".replace(".", "_"))


# The terms ComposeReward adds up, and the key each one is published under. They sum to
# ("agents", "reward") exactly, so a reward curve can be read back as the contributions
# that made it (see rollout_stats in stats.py, which reports the mean of each).
#
# Published by the env rather than re-derived downstream: the weights live in
# ComposeReward, so anything computing "how much of this came from progress" from the
# raw observations would be a second copy of the formula, free to drift from the reward
# the agent was actually trained on.
REWARD_TERM_KEYS: dict[str, td.NestedKey] = {
    "progress": ("agents", "reward_progress"),
    "velocity_forward": ("agents", "reward_velocity_forward"),
    "step_penalty": ("agents", "reward_step_penalty"),
    "collision": ("agents", "reward_collision"),
}


class RoboRacerEnv(TransformedEnv):
    """RoboRacer environment wrapper.

    Args:
        file_name (str): Path to the Unity executable.
        num_stacked_frames (int): Number of frames to stack for the observations.
        no_graphics (bool, optional): Whether to run the environment in no-graphics mode. Defaults to True.
        num_areas (int, optional): Number of areas in the environment. Defaults to 10.
        seed (int, optional): Random seed for the environment. Defaults to 0.
        progress_weight (float, optional): Reward per metre of centerline progress. Defaults to 1.0.
        forward_velocity_weight (float, optional): Reward per m/s of forward velocity. Defaults to 0.0.
        step_penalty (float, optional): Fixed cost charged every step. Defaults to 0.0.
        collision_penalty (float, optional): Cost charged on the step a car crashes. Defaults to 1.0.
    """

    LIDAR_NUM_TAGS = 2
    LIDAR_BLOCK_SIZE = LIDAR_NUM_TAGS + 2
    VECTOR_SENSOR_SIZE = 32

    def __init__(
        self,
        file_name: str | None,
        num_stacked_frames: int,
        no_graphics=True,
        time_scale=100.0,
        num_areas=10,
        seed=0,
        progress_weight=1.0,
        forward_velocity_weight=0.0,
        step_penalty=0.0,
        collision_penalty=1.0,
        worker_id=0
    ):

        engine_configuration_channel = EngineConfigurationChannel()
        engine_configuration_channel.set_configuration_parameters(
            time_scale=time_scale
        )
        agent_names = [f"agent_{i}" for i in range(num_areas)]
        base_env = UnityMLAgentsEnv(
            file_name=file_name,
            side_channels=[
                engine_configuration_channel
            ],
            no_graphics=no_graphics,
            worker_id=worker_id,
            num_areas=num_areas,
            seed=seed,
            group_map=MarlGroupMapType.ALL_IN_ONE_GROUP
        )

        super().__init__(
            base_env,
            Compose(
                *[Stack(
                    in_keys=[
                        ("agents", agent_name, key)
                        for agent_name in agent_names],
                    out_key=("agents", key), dim=-2, del_keys=True
                ) for key in ["lidar", f"VectorSensor_size{self.VECTOR_SENSOR_SIZE}", "done", "terminated", "truncated"]],
                # Never read. Has to be dropped *before* the reward is stacked, not
                # after: Stack(del_keys=True) prunes a per-agent subdict once it takes
                # the last key out of it, but ExcludeTransform leaves the empty subdict
                # behind -- and ParallelEnv rejects a sub-env whose specs contain one.
                ExcludeTransform(
                    *[("agents", agent_name, "group_reward")
                      for agent_name in agent_names]
                ),
                # Unity's own reward is only used as the crash signal (see ComposeReward)
                StackIfPresent(
                    in_keys=[("agents", agent_name, "reward")
                             for agent_name in agent_names],
                    out_key=("agents", "unity_reward"), dim=-2, del_keys=True
                ),
                RenameTransform(
                    in_keys=[
                        ("agents", f"VectorSensor_size{self.VECTOR_SENSOR_SIZE}")],
                    out_keys=[("agents", "vector")]
                ),
                # Reshape the lidar tensor from (num_areas, ray*block) to (num_areas, ray, block)
                UnaryTransform(
                    fn=lambda lidar: torch.unflatten(
                        lidar, -1, (101, self.LIDAR_BLOCK_SIZE)),
                    in_keys=[("agents", "lidar")],
                    out_keys=[("agents", "lidar")],
                ),
                # Mask the misses -> 0 length in LIDAR. This also removes the other
                # lidar "channels", leaving one distance value per ray.
                UnaryTransform(
                    fn=lambda lidar: lidar[..., -1] * (lidar[..., -2] == 0.0).to(torch.float32),
                    in_keys=[("agents", "lidar")],
                    out_keys=[("agents", "lidar")],
                ),
                # Add an extra dim to the lidar tensor so that it can be stacked with CatFrames
                UnsqueezeTransform(
                    dim=-2,
                    in_keys=[("agents", "lidar")],
                    out_keys=[("agents", "lidar")]
                ),
                CatFramesResetOnDone(
                    N=num_stacked_frames,
                    dim=-2,
                    in_keys=[("agents", "lidar")],
                    out_keys=[("agents", "stacked_lidar")],
                    done_key=("agents", "done"),
                    reset_key=("agents", "done")
                ),
                SplitVector(
                    layout=[
                        (("agents", "steering_angle"), torch.Size([1])),
                        (("agents", "throttle"), torch.Size([1])),
                        (("agents", "velocity_forward"), torch.Size([1])),
                        (("agents", "velocity_lateral"), torch.Size([1])),
                        (("agents", "linear_acceleration_forward"),
                         torch.Size([1])),
                        (("agents", "linear_acceleration_lateral"),
                         torch.Size([1])),
                        (("agents", "angular_velocity_y"), torch.Size([1])),
                        *[(track_curvature_key(metres), torch.Size([1]))
                          for metres in CURVATURE_LOOKAHEAD_DISTANCES],
                        *[
                            (("agents", f"wheel_slip_{direction}_{wheel}"), torch.Size(
                                [1]))
                            for wheel in ["front_left", "front_right", "back_left", "back_right"]
                            for direction in ["forward", "lateral"]
                        ],
                        # Centerline metres covered since the last decision, drained per
                        # decision step by Car.cs. Must stay last here: SplitVector is
                        # positional, so this order has to match Car.CollectObservations'
                        # AddObservation order, where it is the final entry.
                        (("agents", "progress"), torch.Size([1])),
                    ],
                    in_key=("agents", "vector"),
                    delete_vector=True
                ),
                # Needs progress and velocity_forward, so it has to follow SplitVector
                ComposeReward(
                    progress_weight=progress_weight,
                    forward_velocity_weight=forward_velocity_weight,
                    step_penalty=step_penalty,
                    collision_penalty=collision_penalty
                ),
                ExcludeTransform(("agents", "unity_reward")),
                StackAction(
                    in_keys=[("agents", a, "continuous_action")
                             for a in agent_names],
                    out_key=("agents", "continuous_action"),
                    in_key_inv=("agents", "continuous_action"),
                    out_keys_inv=[("agents", a, "continuous_action")
                                  for a in agent_names],
                    dim=-2),
                SplitAction(("agents", "continuous_action"),
                            [("action", "throttle"), ("action", "steering")]),
                # Last: every ("agents", ...) leaf has to exist, and carry the
                # area dim, before that dim can be declared as the batch dim.
                AreasAsBatch(num_areas),
            )
        )


class AreasAsBatch(Transform):
    """Declares Unity's per-area dimension as the env's batch dimension.

    The Stacks above already leave every ("agents", ...) leaf with the area dim
    leading -- (num_areas, 1) for the scalars, (num_areas, frames, block, rays)
    for the lidar -- but the env goes on reporting batch_size=(), so that dim
    reads as part of the data: a rollout of a 2-env/4-area setup stacks to
    [T, 2] rather than [T, 2, 4], and train.py's reshape(-1) counts one sample
    per *env* step instead of one per *car* step, so a minibatch is silently
    num_areas times bigger than it claims and shuffling never separates the
    cars sharing an engine.

    Declaring it touches no tensor -- the data already has the right shape, only
    the specs and the reported batch_size change -- which is why this can sit at
    the end of the Compose without disturbing any transform before it.

    The areas are independent tracks sharing one Unity process, not interacting
    agents, so a batch dim (rather than the MARL convention of an agent dim
    inside the "agents" group) is the honest description. The keys stay under
    "agents" regardless, so train.py's set_keys(reward=("agents", "reward"))
    is unaffected.
    """

    def __init__(self, num_areas: int):
        super().__init__()
        self.num_areas = num_areas

    def transform_env_batch_size(self, batch_size: torch.Size) -> torch.Size:
        return torch.Size([*batch_size, self.num_areas])

    def _call(self, next_tensordict: td.TensorDictBase) -> td.TensorDictBase:
        # the leaves are already (num_areas, ...); this only moves the boundary
        # between batch dims and feature dims, hence batch_dims=1 rather than
        # letting auto_batch_size_ swallow the feature dims too
        return next_tensordict.auto_batch_size_(1)

    forward = _call

    def _reset(self, tensordict, tensordict_reset):
        return self._call(tensordict_reset)

    def _inv_call(self, tensordict: td.TensorDictBase) -> td.TensorDictBase:
        # Going the other way, StackAction unstacks the action back into one
        # (2,) entry per agent, which no longer carries the area dim -- so the
        # batch dim has to come off before the transforms below run, or those
        # writes are rejected as too small for the batch. Transform.inv hands
        # this a shallow clone whose sub-tensordicts are fresh objects, so
        # resetting the batch size in place doesn't touch the caller's copy.
        return tensordict.auto_batch_size_(0)

    def transform_output_spec(self, output_spec):
        return self._batched_spec(output_spec)

    def transform_input_spec(self, input_spec):
        return self._batched_spec(input_spec)

    def _batched_spec(self, spec):
        """Re-declares every Composite with the area dim in its shape.

        Leaf specs are returned as they are: their shape already starts with
        num_areas, which is exactly what Composite validates against.
        """
        if not isinstance(spec, Composite):
            return spec
        return Composite(
            {key: self._batched_spec(spec[key]) for key in spec.keys()},
            shape=torch.Size([*spec.shape, self.num_areas]),
            device=spec.device,
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
    """Shaped per-agent reward. A car has crashed when Unity's own reward for it is negative.

    Writes each term out under its own key as well (see REWARD_TERM_KEYS), as plain
    observations rather than rewards -- torchrl treats every entry of the reward spec as
    a reward to optimise, and these are only there to be read.
    """

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
            out_keys=[("agents", "reward"), *REWARD_TERM_KEYS.values()],
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
        # Progress is dropped on the crash step: the distance covered while sliding
        # into a wall shouldn't be paid for.
        progress_reward = progress_delta * \
            self.progress_weight * (1.0 - crashed)
        forward_velocity_reward = forward_velocity * self.forward_velocity_weight
        step_penalty = torch.full_like(progress_reward, -self.step_penalty)
        collision_penalty = -self.collision_penalty * crashed
        terms = {
            "progress": progress_reward,
            "velocity_forward": forward_velocity_reward,
            "step_penalty": step_penalty,
            "collision": collision_penalty,
        }
        shaped = sum(terms.values())
        tensordict["agents", "reward"] = shaped.unsqueeze(-1)
        for name, term in terms.items():
            tensordict[REWARD_TERM_KEYS[name]] = term.unsqueeze(-1)
        return tensordict

    def _reset(self, tensordict: td.TensorDict, tensordict_reset: td.TensorDict) -> td.TensorDict:
        # The terms are declared as observations, so the reset output has to carry them
        # too or it no longer matches the spec. Zero is the honest value: there was no
        # step to pay for. _call can't be reused here -- the reset output has no
        # unity_reward (see StackIfPresent), so there is no crash signal to read.
        for key in REWARD_TERM_KEYS.values():
            tensordict_reset[key] = torch.zeros_like(
                tensordict_reset["agents", "velocity_forward"])
        return tensordict_reset

    def transform_output_spec(self, output_spec):
        output_spec = output_spec.clone()
        obs = output_spec["full_observation_spec",
                          "agents", "velocity_forward"]
        output_spec["full_reward_spec", "agents", "reward"] = Unbounded(
            shape=(*obs.shape[:-1], 1), dtype=torch.float32, device=obs.device)
        for key in REWARD_TERM_KEYS.values():
            output_spec[("full_observation_spec", *key)] = Unbounded(
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


class SplitAction(Transform):
    """Exposes one (..., n) action entry as n separate (..., 1) entries."""

    def __init__(self, in_key, out_keys):
        super().__init__(in_keys=[], out_keys=[])
        self.in_key = in_key
        self.split_keys = out_keys

    def transform_input_spec(self, input_spec):
        action_spec = input_spec["full_action_spec"]
        spec = action_spec[self.in_key]
        for i, key in enumerate(self.split_keys):
            action_spec[key] = spec[..., i:i + 1]
        del action_spec[self.in_key]
        # Deleting the only leaf leaves an empty group behind, which ParallelEnv
        # rejects when it validates the sub-env specs.
        parent_key = self.in_key[:-1]
        while parent_key and action_spec[parent_key].is_empty():
            del action_spec[parent_key]
            parent_key = parent_key[:-1]
        return input_spec

    def _inv_call(self, tensordict):
        return tensordict.set(self.in_key, torch.cat(
            [tensordict.get(k) for k in self.split_keys], dim=-1))


class StackAction(Stack):
    """Stack whose forward side is inert: action keys never appear in observations."""

    def _call(self, next_tensordict):
        keys = next_tensordict.keys(include_nested=True)
        if not any(k in keys for k in self.in_keys):
            return next_tensordict
        return super()._call(next_tensordict)

    forward = _call

    def _reset(self, tensordict, tensordict_reset):
        return tensordict_reset

    def transform_output_spec(self, output_spec):
        return output_spec


class CatFramesResetOnDone(CatFrames):
    """CatFrames for envs that reset in-engine: flushes the stack per agent on done."""

    _pending = None

    def _reset(self, tensordict, tensordict_reset):
        self._pending = None
        return super()._reset(tensordict, tensordict_reset)

    def _step(self, tensordict, next_tensordict):
        pending, self._pending = self._pending, None
        next_tensordict = self._call(next_tensordict)
        if pending is not None:
            next_tensordict = self._call(next_tensordict, _reset=pending)
        done = next_tensordict.get(self.done_key)
        if done.any():
            self._pending = done.squeeze(-1).clone()
        return next_tensordict


class RoboRacerParallelEnvs(ParallelEnv):
    """Parallel wrapper for multiple RoboRacer environments.

    Args:
        num_envs (int): Number of parallel environments.
        file_name (str): Path to the Unity executable.
        num_stacked_frames (int): Number of frames to stack for the observations.
        no_graphics (bool, optional): Whether to run the environment in no-graphics mode. Defaults to True.
        time_scale (float, optional): Time scale for the Unity environment. Defaults to 100.0.
        num_areas (int, optional): Number of areas in each environment. Defaults to 10.
        seed (int, optional): Random seed for the environments. Defaults to 0.
        progress_weight (float, optional): Reward per metre of centerline progress. Defaults to 1.0.
        forward_velocity_weight (float, optional): Reward per m/s of forward velocity. Defaults to 0.0.
        step_penalty (float, optional): Fixed cost charged every step. Defaults to 0.0.
        collision_penalty (float, optional): Cost charged on the step a car crashes. Defaults to 1.0.
    """

    def __init__(
        self,
        num_envs: int,
        file_name: str,
        num_stacked_frames: int,
        no_graphics=True,
        time_scale=100.0,
        num_areas=10,
        seed=0,
        progress_weight=1.0,
        forward_velocity_weight=0.0,
        step_penalty=0.0,
        collision_penalty=1.0,
        start_worker_id=0
    ):
        super().__init__(
            num_envs,
            RoboRacerEnv,
            create_env_kwargs=[{
                "file_name": file_name,
                "num_stacked_frames": num_stacked_frames,
                "no_graphics": no_graphics,
                "time_scale": time_scale,
                "num_areas": num_areas,
                "seed": seed + worker_id,
                "progress_weight": progress_weight,
                "forward_velocity_weight": forward_velocity_weight,
                "step_penalty": step_penalty,
                "collision_penalty": collision_penalty,
                "worker_id": worker_id
            } for worker_id in range(start_worker_id, start_worker_id + num_envs)],
        )
