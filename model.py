import math
from typing import Any

import torch
from tensordict.nn import TensorDictModule, TensorDictSequential
from torchrl.modules import ActorValueOperator, ProbabilisticActor, SafeProbabilisticTensorDictSequential, TanhNormal, ValueOperator
import tensordict as td
from torchrl.modules.tensordict_module.sequence import SafeSequential
from utils import AUX_HEAD_KEYS
import os


# class FollowTheGap:
#     def __init__(self, n_rays: int, lidar_range: float, lidar_fov: float, car_width: float, safety_margin: float):
#         self.n_rays = n_rays
#         self.lidar_range = lidar_range  # meters per unit
#         self.lidar_fov = lidar_fov * (math.pi / 180)  # radians
#         self.car_width = car_width  # meters
#         self.safety_margin = safety_margin

#     def __call__(self, lidar: torch.Tensor, steering_angle: torch.Tensor, cur_throttle: torch.Tensor):
#         *batch_shape, n_frames, n_rays = lidar.shape
#         if n_rays != self.n_rays:
#             raise ValueError(
#                 f"Expected {self.n_rays} lidar rays, got {n_rays}")

#         # get rid of the n_frames
#         lidar = lidar[..., -1, :]  # (*batch_shape, n_rays)

#         # ray angles in radians from -lidar_fov/2 to +lidar_fov/2, with 0 being straight ahead
#         angles = torch.linspace(-self.lidar_fov/2, self.lidar_fov/2, n_rays)
#         ang_res = angles[1] - angles[0]
#         idxs = torch.arange(n_rays)

#         # closest obstacle (*batch_shape, 1)
#         dist_min, idx_min = lidar.min(dim=-1, keepdim=True)
#         safety_bubble_radius = self.car_width/2 + self.safety_margin

#         # angular half-width of the safety bubble, in radians
#         half_angle = torch.atan2(safety_bubble_radius,
#                                  dist_min)  # (*batch_shape, 1)

#         safety_bubble_idx_radius = half_angle / ang_res

#         # zero-out lidar values in that angular slice
#         in_bubble = (idxs - idx_min).abs() <= safety_bubble_idx_radius
#         lidar = lidar.masked_fill(
#             in_bubble,
#             torch.Tensor(0)
#         )


#         # find largest continuous free gap


class RecurrentTrunkModel(torch.nn.Module):
    def __init__(self,
                 num_stacked_lidar_frames: int,
                 n_rays: int,
                 hidden_size: int = 64,
                 ):
        super().__init__()
        self.encoder = TrunkModel(encoder_kwargs)
        self.cell = torch.nn.GRUCell(64, hidden_size)
        self.norm = torch.nn.LayerNorm(hidden_size)

    def forward(self, lidar, steering_angle, cur_throttle, h, is_init) -> torch.Tensor:
        """lidar etc: (..., L, ...) with time as the last batch dim.
        h: (..., hidden) state *before* the first step. is_init: (..., L, 1) bool."""

        x, cnn = self.encoder(lidar, steering_angle, cur_throttle)
        outs = []


class TrunkModel(torch.nn.Module):
    def __init__(
        self,
        num_stacked_lidar_frames: int,
        n_rays: int,
        ray_kernel: int,
        ray_stride: int,
        time_subsample: int = 1,
    ):
        super().__init__()

        self.sampled_time_dim_size = (
            num_stacked_lidar_frames - 1) // time_subsample + 1
        self.num_stacked_lidar_frames = num_stacked_lidar_frames
        self.time_subsample = time_subsample
        self.n_rays = n_rays

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
        )

        with torch.no_grad():
            dummy = torch.zeros(1, self.sampled_time_dim_size, n_rays)
            dense_in = self.lidar_network(dummy).numel() + 2

        self.dense = torch.nn.Sequential(
            torch.nn.Linear(dense_in, 128),
            torch.nn.ReLU(),
            torch.nn.Linear(128, 72),
            torch.nn.ReLU(),
            torch.nn.Linear(72, 64),
            torch.nn.ReLU(),
            torch.nn.LayerNorm(64)
        )

    def forward(self, lidar: torch.Tensor, steering_angle: torch.Tensor, cur_throttle: torch.Tensor):
        # lidar is (..., n_stacked_frames, n_rays) of distances: RoboRacerEnv
        # takes the distance channel out of each ray block before stacking, so
        # there is no tag/miss channel left here to select.
        *batch_shape, n_frames, n_rays = lidar.shape
        if n_frames != self.num_stacked_lidar_frames:
            raise ValueError(
                f"Expected {self.num_stacked_lidar_frames} stacked lidar frames, got {n_frames}")

        if n_rays != self.n_rays:
            raise ValueError(
                f"Expected {self.n_rays} lidar rays, got {n_rays}")

        # Flip time before striding by time_subsample, so that the stride lands
        # on the most recent frame rather than the oldest one.
        lidar_distance_only = lidar.flip(-2)[..., ::self.time_subsample, :]

        # flatten all leading batch dims (agents, time, envs, ...) into one
        # dim so Conv1d always sees (N, n_frames, L), then restore the batch shape
        lidar_cnn_output: torch.Tensor = self.lidar_network(
            lidar_distance_only.reshape(-1,
                                        self.sampled_time_dim_size, n_rays)
        )
        lidar_cnn_output = lidar_cnn_output.reshape(
            *batch_shape, *lidar_cnn_output.shape[1:])
        lidar_cnn_output_flat = lidar_cnn_output.flatten(
            len(batch_shape)).reshape(*batch_shape, -1)

        # only prev steering, throttle in input
        dense_input = torch.cat(
            [lidar_cnn_output_flat, steering_angle, cur_throttle], dim=-1)
        dense_output: torch.Tensor = self.dense(dense_input)

        return dense_output, lidar_cnn_output


class ActionModel(torch.nn.Module):
    def __init__(self):
        super().__init__()
        # 2 for throttle (loc, scale), 2 for steering (loc, scale)
        self.head = torch.nn.Linear(64, 4)
        torch.nn.init.orthogonal_(self.head.weight, gain=0.01)
        torch.nn.init.zeros_(self.head.bias)

    def forward(self, hidden_layer: torch.Tensor):

        out = self.head(hidden_layer)

        # Keep the trailing singleton: the action spec is (..., 1) per component
        # (SplitAction slices the (..., 2) continuous action), and unbind would
        # drop it, so the sampled action no longer fits the env's action buffer.
        throttle_loc = out[..., 0:1]
        throttle_scale = out[..., 1:2]
        steering_loc = out[..., 2:3]
        steering_scale = out[..., 3:4]

        throttle_scale = (torch.nn.functional.softplus(
            throttle_scale) + 1e-3) / 2.0
        steering_scale = (torch.nn.functional.softplus(
            steering_scale - 1.0) + 1e-3) / 2.0

        return throttle_loc, throttle_scale, steering_loc, steering_scale


class AuxModel(torch.nn.Module):
    def __init__(self):
        super().__init__()
        self.head = torch.nn.Linear(64, len(AUX_HEAD_KEYS))

    def forward(self, hidden_layer: torch.Tensor, lidar_cnn_output: torch.Tensor):
        out: torch.Tensor = self.head(hidden_layer)
        return tuple(out[..., i:i + 1] for i in range(len(AUX_HEAD_KEYS)))


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


def make_or_load_model(
    name: str,
    num_stacked_lidar_frames: int,
    n_rays: int,
    ray_kernel: int,
    ray_stride: int,
    time_subsample: int = 1,
) -> tuple[ActorValueAuxOperator, dict[str, Any], int, dict[str, Any] | None]:
    if os.path.exists(f"checkpoints/{name}"):
        # get latest checkpoint
        checkpoints = [f for f in os.listdir(
            f"checkpoints/{name}") if f.endswith(".pt")]
        if not checkpoints:
            raise ValueError(f"No checkpoints found in checkpoints/{name}")
        latest_checkpoint = max(checkpoints, key=lambda f: int(
            f.split("_")[-1].split(".")[0]))
        print(f"Loading model from checkpoints/{name}/{latest_checkpoint}")
        return load_model(f"checkpoints/{name}/{latest_checkpoint}")
    else:
        return (*make_model(
            num_stacked_lidar_frames=num_stacked_lidar_frames,
            n_rays=n_rays,
            ray_kernel=ray_kernel,
            ray_stride=ray_stride,
            time_subsample=time_subsample,
        ), 0, None)


def make_model(
    num_stacked_lidar_frames: int,
    n_rays: int,
    ray_kernel: int,
    ray_stride: int,
    time_subsample: int = 1,
) -> tuple[ActorValueAuxOperator, dict[str, Any]]:
    trunk_tensordict_model = TensorDictModule(
        TrunkModel(
            num_stacked_lidar_frames=num_stacked_lidar_frames,
            n_rays=n_rays,
            ray_kernel=ray_kernel,
            ray_stride=ray_stride,
            time_subsample=time_subsample,
        ),
        in_keys=[("agents", "stacked_lidar"), ("agents", "steering_angle"),
                 ("agents", "throttle")],
        out_keys=["hidden_layer", "lidar_cnn_output"]
    )

    aux = TensorDictModule(
        AuxModel(),
        in_keys=["hidden_layer", "lidar_cnn_output"],
        out_keys=[("aux", name) for name in AUX_HEAD_KEYS]
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

    model_config = {
        "num_stacked_lidar_frames": num_stacked_lidar_frames,
        "n_rays": n_rays,
        "ray_kernel": ray_kernel,
        "ray_stride": ray_stride,
        "time_subsample": time_subsample,
    }

    return ActorValueAuxOperator(
        trunk_tensordict_model,
        actor,
        critic,
        aux,
    ), model_config


def save_model(
    model: ActorValueAuxOperator,
    model_config: dict,
    optim: dict[str, Any],
    iter: int,
    name: str,
):
    path = f"checkpoints/{name}/iteration_{iter:05d}.pt"
    os.makedirs(os.path.dirname(path), exist_ok=True)
    checkpoint = {
        "model": model.state_dict(),
        "model_config": model_config,
        "optim": optim,
        "iter": iter
    }
    torch.save(checkpoint, path)


def load_model(path: str) -> tuple[ActorValueAuxOperator, dict[str, Any], int, dict[str, Any] | None]:
    checkpoint = torch.load(path, map_location="cpu")
    model_config = checkpoint["model_config"]
    # older checkpoints carry config keys from the removed conv2d trunk
    if model_config.pop("lidar_conv", "conv1d") != "conv1d":
        raise ValueError(f"{path} uses the removed conv2d lidar trunk")
    model_config.pop("time_stride", None)
    model_config.pop("time_kernel", None)
    optim_state_dict = checkpoint["optim"]
    model, _ = make_model(**model_config)
    model.load_state_dict(checkpoint["model"])
    return model, model_config, checkpoint["iter"], optim_state_dict
