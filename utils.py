from typing import Literal

from tensordict import NestedKey, TensorDict
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
    "angular_velocity_y",
    *CURVATURE_LOOKAHEAD_KEYS,
    "wheel_slip_forward_front_left",
    "wheel_slip_forward_front_right",
    "wheel_slip_lateral_front_left",
    "wheel_slip_lateral_front_right",
    "wheel_slip_forward_back_left",
    "wheel_slip_forward_back_right",
    "wheel_slip_lateral_back_left",
    "wheel_slip_lateral_back_right"
]


def compare_aux_head_keys_sort(a: str, b: str) -> int:
    if a in AUX_HEAD_KEYS and b in AUX_HEAD_KEYS:
        return AUX_HEAD_KEYS.index(a) - AUX_HEAD_KEYS.index(b)
    else:
        raise ValueError(f"Keys {a} and {b} must both be in AUX_HEAD_KEYS")


REWARD_TERM_KEYS: dict[str, NestedKey] = {
    "progress": ("agents", "reward_progress"),
    "velocity_forward": ("agents", "reward_velocity_forward"),
    "step_penalty": ("agents", "reward_step_penalty"),
    "collision": ("agents", "reward_collision"),
}


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


def gen_aux_weights_default_zero(aux_weights_override: dict[str, float]) -> dict[str, float]:
    return {
        key: aux_weights_override.get(key, 0.0)
        for key in AUX_HEAD_KEYS
    }

def gen_aux_weights(default_value: float):
    return {
        key: default_value
        for key in AUX_HEAD_KEYS
    }


def load_aux_head_scaling_factors(path: str) -> dict[str, tuple[float, float]]:
    with open(path, "r") as f:
        scaling_factors = json.load(f)
    return {
        key: (scaling_factors[key]["mean"], scaling_factors[key]["var"]**(1/2))
        for key in AUX_HEAD_KEYS
    }


def gen_aux_losses(td: TensorDict, scaling_factors: dict[str, tuple[float, float]]):
    predicted_values = get_aux_head_predicted_values(td)
    true_values = get_aux_head_true_values(td)
    aux_losses = {
        key: smooth_l1_loss(
            predicted_values[key],
            (true_values[key] - scaling_factors[key][0]) /
            scaling_factors[key][1],
            reduction='mean',
        ) for key in AUX_HEAD_KEYS
    }
    return aux_losses


def get_aux_head_r2_scores(prediction: TensorDict, target: TensorDict, scaling_factors: dict[str, tuple[float, float]]):
    r2_scores = {
        key: r2_score(prediction[key].flatten(), ((
            target[key] - scaling_factors[key][0]) / scaling_factors[key][1]).flatten())
        for key in AUX_HEAD_KEYS
    }
    return r2_scores


def rollout_stats(rollout: TensorDict) -> dict[str, float]:

    next_td = rollout["next"]
    terminated = next_td["agents", "terminated"]
    # Crashes are the only terminations; a timeout or a track regeneration
    # interrupts the episode instead, and Car.cs reports those as truncations.
    crashes = terminated.sum()
    episodes = next_td["agents", "done"].sum()

    stats = {
        "reward_mean": next_td["agents", "reward"].mean().item(),
        "velocity_forward_mean": next_td["agents", "velocity_forward"].mean().item(),
        "progress_mean": next_td["agents", "progress"].mean().item(),
        # Per step: the chance that any given step is a car hitting a wall. Scales
        # with how long episodes last, so it moves when episodeTimeoutSeconds does.
        "collision_rate_per_step": terminated.float().mean().item(),
        # Per episode: the share of the episodes that ended in this rollout which
        # ended in a crash rather than in a timeout. The one to read as "how often
        # does it still crash", since it does not depend on episode length.
        #
        # nan rather than zero when no episode finished at all: a rollout shorter
        # than an episode has no answer, and zero would read as a clean sweep.
        "collision_rate_per_episode": (crashes / episodes).item() if episodes > 0 else float("nan"),
    }
    stats.update({
        f"reward_{name}_mean": next_td[key].mean().item()
        for name, key in REWARD_TERM_KEYS.items()
    })
    return stats
