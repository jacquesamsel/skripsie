from environment import RoboRacerParallelEnvs, RoboRacerEnv
from model import load_model
from tqdm import tqdm
import torch


model, model_config, _, _ = load_model("checkpoints/baseline_w0_s0/iteration_00600.pt")

env = RoboRacerEnv(
    file_name=None,
    num_stacked_frames=model_config["num_stacked_lidar_frames"],
    num_areas=1,
    no_graphics=False,
    time_scale=1.0
)


tensordict = env.reset()

with torch.no_grad():
    for i in tqdm(range(1000)):
        tensordict = model.get_policy_operator()(tensordict)
        tensordict = env.step(tensordict)
        tensordict = env.step_mdp(tensordict)