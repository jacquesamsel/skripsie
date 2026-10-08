import argparse

from train import train
from environment import make_envs
import optuna

# Iterations per trial. Each iteration is a full rollout + GAE + 4 epochs of
# minibatch updates (see train.py's timing printout for how long one takes) --
# tune this against your actual wall-clock budget for n_trials.
TRIAL_ITERS = 250

# Worker IDs select the Unity instance's port (base_port + worker_id). Each
# trial needs its own range -- a closed env's port can stay in TIME_WAIT for a
# bit, so reusing it immediately for the next trial risks a bind failure.
WORKER_IDS_PER_TRIAL = 20

# Fixed across every trial, so that model init, env/track layout and
# minibatch shuffling are identical for each -- isolating the reward
# weights as the only thing that varies between trials.
SEED = 42

# Per-trial torch thread count. When running several copies of this script
# at once (see --num-threads), divide the machine's core count between them
# so they don't oversubscribe each other.
NUM_THREADS = 16

def objective(trial: optuna.Trial):
    forward_velocity_weight = trial.suggest_float(
        "forward_velocity_weight", 0.0, 0.3)
    lateral_velocity_weight = trial.suggest_float(
        "lateral_velocity_weight", 0.0, 0.3)
    curvature_weights_0_5m = trial.suggest_float(
        "curvature_weights_0_5m", 0.0, 0.3)
    curvature_weights_1_0m = trial.suggest_float(
        "curvature_weights_1_0m", 0.0, 0.3)
    curvature_weights_2_0m = trial.suggest_float(
        "curvature_weights_2_0m", 0.0, 0.3)
    wheel_slips_weight_front_lateral = trial.suggest_float(
        "wheel_slips_weight_front_lateral", 0.0, 0.3)
    wheel_slips_weight_rear_lateral = trial.suggest_float(
        "wheel_slips_weight_rear_lateral", 0.0, 0.3)
    wheel_slips_weight_front_forward = trial.suggest_float(
        "wheel_slips_weight_front_forward", 0.0, 0.3)
    wheel_slips_weight_rear_forward = trial.suggest_float(
        "wheel_slips_weight_rear_forward", 0.0, 0.3)
    angular_velocity_y_weight = trial.suggest_float(
        "angular_velocity_y_weight", 0.0, 0.3)

    trial_worker_id_start = 100 + trial.number * WORKER_IDS_PER_TRIAL

    env = make_envs(
        num_envs=8,
        num_agents_per_env=6,
        num_stacked_frames=50,
        time_scale=20.0,
        seed=SEED,
        worker_id_start=trial_worker_id_start,
    )

    # Front/rear each share a single left-right weight (LF/RF share "front",
    # LR/RR share "rear") -- train() itself pairs them, both for this search
    # space (4 wheel-slip params instead of 8) and for the fixed normalisation
    # scale it multiplies each weight by (see AUX_LOSS_SCALE in train.py).
    model, train_stats = train(
        env,
        velocity_forward_weight=forward_velocity_weight,
        velocity_lateral_weight=lateral_velocity_weight,
        curvature_05m_weight=curvature_weights_0_5m,
        curvature_10m_weight=curvature_weights_1_0m,
        curvature_20m_weight=curvature_weights_2_0m,
        wheel_slip_front_forward_weight=wheel_slips_weight_front_forward,
        wheel_slip_front_lateral_weight=wheel_slips_weight_front_lateral,
        wheel_slip_rear_forward_weight=wheel_slips_weight_rear_forward,
        wheel_slip_rear_lateral_weight=wheel_slips_weight_rear_lateral,
        angular_velocity_y_weight=angular_velocity_y_weight,
        num_stacked_lidar_frames=50,
        n_rays=101,
        lidar_conv="conv1d",
        ray_kernel=8,
        ray_stride=1,
        name=f"optuna_trial_{trial.number}",
        max_iters=TRIAL_ITERS,
        seed=SEED,
        num_threads=NUM_THREADS,
    )

    for key, value in train_stats.items():
        trial.set_user_attr("train_" + key, value)

    return train_stats["reward_auc"]


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    # This process's own share of the total trial budget -- when running P
    # copies of this script in parallel against the same study, pass
    # roughly (total desired trials) / P here for each copy.
    parser.add_argument("--n-trials", type=int, default=50)
    # torch threads for this process alone. Set to (core count) / (number of
    # copies you're running at once) so parallel copies don't oversubscribe
    # each other's CPU.
    parser.add_argument("--num-threads", type=int, default=NUM_THREADS)
    args = parser.parse_args()
    NUM_THREADS = args.num_threads

    storage = optuna.storages.JournalStorage(
        optuna.storages.JournalFileStorage("./optuna_journal.log")
    )
    study = optuna.create_study(
        direction="maximize",
        study_name="hyperparameter_search",
        storage=storage,
        load_if_exists=True,
        # constant_liar: while a trial is still running in another process,
        # treat its in-progress params as if they'd already returned a
        # (temporary, worst-case) result, so concurrent processes don't all
        # propose near-identical points before any of them has finished.
        sampler=optuna.samplers.TPESampler(seed=SEED, constant_liar=True),
    )

    study.optimize(
        objective,
        n_trials=args.n_trials,
        show_progress_bar=True,
        catch=(Exception,),
        gc_after_trial=True,
    )
