from functools import reduce

from torchrl.envs.transforms import Transform, Stack, UnaryTransform, ExcludeTransform, RenameTransform, UnsqueezeTransform
from torchrl.envs import CatFrames, TransformedEnv, UnityMLAgentsEnv, MarlGroupMapType, ParallelEnv, Compose
from torchrl.data import Bounded, Unbounded, UnboundedContinuous
import torch
from mlagents_envs.side_channel.engine_configuration_channel import EngineConfigurationChannel
import tensordict as td
from tensordict import is_tensor_collection
import platform
import random


class RoboRacerEnv(TransformedEnv):
    """RoboRacer environment wrapper.

    Args:
        file_name (str): Path to the Unity executable.
        num_stacked_frames (int): Number of frames to stack for the observations.
        no_graphics (bool, optional): Whether to run the environment in no-graphics mode. Defaults to True.
        num_areas (int, optional): Number of areas in the environment. Defaults to 10.
        seed (int, optional): Random seed for the environment. Defaults to 0.
    """

    LIDAR_NUM_TAGS = 2
    LIDAR_BLOCK_SIZE = LIDAR_NUM_TAGS + 2

    def __init__(
        self,
        file_name: str,
        num_stacked_frames: int,
        no_graphics=True,
        time_scale=100.0,
        num_areas=10,
        seed=0,
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
                ) for key in ["lidar", "VectorSensor_size23", "done", "terminated", "truncated"]],

                UnaryTransform(
                    fn=lambda lidar: torch.unflatten(
                        lidar, -1, (101, self.LIDAR_BLOCK_SIZE))
                    .transpose(-1, -2),  # [1, 500, LIDAR_BLOCK_SIZE, 101]
                    in_keys=[("agents", "lidar")],
                    out_keys=[("agents", "lidar")],
                ),
                # Add an extra dim to the lidar tensor so that it can be stacked with CatFrames
                UnsqueezeTransform(
                    dim=-3,
                    in_keys=[("agents", "lidar")],
                    out_keys=[("agents", "lidar")]
                ),
                CatFramesResetOnDone(
                    N=num_stacked_frames,
                    dim=-3,
                    in_keys=[("agents", "lidar")],
                    out_keys=[("agents", "stacked_lidar")],
                    done_key=("agents", "done"),
                    reset_key=("agents", "done")
                ),
                StackAction(
                    in_keys=[("agents", a, "continuous_action")
                             for a in agent_names],
                    out_key=("agents", "continuous_action"),
                    in_key_inv=("agents", "continuous_action"),
                    out_keys_inv=[("agents", a, "continuous_action")
                                  for a in agent_names],
                    dim=-2),
                SplitAction(("agents", "continuous_action"),
                            [("actions", "throttle"), ("actions", "steering")]),
            )
        )


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


class RoboRacerEnvs(ParallelEnv):
    """Parallel wrapper for multiple RoboRacer environments.

    Args:
        num_envs (int): Number of parallel environments.
        file_name (str): Path to the Unity executable.
        num_stacked_frames (int): Number of frames to stack for the observations.
        no_graphics (bool, optional): Whether to run the environment in no-graphics mode. Defaults to True.
        time_scale (float, optional): Time scale for the Unity environment. Defaults to 100.0.
        num_areas (int, optional): Number of areas in each environment. Defaults to 10.
        seed (int, optional): Random seed for the environments. Defaults to 0.
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
    ):
        super().__init__(
            num_envs=num_envs,
            create_env_fn=lambda rank: RoboRacerEnv(
                file_name=file_name,
                num_stacked_frames=num_stacked_frames,
                no_graphics=no_graphics,
                time_scale=time_scale,
                num_areas=num_areas,
                seed=seed + rank
            )
        )
