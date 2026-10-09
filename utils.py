from typing import Literal

from tensordict import TensorDict
from torch.nn.functional import smooth_l1_loss
import json
from torcheval.metrics.functional import r2_score

CURVATURE_LOOKAHEAD_DISTANCES = [0.5 * i for i in range(1, 17)]
CURVATURE_LOOKAHEAD_KEYS = [
    f"track_curvature_{metres:.2f}".replace(".", "_")
    for metres in CURVATURE_LOOKAHEAD_DISTANCES
]

AUX_HEAD_KEYS = [
    "velocity_forward",
    "velocity_lateral",
    *CURVATURE_LOOKAHEAD_KEYS,
    "wheel_slip_forward_front_left",
    "wheel_slip_lateral_front_left",
    "wheel_slip_forward_back_left",
    "wheel_slip_lateral_back_left",
    "wheel_slip_forward_front_right",
    "wheel_slip_lateral_front_right",
    "wheel_slip_forward_back_right",
    "wheel_slip_lateral_back_right",
    "angular_velocity_y"
]


def get_aux_head_true_values(td: TensorDict) -> dict[str, float]:
    return {
        key: td["agents", key]
        for key in AUX_HEAD_KEYS
    }


def get_aux_head_predicted_values(td: TensorDict) -> dict[str, float]:
    return {
        key: td["aux", key]
        for key in AUX_HEAD_KEYS
    }


def load_aux_head_scaling_factors(path: str) -> dict[str, tuple[float, float]]:
    with open(path, "r") as f:
        scaling_factors = json.load(f)
    return {
        key: (scaling_factors[key]["mean"], scaling_factors[key]["var"]**(1/2))
        for key in AUX_HEAD_KEYS
    }


def gen_aux_losses(td: TensorDict, scaling_factors: dict[str, tuple[float, float]], reduction: Literal['none', 'mean', 'sum'] = 'mean') -> TensorDict:
    predicted_values = get_aux_head_predicted_values(td)
    true_values = get_aux_head_true_values(td)
    aux_losses = TensorDict({
        key: smooth_l1_loss(
            predicted_values[key],
            true_values[key],
            reduction=reduction,
            beta=scaling_factors[key][1]  # Use the standard deviation as beta
        ) / scaling_factors[key][1] for key in AUX_HEAD_KEYS
    }, batch_size=td.batch_size if reduction == 'none' else [])
    return aux_losses

def get_aux_head_r2_scores(prediction: TensorDict, target: TensorDict) -> TensorDict:
    r2_scores = {
        key: r2_score(prediction[key], target[key])
        for key in AUX_HEAD_KEYS
    }
    return r2_scores