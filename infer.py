import torch

from environment import make_envs
from model import make_model
import tensordict as td
import matplotlib
import torch
import time
from matplotlib import pyplot as plt
from torchrl.envs.utils import ExplorationType, set_exploration_type

#curl -F "reqtype=fileupload" -F "time=24h" -F "fileToUpload=@Archiv.zip" https://litterbox.catbox.moe/resources/internals/api.php


class Visualiser:
    def __init__(self, num_envs: int, num_agents: int):
        self.num_envs = num_envs
        self.num_agents = num_agents
        self.fig, self.ax = plt.subplots(
            num_envs, num_agents, squeeze=False,
            figsize=(4 * num_agents, 4 * num_envs))
        self.images = [[None] * num_agents for _ in range(num_envs)]
        for e in range(num_envs):
            for a in range(num_agents):
                self.ax[e, a].set_title(f"env {e} agent {a}")
        self.fig.tight_layout()
        plt.show(block=False)

    def render_view(self, tensordict: td.TensorDict):
        # tag -1 is distance (see environment.py's LIDAR_BLOCK / model.py's TrunkModel)
        lidar = tensordict["agents", "stacked_lidar"][..., -1, :].cpu().numpy()
        n_frames, n_rays = lidar.shape[-2:]
        lidar = lidar.reshape(self.num_envs, self.num_agents, n_frames, n_rays)
        for e in range(self.num_envs):
            for a in range(self.num_agents):
                frame = lidar[e, a]  # (n_frames, n_rays)
                im = self.images[e][a]
                if im is None:
                    self.images[e][a] = self.ax[e, a].imshow(
                        frame, aspect="auto", vmin=0.0, vmax=1.0)
                else:
                    im.set_data(frame)

        # print("Lidar stats:")
        # print(lidar.shape)
        # print(f"\tmins: {lidar.min(axis=(-1, -2)).reshape(-1)}")
        # print(f"\tmaxs: {lidar.max(axis=(-1, -2)).reshape(-1)}")
        # print(f"\tmeans: {lidar.mean(axis=(-1, -2)).reshape(-1)}")

        if (tensordict["agents", "done"].float().sum() > 0.0):
            print(f"Done! {torch.argwhere(tensordict['agents', 'done'])}")
        self.fig.canvas.draw_idle()
        self.fig.canvas.flush_events()
        plt.pause(0.0001)


if __name__ == "__main__":
    checkpoint = torch.load("checkpoints/conv2d.pt", map_location="cpu")
    model_config = checkpoint["model_config"]

    num_envs = 2
    num_agents_per_env = 1
    env = make_envs(
        num_envs=num_envs,
        num_agents_per_env=num_agents_per_env,
        time_scale=0.1,
        num_stacked_frames=model_config["num_stacked_lidar_frames"])
    tensordict = env.reset()

    model = make_model(**model_config)
    model.load_state_dict(checkpoint["model"])

    visualiser = Visualiser(num_envs=num_envs, num_agents=num_agents_per_env)

    try:
        with torch.no_grad(), set_exploration_type(ExplorationType.DETERMINISTIC):
            while True:
                tensordict = env.step(model.get_policy_operator()(tensordict))
                tensordict = env.step_mdp(tensordict)
                visualiser.render_view(tensordict)
    except KeyboardInterrupt:
        pass
    finally:
        env.close()
