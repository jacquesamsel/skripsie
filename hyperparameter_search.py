import optuna


def generate_grid(
    params: dict[str, list[float]]
):
    """Generates a grid of hyperparameter combinations from the given parameter ranges.

    Args:
        params (dict[str, list[float]]): A dictionary where keys are hyperparameter names and values are lists of possible values.

    Returns:
        list[dict[str, float]]: A list of dictionaries, each representing a unique combination of hyperparameters.
    """
    from itertools import product

    keys = params.keys()
    values = params.values()
    grid = [dict(zip(keys, combination)) for combination in product(*values)]
    return grid

def generate_single_try_per_parameter():


#def objective(trial: optuna.Trial):
    # sample hyperparameters


if __name__ == "__main__":
    grid = generate_grid({
        "velocity_forward_weight": [0.1, 0.5, 1.0],
        "velocity_lateral_weight": [0.1, 0.5, 1.0],
        "curvature_weights": {
            "close": [0.1, 0.5, 1.0],
            "medium": [0.1, 0.5, 1.0],
            "far": [0.1, 0.5, 1.0]
        },
        "wheel_slip_front_forward": [0.1, 0.5, 1.0],
        "wheel_slip_front_lateral": [0.1, 0.5, 1.0],
        "wheel_slip_rear_forward": [0.1, 0.5, 1.0],
        "wheel_slip_rear_lateral": [0.1, 0.5, 1.0],
        "angular_velocity_weight": [0.1, 0.5, 1.0],
    })

    print(f"Generated {len(grid)} hyperparameter combinations.")