import torch
from tensordict.nn import TensorDictModule
from torchrl.modules import ActorValueOperator, ProbabilisticActor, TanhNormal, ValueOperator
import tensordict as td


# Raw vector obs indices fed to the network (see F1TenthRacing.CollectObservations):
# 1 steering, 2 throttle, 37 forward velocity (signed, m/s), 38 lateral velocity (m/s)
VECTOR_FEATURES = [1, 2, 37, 38]
# Per-feature divisor so every input lands roughly in [-1, 1].
# Steering/throttle are already in [-1, 1]; MAX_SPEED is an estimate — check
# the logged max of obs_vector idx 37 and adjust.
MAX_SPEED = 5.0
VECTOR_SCALE = [1.0, 1.0, MAX_SPEED, MAX_SPEED]


class TrunkModel(torch.nn.Module):
    def __init__(self):
        super().__init__()

        self.register_buffer("vector_features", torch.tensor(
            VECTOR_FEATURES, dtype=torch.long), persistent=False)
        self.register_buffer("vector_scale", torch.tensor(
            VECTOR_SCALE, dtype=torch.float32), persistent=False)

        self.lidar_network = torch.nn.Sequential(
            torch.nn.Conv1d(in_channels=1, out_channels=16, kernel_size=8),
            torch.nn.ReLU(),
            torch.nn.Conv1d(in_channels=16, out_channels=32, kernel_size=8),
            torch.nn.ReLU(),
            torch.nn.Conv1d(in_channels=32, out_channels=64, kernel_size=8),
            torch.nn.ReLU(),
            torch.nn.Conv1d(in_channels=64, out_channels=32, kernel_size=8),
            torch.nn.ReLU(),
            torch.nn.Conv1d(in_channels=32, out_channels=8, kernel_size=8),
            torch.nn.ReLU(),
        )

        lidar_len = 101
        for _ in range(5):
            lidar_len -= 7
        lidar_out_channels = 8
        dense_in = lidar_out_channels * lidar_len + len(VECTOR_FEATURES)

        self.dense = torch.nn.Sequential(
            torch.nn.Linear(dense_in, 128),
            torch.nn.ReLU(),
            torch.nn.Linear(128, 256),
            torch.nn.ReLU(),
            torch.nn.Linear(256, 128),
            torch.nn.ReLU(),
            torch.nn.Linear(128, 64),
            torch.nn.ReLU(),
            torch.nn.Linear(64, 32),
            torch.nn.ReLU()
        )

    def forward(self, lidar: torch.Tensor, vector: torch.Tensor):
        # lidar block is [T_1..T_n, Miss, Distance] -> Distance is always the last channel
        lidar = lidar[..., -1, :]
        *batch_shape, lidar_len = lidar.shape

        # flatten all leading batch dims (agents, time, envs, ...) into one
        # dim so Conv1d always sees (N, 1, L), then restore the batch shape
        lidar_cnn_output: torch.Tensor = self.lidar_network(
            lidar.reshape(-1, 1, lidar_len))
        lidar_cnn_output = lidar_cnn_output.flatten(
            1).reshape(*batch_shape, -1)

        # only steering, throttle and signed forward/lateral velocity of the raw
        # vector obs are fed to the network (normalised) — the rest (position,
        # encoders, progress delta, etc.) is only used on the Python side
        vector_input = vector[..., self.vector_features] / self.vector_scale
        dense_input = torch.cat([lidar_cnn_output, vector_input], dim=-1)
        dense_output: torch.Tensor = self.dense(dense_input)

        return dense_output


class ActionModel(torch.nn.Module):
    def __init__(self):
        super().__init__()
        # 2 for throttle (loc, scale), 2 for steering (loc, scale)
        self.head = torch.nn.Linear(32, 4)

    def forward(self, hidden_layer: torch.Tensor):

        out = self.head(hidden_layer)

        throttle_loc, throttle_scale, steering_loc, steering_scale = out.unbind(
            -1)

        throttle_scale = (torch.nn.functional.softplus(
            throttle_scale) + 1e-3) / 2.0
        steering_scale = (torch.nn.functional.softplus(
            steering_scale - 1.0) + 1e-3) / 2.0

        return throttle_loc, throttle_scale, steering_loc, steering_scale


class ValueModel(torch.nn.Module):
    def __init__(self):
        super().__init__()
        self.head = torch.nn.Linear(32, 1)

    def forward(self, hidden_layer: torch.Tensor):
        return self.head(hidden_layer)


trunk_tensordict_model = TensorDictModule(
    TrunkModel(),
    in_keys=[("agents", "lidar"), ("agents", "vector")],
    out_keys=["hidden_layer"]
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
