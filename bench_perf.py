import contextlib
import csv
import multiprocessing as mp
import os
import platform
from concurrent.futures import ProcessPoolExecutor, as_completed
from dataclasses import dataclass
from datetime import datetime
from itertools import product
from pathlib import Path

MAX_ITERS = 5
PORT_STRIDE = 20  # worker-id ports reserved per slot; must exceed any config's num_envs
TRIAL_PORT_STRIDE = 256  # must exceed PORT_STRIDE * max(WORKER_COUNTS)
FRAMES_PER_ROLLOUT = 256  # must match the hardcoded value in train.py

WORKER_COUNTS = [8]
THREAD_COUNTS = [16]
ENV_COUNTS = [8]
NUM_AREAS = [6, 8, 12, 24]

BENCH_DIR = Path("bench_results")
LOG_DIR = BENCH_DIR / "logs"
CSV_PATH = Path("results/bench_perf.csv")


@dataclass(frozen=True)
class Trial:
    num_workers: int
    n_python_threads: int
    num_envs: int
    num_areas: int


def run_worker(trial: Trial, slot: int, trial_index: int, log_path: Path) -> float:
    """Runs in its own spawned process. Returns seconds/iter."""
    n = str(trial.n_python_threads)
    os.environ["OMP_NUM_THREADS"] = n
    os.environ["MKL_NUM_THREADS"] = n
    os.environ["OPENBLAS_NUM_THREADS"] = n

    from environment import RoboRacerParallelEnvs
    from train import train, TrainParams
    from utils import gen_aux_weights_default_zero

    with open(log_path, "w") as log_file, \
            contextlib.redirect_stdout(log_file), \
            contextlib.redirect_stderr(log_file):
        env = RoboRacerParallelEnvs(
            file_name="TestUnityProject/Test speed/build.app" if platform.system() == "Darwin" else "linux_build/linux_build.x86_64",
            num_envs=trial.num_envs,
            num_areas=trial.num_areas,
            num_stacked_frames=50,
            seed=0,
            # A port tied only to slot number would be reused by every trial;
            # a worker that dies mid-handshake can leak its Unity socket (see
            # mlagents_envs's atexit _close() failing on an unset
            # _communicator), which would then permanently fail that same
            # slot in every later trial. Folding in trial_index gives every
            # trial its own port range, so a leak costs one port, not the
            # rest of the sweep.
            start_worker_id=trial_index * TRIAL_PORT_STRIDE + slot * PORT_STRIDE,
        )
        try:
            elapsed_ns = train(
                env,
                params=TrainParams(
                    aux_weights=gen_aux_weights_default_zero({}),
                    name=None,
                    seed=0,
                    max_iters=MAX_ITERS,
                    num_threads=trial.n_python_threads,
                    rollout_length=FRAMES_PER_ROLLOUT,
                )
            )
            elapsed = elapsed_ns / 1e9
        finally:
            env.close()

    return elapsed / MAX_ITERS


def run_trial(trial: Trial, trial_index: int) -> dict | None:
    ctx = mp.get_context("spawn")
    with ProcessPoolExecutor(max_workers=trial.num_workers, mp_context=ctx) as ex:
        futures = {
            ex.submit(
                run_worker, trial, slot, trial_index,
                LOG_DIR / f"w{trial.num_workers}_t{trial.n_python_threads}_e{trial.num_envs}_a{trial.num_areas}_slot{slot}.log",
            ): slot
            for slot in range(trial.num_workers)
        }
        seconds_per_iter = []
        for fut in as_completed(futures):
            slot = futures[fut]
            try:
                seconds_per_iter.append(fut.result())
            except Exception as e:
                print(f"FAILED trial={trial} slot={slot}: {e!r}")

    if not seconds_per_iter:
        return None

    mean_spi = sum(seconds_per_iter) / len(seconds_per_iter)
    # timesteps = one step per area (they step in parallel inside each env instance)
    per_worker_timesteps_per_sec = (
        FRAMES_PER_ROLLOUT * trial.num_envs * trial.num_areas / mean_spi
    )

    return {
        "num_workers": trial.num_workers,
        "n_python_threads": trial.n_python_threads,
        "num_envs": trial.num_envs,
        "num_areas": trial.num_areas,
        "completed_workers": len(seconds_per_iter),
        "mean_seconds_per_iter": mean_spi,
        "per_worker_timesteps_per_sec": per_worker_timesteps_per_sec,
        "total_timesteps_per_sec": trial.num_workers * per_worker_timesteps_per_sec,
    }


def load_completed_trials() -> set[tuple[int, int, int, int]]:
    if not CSV_PATH.exists():
        return set()
    with open(CSV_PATH, newline="") as f:
        return {
            (int(row["num_workers"]), int(row["n_python_threads"]),
             int(row["num_envs"]), int(row["num_areas"]))
            for row in csv.DictReader(f)
        }


def log_result(row: dict):
    BENCH_DIR.mkdir(exist_ok=True)
    is_new = not CSV_PATH.exists()
    with open(CSV_PATH, "a", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["timestamp", *row.keys()])
        if is_new:
            writer.writeheader()
        writer.writerow({"timestamp": datetime.now().isoformat(timespec="seconds"), **row})


def main():
    LOG_DIR.mkdir(parents=True, exist_ok=True)

    completed = load_completed_trials()
    # Index into the full (w, t, e, a) grid, not into the filtered/resumed list below:
    # it's used as a port offset (see TRIAL_PORT_STRIDE), and it has to stay stable
    # across resumed runs so a trial never reuses a port some earlier run may have
    # leaked under the same index.
    all_combos = list(product(WORKER_COUNTS, THREAD_COUNTS, ENV_COUNTS, NUM_AREAS))
    trials = [
        (all_combos.index((w, t, e, a)), Trial(num_workers=w, n_python_threads=t, num_envs=e, num_areas=a))
        for w, t, e, a in all_combos
        # workers=8/envs=16 spawns 128 concurrent Unity instances, which
        # drove this machine into swap and crashed every worker mid-step,
        # then poisoned every later trial via leaked mlagents ports.
        if (w, e) != (8, 16)
    ]
    trials = [
        (idx, t) for idx, t in trials
        if (t.num_workers, t.n_python_threads, t.num_envs, t.num_areas) not in completed
    ]
    if not trials:
        print("All trials already present in", CSV_PATH)
        return

    for i, (trial_index, trial) in enumerate(trials, 1):
        print(f"[{i}/{len(trials)}] workers={trial.num_workers} "
              f"threads={trial.n_python_threads} envs={trial.num_envs} areas={trial.num_areas} ...", flush=True)
        result = run_trial(trial, trial_index)
        if result is None:
            print("  all workers failed, skipping")
            continue
        log_result(result)
        print(f"  {result['mean_seconds_per_iter']:.3f} s/iter/worker, "
              f"{result['total_timesteps_per_sec']:.0f} total timesteps/s")

    print(f"\nResults appended to {CSV_PATH}")


if __name__ == "__main__":
    main()
