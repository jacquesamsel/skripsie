import optuna
from utils import CURVATURE_LOOKAHEAD_KEYS, CURVATURE_LOOKAHEAD_DISTANCES

HYPERPARAMETER_GROUPS = [
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
        "wheel_slip_lb_forward"
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


if __name__ == "__main__":
    for i in range(len(HYPERPARAMETER_GROUPS)):
