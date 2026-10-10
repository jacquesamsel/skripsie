import multiprocessing as mp
from concurrent.futures import ProcessPoolExecutor, as_completed
from dataclasses import dataclass
from pathlib import Path
import platform

from utils import CURVATURE_LOOKAHEAD_KEYS, CURVATURE_LOOKAHEAD_DISTANCES


def curvature_keys(lo, hi):
    return [k for k, d in zip(CURVATURE_LOOKAHEAD_KEYS, CURVATURE_LOOKAHEAD_DISTANCES)
            if lo < d <= hi]


HYPERPARAMETER_GROUPS = {
    "velocity_forward": ["velocity_forward"],
    "velocity_lateral": ["velocity_lateral"],
    "curvature_close": curvature_keys(0.0, 3.0),
    "curvature_medium": curvature_keys(3.0, 6.0),
    "curvature_far": curvature_keys(6.0, 8.0),
    "wheel_slip_front_forward": ["wheel_slip_forward_front_left", "wheel_slip_forward_front_right"],
    "wheel_slip_front_lateral": ["wheel_slip_lateral_front_left", "wheel_slip_lateral_front_right"],
    "wheel_slip_rear_forward": ["wheel_slip_forward_back_left", "wheel_slip_forward_back_right"],
    "wheel_slip_rear_lateral": ["wheel_slip_lateral_back_left", "wheel_slip_lateral_back_right"],
    "angular_velocity_y": ["angular_velocity_y"],
}

WEIGHT_VALUES = [0.1, 0.5, 1.0]
SEEDS = [0, 1, 2]
MAX_WORKERS = 4
RUNS_DIR = Path("run_done_flags")

NUM_ENVS = 8
MAX_WORKERS = 4

_SLOT = None


@dataclass(frozen=True)
class Trial:
    group: str           # "baseline" or a key of HYPERPARAMETER_GROUPS
    weight: float        # 0.0 for baseline
    seed: int

    @property
    def name(self):
        return f"{self.group}_w{self.weight:g}_s{self.seed}"

    @property
    def params(self):
        keys = HYPERPARAMETER_GROUPS.get(self.group, [])
        return {k: self.weight for k in keys}

    @property
    def done_marker(self):
        return RUNS_DIR / f"{self.name}.done"


def build_trials():
    for g, keys in HYPERPARAMETER_GROUPS.items():
        assert keys, f"Group '{g}' is empty - check your filters"

    trials = [Trial("baseline", 0.0, s) for s in SEEDS]
    trials += [Trial(g, w, s)
               for g in HYPERPARAMETER_GROUPS
               for w in WEIGHT_VALUES
               for s in SEEDS]
    # seed-major order: complete seed sets finish first
    trials.sort(key=lambda t: t.seed)
    return trials


def worker(trial: Trial):
    from environment import RoboRacerParallelEnvs
    from train import train
    from utils import gen_aux_weights_default_zero
    is_mac = platform.system() == "Darwin"
    if _SLOT is None:
        raise RuntimeError(
            "Worker slot not set. Use the 'mp' context to spawn workers.")

    env = RoboRacerParallelEnvs(
        file_name="TestUnityProject/Test speed/build.app" if is_mac else "linux_build/linux_build.x86_64",
        num_envs=NUM_ENVS,
        num_areas=6,
        num_stacked_frames=50,
        seed=trial.seed,
        start_worker_id=_SLOT * NUM_ENVS
    )
    try:
        train(
            env,
            aux_weights=gen_aux_weights_default_zero(trial.params),
            num_stacked_lidar_frames=50,
            name=trial.name,
            n_rays=101,
            ray_kernel=8,
            ray_stride=1,
            seed=trial.seed,
            lidar_conv="conv1d",
            max_iters=300
        )
    finally:
        env.close()
    trial.done_marker.touch()
    return trial.name


def _init_worker(counter):
    global _SLOT
    with counter.get_lock():
        _SLOT = counter.value % MAX_WORKERS
        counter.value += 1


def main():
    RUNS_DIR.mkdir(exist_ok=True)
    trials = build_trials()

    pending = [t for t in trials if not t.done_marker.exists()]
    print(f"{len(pending)}/{len(trials)} trials to run")

    ctx = mp.get_context("spawn")
    counter = ctx.Value('i', 0)
    with ProcessPoolExecutor(
        max_workers=MAX_WORKERS,
        mp_context=ctx,
        initializer=_init_worker,
        initargs=(counter,)
    ) as ex:
        futures = {ex.submit(worker, t): t for t in pending}
        for fut in as_completed(futures):
            t = futures[fut]
            try:
                print(f"done: {fut.result()}")
            except Exception as e:
                print(f"FAILED: {t.name}: {e!r}")


if __name__ == "__main__":
    main()
