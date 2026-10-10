"""Sweep concurrent-training throughput over (num_workers, n_python_threads, num_envs).

Edit WORKER_COUNTS / THREAD_COUNTS / ENV_COUNTS below, then: python bench_perf.py

For each grid point, num_workers identical training processes run concurrently
(same thread count and env count each) for MAX_ITERS iterations, with no
checkpointing/TensorBoard logging. Throughput is reported in environment
timesteps/sec (frames_per_rollout * num_envs * num_areas / seconds_per_iter),
both per worker and totaled across all concurrent workers, so you can see
where adding more concurrent workers stops paying off. Each worker's own
stdout/stderr (Unity/torch noise) is redirected to bench_results/logs/ instead
of the console. One summary row per grid point is appended to
bench_results/bench_perf.csv.
"""
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
NUM_AREAS = 6
PORT_STRIDE = 100  # worker-id ports reserved per slot; must exceed any config's num_envs
TOTAL_CPUS = os.cpu_count() or 1
FRAMES_PER_ROLLOUT = 256  # must match the hardcoded value in train.py

WORKER_COUNTS = [2, 4, 8, 12]
THREAD_COUNTS = [8, 16]
ENV_COUNTS = [4, 8]

BENCH_DIR = Path("bench_results")
LOG_DIR = BENCH_DIR / "logs"
CSV_PATH = BENCH_DIR / "bench_perf.csv"


@dataclass(frozen=True)
class Trial:
    num_workers: int
    n_python_threads: int
    num_envs: int
    num_areas: int = NUM_AREAS


def run_worker(trial: Trial, slot: int, log_path: Path) -> float:
    """Runs in its own spawned process. Returns seconds/iter."""
    # Pin this process (and the Unity child it spawns) to a slice of cores so
    # Unity's native thread pools (which size themselves off detected CPU
    # count, not -job-worker-count) don't each try to grab all TOTAL_CPUS.
    cores_per_worker = max(1, TOTAL_CPUS // trial.num_workers)
    start_core = slot * cores_per_worker
    os.sched_setaffinity(0, range(start_core, start_core + cores_per_worker))

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
            start_worker_id=slot * PORT_STRIDE,
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


def run_trial(trial: Trial) -> dict | None:
    ctx = mp.get_context("spawn")
    with ProcessPoolExecutor(max_workers=trial.num_workers, mp_context=ctx) as ex:
        futures = {
            ex.submit(
                run_worker, trial, slot,
                LOG_DIR / f"w{trial.num_workers}_t{trial.n_python_threads}_e{trial.num_envs}_slot{slot}.log",
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
    trials = [
        Trial(num_workers=w, n_python_threads=t, num_envs=e)
        for w, t, e in product(WORKER_COUNTS, THREAD_COUNTS, ENV_COUNTS)
        # workers=8/envs=16 spawns 128 concurrent Unity instances, which
        # drove this machine into swap and crashed every worker mid-step,
        # then poisoned every later trial via leaked mlagents ports.
        if (w, e) != (8, 16)
    ]
    trials = [
        t for t in trials
        if (t.num_workers, t.n_python_threads, t.num_envs, t.num_areas) not in completed
    ]
    if not trials:
        print("All trials already present in", CSV_PATH)
        return

    for i, trial in enumerate(trials, 1):
        print(f"[{i}/{len(trials)}] workers={trial.num_workers} "
              f"threads={trial.n_python_threads} envs={trial.num_envs} ...", flush=True)
        result = run_trial(trial)
        if result is None:
            print("  all workers failed, skipping")
            continue
        log_result(result)
        print(f"  {result['mean_seconds_per_iter']:.3f} s/iter/worker, "
              f"{result['total_timesteps_per_sec']:.0f} total timesteps/s")

    print(f"\nResults appended to {CSV_PATH}")


if __name__ == "__main__":
    main()
