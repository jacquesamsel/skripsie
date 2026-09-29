import torch

from environment import make_envs
from model import make_model
from torchrl.envs.utils import ExplorationType, set_exploration_type

if __name__ == "__main__":
    checkpoint = torch.load("checkpoints/no_aux.pt", map_location="cpu")
    model_config = checkpoint["model_config"]

    env = make_envs(
        num_envs=1,
        num_agents_per_env=1,
        time_scale=1.0,
        num_stacked_frames=model_config["num_stacked_lidar_frames"])
    tensordict = env.reset()

    model = make_model(**model_config)
    model.load_state_dict(checkpoint["model"])

    with torch.no_grad(), set_exploration_type(ExplorationType.DETERMINISTIC):
        while True:
            tensordict = env.step(model.get_policy_operator()(tensordict))
            tensordict = env.step_mdp(tensordict)
