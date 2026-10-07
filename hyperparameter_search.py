from train import train
from environment import make_envs
import optuna
import torch

# Iterations per trial. Each iteration is a full rollout + GAE + 4 epochs of
# minibatch updates (see train.py's timing printout for how long one takes) --
# tune this against your actual wall-clock budget for n_trials.
TRIAL_ITERS = 50

# Worker IDs select the Unity instance's port (base_port + worker_id). Each
# trial needs its own range -- a closed env's port can stay in TIME_WAIT for a
# bit, so reusing it immediately for the next trial risks a bind failure.
WORKER_IDS_PER_TRIAL = 20


def objective(trial: optuna.Trial):
    forward_velocity_weight = trial.suggest_float(
        "forward_velocity_weight", 0.0, 1.0)
    lateral_velocity_weight = trial.suggest_float(
        "lateral_velocity_weight", 0.0, 1.0)
    curvature_weights_0_5m = trial.suggest_float(
        "curvature_weights_0_5m", 0.0, 1.0)
    curvature_weights_1_0m = trial.suggest_float(
        "curvature_weights_1_0m", 0.0, 1.0)
    curvature_weights_1_5m = trial.suggest_float(
        "curvature_weights_1_5m", 0.0, 1.0)
    wheel_slips_weight_front_lateral = trial.suggest_float(
        "wheel_slips_weight_front_lateral", 0.0, 1.0)
    wheel_slips_weight_rear_lateral = trial.suggest_float(
        "wheel_slips_weight_rear_lateral", 0.0, 1.0)
    wheel_slips_weight_front_forward = trial.suggest_float(
        "wheel_slips_weight_front_forward", 0.0, 1.0)
    wheel_slips_weight_rear_forward = trial.suggest_float(
        "wheel_slips_weight_rear_forward", 0.0, 1.0)
    yaw_rate_weight = trial.suggest_float("yaw_rate_weight", 0.0, 1.0)

    trial_worker_id_start = 100 + trial.number * WORKER_IDS_PER_TRIAL

    env = make_envs(
        num_envs=8,
        num_agents_per_env=6,
        num_stacked_frames=50,
        time_scale=20.0,
        worker_id_start=trial_worker_id_start,
    )

    model, train_stats = train(
        env,
        forward_velocity_weight=forward_velocity_weight,
        lateral_velocity_weight=lateral_velocity_weight,
        curvature_weights=torch.as_tensor([
            curvature_weights_0_5m,
            curvature_weights_1_0m,
            curvature_weights_1_5m
        ]),
        # (4, 2): rows are wheels in [LF, RF, LR, RR] order, columns are
        # [forward, lateral] -- matches AuxModel.forward's wheel_slips layout
        # and the ("agents", "wheel_slips") target shape. Front/rear share a
        # weight left-right to keep the search space at 4 params instead of 8.
        wheel_slips_weight=torch.as_tensor([
            [wheel_slips_weight_front_forward, wheel_slips_weight_front_lateral],
            [wheel_slips_weight_front_forward, wheel_slips_weight_front_lateral],
            [wheel_slips_weight_rear_forward, wheel_slips_weight_rear_lateral],
            [wheel_slips_weight_rear_forward, wheel_slips_weight_rear_lateral],
        ]),
        yaw_rate_weight=yaw_rate_weight,
        num_stacked_lidar_frames=50,
        n_rays=101,
        lidar_conv="conv1d",
        ray_kernel=8,
        ray_stride=1,
        name=f"optuna_trial_{trial.number}",
        max_iters=TRIAL_ITERS,
    )

    for key, value in train_stats.items():
        trial.set_user_attr("train_" + key, value)

    # Run rollout to check

    return train_stats["reward_mean"]


if __name__ == "__main__":
    storage = optuna.storages.JournalStorage(
        optuna.storages.JournalFileStorage("./optuna_journal.log")
    )
    study = optuna.create_study(
        direction="maximize",
        study_name="hyperparameter_search",
        storage=storage,
        load_if_exists=True
    )

    study.optimize(objective, n_trials=500, show_progress_bar=True)
