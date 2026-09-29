from typing import Literal

import torch
from tensordict.nn import TensorDictModule, TensorDictSequential
from torchrl.modules import ActorValueOperator, ProbabilisticActor, SafeProbabilisticTensorDictSequential, TanhNormal, ValueOperator
import tensordict as td
from torchrl.modules.tensordict_module.sequence import SafeSequential


class TrunkModel(torch.nn.Module):
    def __init__(
        self,
        num_stacked_lidar_frames: int,
        n_rays: int,
        lidar_conv: Literal["conv1d", "conv2d"],
        ray_kernel: int,
        ray_stride: int,
        time_subsample: int = 1,

        time_stride: int | None = None,
        time_kernel: int | None = None,
    ):
        super().__init__()
        if lidar_conv == "conv2d" and (time_kernel is None or time_stride is None):
            raise ValueError(
                f"time_kernel and time_stride must be specified for conv2d lidar_conv. Got time_kernel={time_kernel}, time_stride={time_stride}")

        self.sampled_time_dim_size = (
            num_stacked_lidar_frames - 1) // time_subsample + 1
        self.num_stacked_lidar_frames = num_stacked_lidar_frames
        self.time_subsample = time_subsample
        self.n_rays = n_rays
        self.lidar_conv = lidar_conv

        self.lidar_network = torch.nn.Sequential(
            torch.nn.Conv1d(
                in_channels=(num_stacked_lidar_frames-1)//time_subsample + 1,
                out_channels=16,
                kernel_size=ray_kernel,
                stride=ray_stride
            ),
            torch.nn.ReLU(),
            torch.nn.Conv1d(in_channels=16, out_channels=32, kernel_size=8),
            torch.nn.ReLU(),
            torch.nn.Conv1d(in_channels=32, out_channels=32, kernel_size=8),
            torch.nn.ReLU(),
            torch.nn.Conv1d(in_channels=32, out_channels=16, kernel_size=8),
            torch.nn.ReLU(),
        ) if lidar_conv == "conv1d" else torch.nn.Sequential(
            torch.nn.Conv2d(
                in_channels=1,
                out_channels=16,
                kernel_size=(time_kernel, ray_kernel),
                stride=(time_stride, ray_stride)
            ),
            torch.nn.ReLU(),
            torch.nn.Conv2d(in_channels=16, out_channels=32,
                            kernel_size=(1, 8)),
            torch.nn.ReLU(),
            torch.nn.Conv2d(in_channels=32, out_channels=32,
                            kernel_size=(1, 8)),
            torch.nn.ReLU(),
            torch.nn.Conv2d(in_channels=32, out_channels=16,
                            kernel_size=(1, 8)),
            torch.nn.ReLU(),
        )

        with torch.no_grad():
            dummy = torch.zeros(1, self.sampled_time_dim_size, n_rays) if lidar_conv == "conv1d" else torch.zeros(
                1, 1, self.sampled_time_dim_size, n_rays)
            dense_in = self.lidar_network(dummy).numel() + 2

        self.dense = torch.nn.Sequential(
            torch.nn.Linear(dense_in, 128),
            torch.nn.ReLU(),
            torch.nn.Linear(128, 256),
            torch.nn.ReLU(),
            torch.nn.Linear(256, 128),
            torch.nn.ReLU(),
            torch.nn.Linear(128, 64),
            torch.nn.ReLU()
        )

    def forward(self, lidar: torch.Tensor, cur_steering_angle: torch.Tensor, cur_throttle: torch.Tensor):
        # lidar is (..., n_stacked_frames, L) of distances (see StackLidar)
        *batch_shape, n_frames, n_tags, n_rays = lidar.shape
        if n_frames != self.num_stacked_lidar_frames:
            raise ValueError(
                f"Expected {self.num_stacked_lidar_frames} stacked lidar frames, got {n_frames}")

        if n_rays != self.n_rays:
            raise ValueError(
                f"Expected {self.n_rays} lidar rays, got {n_rays}")

        n_tags -= 2  # remove the miss, dist 'tags'

        # (..., n_stacked_frames, L) of distances only. Have to flip the lidar tensor on time so that the most recent frame is always included
        lidar_distance_only = lidar.flip(-3)[...,
                                             ::self.time_subsample,  -1, :]

        # flatten all leading batch dims (agents, time, envs, ...) into one
        # dim so Conv1d always sees (N, n_frames, L), then restore the batch shape
        lidar_cnn_output: torch.Tensor = self.lidar_network(
            lidar_distance_only.reshape(-1,
                                        self.sampled_time_dim_size, n_rays) if self.lidar_conv == "conv1d" else
            lidar_distance_only.reshape(-1, 1,
                                        self.sampled_time_dim_size, n_rays)
        )
        lidar_cnn_output = lidar_cnn_output.reshape(
            *batch_shape, *lidar_cnn_output.shape[1:])
        lidar_cnn_output_flat = lidar_cnn_output.flatten(
            len(batch_shape)).reshape(*batch_shape, -1)

        # only prev steering, throttle in input
        dense_input = torch.cat(
            [lidar_cnn_output_flat, cur_steering_angle, cur_throttle], dim=-1)
        dense_output: torch.Tensor = self.dense(dense_input)

        return dense_output, lidar_cnn_output


class ActionModel(torch.nn.Module):
    def __init__(self):
        super().__init__()
        # 2 for throttle (loc, scale), 2 for steering (loc, scale)
        self.head = torch.nn.Linear(64, 4)

    def forward(self, hidden_layer: torch.Tensor):

        out = self.head(hidden_layer)

        throttle_loc, throttle_scale, steering_loc, steering_scale = out.unbind(
            -1)

        throttle_scale = (torch.nn.functional.softplus(
            throttle_scale) + 1e-3) / 2.0
        steering_scale = (torch.nn.functional.softplus(
            steering_scale - 1.0) + 1e-3) / 2.0

        return throttle_loc, throttle_scale, steering_loc, steering_scale


class AuxModel(torch.nn.Module):
    def __init__(self):
        super().__init__()
        self.head = torch.nn.Linear(64, 16)

    def forward(self, hidden_layer: torch.Tensor, lidar_cnn_output: torch.Tensor):
        out: torch.Tensor = self.head(hidden_layer)
        velocity_forward = out[..., :1]  # (..., 1) = [forward_velocity]
        velocity_lateral = out[..., 1:2]  # (..., 1) = [lateral_velocity]
        # (..., 2) = [forward_pos_delta, lateral_pos_delta]
        pos_delta = out[..., 2:4]
        # (..., 1) = [yaw_rate] (angular velocity about Unity's y-axis)
        yaw_rate = out[..., 4:5]
        # (..., 4, 2) = [wheel_slip_lf_forward, wheel_slip_lf_sideways, ...] lf, rf, lr, rr
        wheel_slips = out[..., 5:13].unflatten(-1, (4, 2))
        # (..., 3) = [curvature_0.5_m, curvature_1.0_m, curvature_2.0_m]
        curvature = out[..., 13:16]

        return velocity_forward, velocity_lateral, pos_delta, yaw_rate, wheel_slips, curvature


class ValueModel(torch.nn.Module):
    def __init__(self):
        super().__init__()
        self.head = torch.nn.Linear(64, 1)

    def forward(self, hidden_layer: torch.Tensor):
        return self.head(hidden_layer)


class ActorValueAuxOperator(SafeSequential):

    def __init__(
        self,
        common_operator: TensorDictModule,
        policy_operator: TensorDictModule,
        value_operator: TensorDictModule,
        aux_operator: TensorDictModule
    ):
        super().__init__(
            common_operator,
            policy_operator,
            value_operator,
            aux_operator
        )

    def get_trunk_operator(self) -> TensorDictModule:
        """Returns the shared trunk alone, mapping an observation to (hidden_layer, lidar_cnn_output)."""
        return self.module[0]

    def get_policy_operator(self) -> TensorDictSequential:
        """Returns a standalone policy operator that maps an observation to an action."""
        if isinstance(self.module[1], SafeProbabilisticTensorDictSequential):
            return SafeProbabilisticTensorDictSequential(
                self.module[0], *self.module[1].module
            )
        return SafeSequential(self.module[0], self.module[1])

    def get_value_operator(self) -> TensorDictSequential:
        """Returns a standalone value network operator that maps an observation to a value estimate."""
        return SafeSequential(self.module[0], self.module[2])

    def get_aux_operator(self) -> TensorDictSequential:
        """Returns a standalone aux network operator that maps an observation to aux outputs."""
        return SafeSequential(self.module[0], self.module[3])

    def get_policy_head(self) -> TensorDictModule:
        """Returns the policy head."""
        return self.module[1]

    def get_value_head(self) -> TensorDictModule:
        """Returns the value head."""
        return self.module[2]

    def get_aux_head(self) -> TensorDictModule:
        """Returns the aux head."""
        return self.module[3]


def make_model(
    num_stacked_lidar_frames: int,
    n_rays: int,
    lidar_conv: Literal["conv1d", "conv2d"],
    ray_kernel: int,
    ray_stride: int,
    time_subsample: int = 1,
    time_stride: int | None = None,
    time_kernel: int | None = None,
) -> ActorValueAuxOperator:

    trunk_tensordict_model = TensorDictModule(
        TrunkModel(
            num_stacked_lidar_frames=num_stacked_lidar_frames,
            n_rays=n_rays,
            lidar_conv=lidar_conv,
            ray_kernel=ray_kernel,
            ray_stride=ray_stride,
            time_subsample=time_subsample,
            time_stride=time_stride,
            time_kernel=time_kernel,
        ),
        in_keys=[("agents", "stacked_lidar"), ("agents", "cur_steering_angle"),
                 ("agents", "cur_throttle")],
        out_keys=["hidden_layer", "lidar_cnn_output"]
    )

    aux = TensorDictModule(
        AuxModel(),
        in_keys=["hidden_layer", "lidar_cnn_output"],
        out_keys=[("aux", "velocity_forward"), ("aux", "velocity_lateral"), ("aux",
                                                                             "pos_delta"), ("aux", "yaw_rate"), ("aux", "wheel_slips"), ("aux", "curvature")]
    )

    actor_tensordict_model = TensorDictModule(
        ActionModel(),
        in_keys=["hidden_layer"],
        out_keys=[
            ("params", "throttle", "loc"),
            ("params", "throttle", "scale"),
            ("params", "steering", "loc"),
            ("params", "steering", "scale"),
        ]
    )

    actor = ProbabilisticActor(
        actor_tensordict_model,
        in_keys=["params"],
        distribution_class=td.nn.CompositeDistribution,
        return_log_prob=True,
        distribution_kwargs={
            "distribution_map": {
                "throttle": lambda loc, scale: TanhNormal(loc, scale, event_dims=0, tanh_loc=True),
                "steering": lambda loc, scale: TanhNormal(loc, scale, event_dims=0, tanh_loc=True),
            },
            "name_map": {
                "throttle": ("action", "throttle"),
                "steering": ("action", "steering")
            }
        }
    )

    critic = ValueOperator(
        ValueModel(),
        in_keys=["hidden_layer"],
        out_keys=["state_value"]
    )

    return ActorValueAuxOperator(
        trunk_tensordict_model,
        actor,
        critic,
        aux,
    )
