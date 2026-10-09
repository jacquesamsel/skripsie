import os
import multiprocessing as mp
from concurrent.futures import ProcessPoolExecutor
from utils import CURVATURE_LOOKAHEAD_KEYS, CURVATURE_LOOKAHEAD_DISTANCES
from dataclasses import dataclass, asdict

HYPERPARAMETER_GROUPS = [
    [],
    ["velocity_forward"],
    ["velocity_lateral"],
    [
        CURVATURE_LOOKAHEAD_KEYS[i]
        for i in range(len(CURVATURE_LOOKAHEAD_KEYS))
        if CURVATURE_LOOKAHEAD_DISTANCES[i] <= 3.0
    ],
    [
        CURVATURE_LOOKAHEAD_KEYS[i]
        for i in range(len(CURVATURE_LOOKAHEAD_KEYS))
        if CURVATURE_LOOKAHEAD_DISTANCES[i] <= 6.0 and CURVATURE_LOOKAHEAD_DISTANCES[i] > 3.0
    ],
    [
        CURVATURE_LOOKAHEAD_KEYS[i]
        for i in range(len(CURVATURE_LOOKAHEAD_KEYS))
        if CURVATURE_LOOKAHEAD_DISTANCES[i] <= 8.0 and CURVATURE_LOOKAHEAD_DISTANCES[i] > 6.0
    ],
    [
        "wheel_slip_lf_forward",
        "wheel_slip_rf_forward"
    ],
    [
        "wheel_slip_lf_lateral",
        "wheel_slip_rf_lateral"
    ],
    [
        "wheel_slip_lb_forward",
        "wheel_slip_rb_forward"
    ],
    [
        "wheel_slip_lb_lateral",
        "wheel_slip_rb_lateral"
    ],
    [
        "angular_velocity_y"
    ]
]

WEIGHT_VALUES = [0.5, 0.1, 1]
NUM_TRIALS_PER_GROUP = 5

HYPERPARAMETER_SEARCH_SPACE = [{}] + [
    {key: value for key in group} for value in WEIGHT_VALUES for group in HYPERPARAMETER_GROUPS if group
]


@dataclass(frozen=True)
class Trial:
    name: str
    params: dict[str, float]
    seed: int


def worker(trial: Trial):
    from environment import RoboRacerParallelEnvs
    from train import train
    from utils import gen_aux_weights_default_zero

    env = RoboRacerParallelEnvs(
        num_envs=8,
        seed=trial.seed
    )
    train(
        env,
        aux_weights=gen_aux_weights_default_zero(trial.params),
        name=trial.name,
        n_rays=101,
        lidar_conv="conv1d"
    )


def main():
    trials = [
        Trial(
            name=f"trial_{i}",
            params=params,
            seed=42
        )
        for i, params in enumerate(HYPERPARAMETER_SEARCH_SPACE)
    ]
    ctx = mp.get_context("spawn")
    with ProcessPoolExecutor(max_workers=3, mp_context=ctx) as ex:
        futures = [
            ex.submit(worker, trial) for trial in trials
        ]
        for i, fut in enumerate(futures):
            try:
                fut.result()
            except Exception as e:
                print(f"Trial {trials[i].name} failed with exception: {e}")


if __name__ == "__main__":
    main()
