import torch

from environment import make_envs
from model import make_model
from torchrl.envs.utils import ExplorationType, set_exploration_type

if __name__ == "__main__":
    env = make_envs(1, 1, time_scale=1.0)
    tensordict = env.reset()

    model = make_model(
        num_stacked_lidar_frames=13,
        n_rays=101,
        lidar_conv="conv1d",
        ray_kernel=8,
        ray_stride=1)
    checkpoint = torch.load("checkpoints/no_aux.pt", map_location="cpu")
    model.load_state_dict(checkpoint["model"])

    with torch.no_grad(), set_exploration_type(ExplorationType.DETERMINISTIC):
        while True:
            tensordict = env.step(model.get_policy_operator()(tensordict))
            tensordict = env.step_mdp(tensordict)
