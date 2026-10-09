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
import seaborn as sns
from sklearn.metrics import r2_score, mean_absolute_error
from matplotlib import pyplot as plt
import math


PATH = "results/aux_head_training_data.pt"

if not os.path.exists(PATH):
    try:
        model, model_config = load_model(
            "checkpoints/conv1d_fixed_lidar_try_2.pt")
        env = RoboRacerEnv(
            time_scale=100.0,
            file_name="TestUnityProject/Test speed/build.app",
            num_stacked_frames=model_config["num_stacked_lidar_frames"],
            no_graphics=True,
            num_areas=4,
            seed=0
        )

        data = do_rollout(
            env,
            model,
            num_steps=32768,
            select_keys=[*[("agents", key) for key in AUX_HEAD_KEYS], "hidden_layer"])
        data = data.reshape(-1)
        print(
            f"Saved {len(data)} steps to {PATH}, {data.bytes() / 1024 / 1024:.2f} MB")
        torch.save(data, PATH)
    except KeyboardInterrupt:
        pass
    finally:
        env.close()
else:
    torch.serialization.add_safe_globals(
        [tensordict._td.TensorDict, tensordict._reductions._make_td])
    data = torch.load(PATH)


x = data["hidden_layer"].numpy()
y = pd.DataFrame({
    key: data[("agents", key)].numpy().flatten() for key in AUX_HEAD_KEYS
})

train_split = 0.8

train_x = x[0:int(len(x) * train_split)]
train_y = y.iloc[0:int(len(y) * train_split)]

test_x = x[int(len(x) * train_split):]
test_y = y.iloc[int(len(y) * train_split):]

lr = LinearRegression()
lr.fit(train_x, train_y)

test_y_hat = lr.predict(test_x)

scores = pd.DataFrame({
    "target": y.columns,
    "r2_score": [r2_score(test_y.iloc[:, i], test_y_hat[:, i]) for i in range(len(y.columns))],
    "mae": [mean_absolute_error(test_y.iloc[:, i], test_y_hat[:, i]) for i in range(len(y.columns))],
    "target_stddev": [test_y.iloc[:, i].std() for i in range(len(y.columns))],
})

scores.to_csv("results/aux_head_regression_scores.csv", index=False)
