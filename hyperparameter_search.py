import os
import multiprocessing as mp
from concurrent.futures import ProcessPoolExecutor
from utils import CURVATURE_LOOKAHEAD_KEYS, CURVATURE_LOOKAHEAD_DISTANCES

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


if __name__ == "__main__":
    print(HYPERPARAMETER_SEARCH_SPACE)
