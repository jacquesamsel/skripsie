import torch
from tensordict.nn import TensorDictModule, TensorDictSequential
from torchrl.modules import ActorValueOperator, ProbabilisticActor, SafeProbabilisticTensorDictSequential, TanhNormal, ValueOperator
import tensordict as td
from torchrl.modules.tensordict_module.sequence import SafeSequential

class TrunkModel(torch.nn.Module):
    def __init__(self):
        super().__init__()
        self.lidar_network = torch.nn.Sequential(
            torch.nn.Conv1d(in_channels=1, out_channels=16, kernel_size=8),
            torch.nn.ReLU(),
            torch.nn.Conv1d(in_channels=16, out_channels=32, kernel_size=8),
            torch.nn.ReLU(),
            torch.nn.Conv1d(in_channels=32, out_channels=64, kernel_size=8),
            torch.nn.ReLU(),
            torch.nn.Conv1d(in_channels=64, out_channels=32, kernel_size=8),
            torch.nn.ReLU(),
            torch.nn.Conv1d(in_channels=32, out_channels=16, kernel_size=8),
            torch.nn.ReLU(),
        )

        lidar_len = 101
        for _ in range(5):
            lidar_len -= 7
        lidar_out_channels = 16
        dense_in = lidar_out_channels * lidar_len + 2

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

    def forward(self, lidar: torch.Tensor, cur_steering: torch.Tensor, cur_throttle: torch.Tensor):
        # lidar block is [T_1..T_n, Miss, Distance] -> Distance is always the last channel
        lidar = lidar[..., -1, :]
        *batch_shape, lidar_len = lidar.shape

        # flatten all leading batch dims (agents, time, envs, ...) into one
        # dim so Conv1d always sees (N, 1, L), then restore the batch shape
        lidar_cnn_output: torch.Tensor = self.lidar_network(
            lidar.reshape(-1, 1, lidar_len))
        lidar_cnn_output = lidar_cnn_output.reshape(
            *batch_shape, *lidar_cnn_output.shape[1:])
        lidar_cnn_output_flat = lidar_cnn_output.flatten(
            len(batch_shape)).reshape(*batch_shape, -1)

        # only prev steering, throttle in input
        dense_input = torch.cat([lidar_cnn_output_flat, cur_steering, cur_throttle], dim=-1)
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
    def __init__(self, lidar_size = 101):
        super().__init__()
        self.head = torch.nn.Linear(64, 17)

    def forward(self, hidden_layer: torch.Tensor, lidar_cnn_output: torch.Tensor):
        out: torch.Tensor = self.head(hidden_layer)
        velocity = out[..., :2] #(..., 2) = [forward_velocity, lateral_velocity]
        pos_delta = out[..., 2:4] #(..., 2) = [forward_pos_delta, lateral_pos_delta]
        angular_velocity = out[..., 4] #(..., 1) = [angular_velocity]
        wheel_slips = out[..., 5:14] #(..., 8) = [wheel_slip_lf_forward, wheel_slip_lf_sideways, ...] lf, rf, lr, rr
        curvature = out[..., 14:17] #(..., 3) = [curvature_0.5_m, curvature_1.0_m, curvature_2.0_m]

        return velocity, pos_delta, angular_velocity, wheel_slips, curvature

class ValueModel(torch.nn.Module):
    def __init__(self):
        super().__init__()
        self.head = torch.nn.Linear(64, 1)

    def forward(self, hidden_layer: torch.Tensor):
        return self.head(hidden_layer)


trunk_tensordict_model = TensorDictModule(
    TrunkModel(),
    in_keys=[("agents", "lidar"), ("agents", "cur_steering_angle"), ("agents", "cur_throttle")],
    out_keys=["hidden_layer", "lidar_cnn_output"]
)

aux = TensorDictModule(
    AuxModel(),
    in_keys=["hidden_layer", "lidar_cnn_output"],
    out_keys=["velocity", "pos_delta", "angular_velocity", "wheel_slips", "curvature"]
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