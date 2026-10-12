import tensordict

from environment import RoboRacerEnv
from model import load_model
import torch
from infer import do_rollout
import os
from utils import AUX_HEAD_KEYS
from sklearn.linear_model import LinearRegression
import pandas as pd
from sklearn.model_selection import train_test_split
# import seaborn as sns
from sklearn.metrics import r2_score, mean_absolute_error
from matplotlib import pyplot as plt
import math
import platform
from pathlib import Path
import tqdm


torch.set_num_threads(4)
PATH = "results/baseline_rollout.pt"

if not os.path.exists(PATH):
    is_mac = platform.system() == "Darwin"
    try:
        model, model_config, _, _ = load_model(
            "checkpoints/baseline_w0_s0/iteration_00600.pt")
        env = RoboRacerEnv(
            time_scale=100.0,
            file_name="TestUnityProject/Test speed/build.app" if is_mac else "linux_build/linux_build.x86_64",
            num_stacked_frames=model_config["num_stacked_lidar_frames"],
            no_graphics=True,
            num_areas=4,
            seed=0,
            worker_id=2000
        )

        data = do_rollout(
            env,
            model,
            num_steps=2048,
            select_keys=[*[("agents", key) for key in ["stacked_lidar", "steering_angle", "throttle", *AUX_HEAD_KEYS]]])
        data = data.reshape(-1)
        torch.save(data, PATH)
        print(
            f"Saved {len(data)} steps to {PATH}, {data.bytes() / 1024 / 1024:.2f} MB")
    except KeyboardInterrupt:
        pass
    finally:
        env.close()
else:
    torch.serialization.add_safe_globals(
        [tensordict._td.TensorDict, tensordict._reductions._make_td])
    data = torch.load(PATH)


def get_iter_name(i: int):
    return f"{i:05d}"



ITERATIONS = [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 150, 200, 250, 300, 350, 400, 450, 500, 550, 600]
MODEL_NAMES = os.listdir("checkpoints")

all_scores = []

trainings_to_do = [
    (get_iter_name(iteration), model_name) for iteration in ITERATIONS for model_name in MODEL_NAMES
]

for iter_name, model_name in tqdm.tqdm(trainings_to_do):

    weights_file_name = f"iteration_{iter_name}.pt"
    model_path = Path("checkpoints") / model_name / weights_file_name

    if not model_path.exists():
        print(
            f"Checkpoint for {model_name} at iteration {iter_name} not found.")
        continue

    #print(f"Found {model_name} with iteration {iter_name}")
    model, model_config, _, _ = load_model(model_path)

    # Do forward pass to get the aux head outputs
    with torch.no_grad():
        trunk_outputs = model.get_trunk_operator().forward(data).select("hidden_layer")

    x = trunk_outputs["hidden_layer"].numpy()
    y = pd.DataFrame({
        key: data[("agents", key)].numpy().flatten() for key in AUX_HEAD_KEYS
    })

    train_split = 0.8
    train_cuttoff_idx = int(len(x) * train_split)
    train_x, test_x = x[:train_cuttoff_idx], x[train_cuttoff_idx:]
    train_y, test_y = y.iloc[:train_cuttoff_idx], y.iloc[train_cuttoff_idx:]

    lr = LinearRegression(n_jobs=5)
    lr.fit(train_x, train_y)

    test_y_hat = lr.predict(test_x)

    scores = pd.DataFrame({
        "model_name": model_name,
        "target": y.columns,
        "iteration": int(iter_name),
        "r2_score": [r2_score(test_y.iloc[:, i], test_y_hat[:, i]) for i in range(len(y.columns))],
        "mae": [mean_absolute_error(test_y.iloc[:, i], test_y_hat[:, i]) for i in range(len(y.columns))],
        "target_stddev": [test_y.iloc[:, i].std() for i in range(len(y.columns))],
    })
    all_scores.append(scores)
    #print(scores)

scores = pd.concat(all_scores, ignore_index=True)
scores.to_csv("results/aux_head_regression_scores.csv", index=False)
