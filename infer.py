import csv
import math

import torch
from collections import deque

import tensordict as td
from matplotlib import pyplot as plt
from torchrl.envs.utils import ExplorationType, set_exploration_type
from torchrl.objectives.value import GAE

from environment import make_envs
from model import make_model

#curl -F "reqtype=fileupload" -F "time=24h" -F "fileToUpload=@Archiv.zip" https://litterbox.catbox.moe/resources/internals/api.php

# Must match train.py's gamma/lmbda -- not stored in the checkpoint, so kept in sync by hand.
GAMMA = 0.99
LMBDA = 0.95


def discounted_return(rewards: torch.Tensor, gamma: float) -> float:
    """Backward-accumulated discounted return from realised rewards (no bootstrap).

    The ground-truth counterpart to the GAE value_target: compare the two to see
    whether the critic's return estimate is actually calibrated to what happened.
    """
    g = 0.0
    for r in reversed(rewards.tolist()):
        g = r + gamma * g
    return g


class AgentPanel:
    """Lidar heatmap plus a reward/progress/return chart for one (env, agent)."""

    def __init__(self, lidar_ax, chart_ax, history_len: int):
        self.lidar_ax = lidar_ax
        self.chart_ax = chart_ax
        self.image = None
        self.history = {name: deque(maxlen=history_len)
                         for name in ("reward", "progress", "return", "discounted_return")}

        return_ax = chart_ax.twinx()
        self.return_ax = return_ax
        self.lines = {
            "reward": chart_ax.plot([], [], color="tab:blue", label="reward")[0],
            # raw, unshaped progress signal -- sanity check reward against it
            "progress": chart_ax.plot([], [], color="tab:green", label="progress", alpha=0.6)[0],
            # Both are step functions: held constant at the previous episode's
            # value until it crashes and the just-finished episode's own value
            # takes over. GAE value_target is the critic's bootstrapped estimate;
            # discounted_return is what actually happened -- compare the two to
            # judge whether the critic is calibrated.
            "return": return_ax.plot([], [], color="tab:orange", label="return (GAE)")[0],
            "discounted_return": return_ax.plot(
                [], [], color="tab:red", label="return (discounted)", linestyle="--")[0],
        }
        chart_ax.set_ylabel("reward / progress")
        return_ax.set_ylabel("return", color="tab:orange")
        lines = list(self.lines.values())
        chart_ax.legend(lines, [line.get_label() for line in lines], loc="upper left")

    def update(self, lidar_frame, reward: float, progress: float,
               episode_return: float, episode_discounted_return: float):
        if self.image is None:
            self.image = self.lidar_ax.imshow(
                lidar_frame, aspect="auto", vmin=0.0, vmax=1.0)
        else:
            self.image.set_data(lidar_frame)

        self.history["reward"].append(reward)
        self.history["progress"].append(progress)
        self.history["return"].append(episode_return)
        self.history["discounted_return"].append(episode_discounted_return)

        xs = range(len(self.history["reward"]))
        for name, line in self.lines.items():
            line.set_data(xs, self.history[name])
        self.chart_ax.set_xlim(0, max(len(xs) - 1, 1))
        self.chart_ax.relim()
        self.chart_ax.autoscale_view(scalex=False)
        self.return_ax.relim()
        self.return_ax.autoscale_view(scalex=False)


class Visualiser:
    def __init__(self, num_envs: int, num_agents: int, value_operator: td.nn.TensorDictModule,
                 history_len: int = 800, csv_path: str = "infer_stats.csv"):
        self.num_envs = num_envs
        self.num_agents = num_agents
        self.step = 0

        self.csv_file = open(csv_path, "w", newline="")
        self.csv_writer = csv.writer(self.csv_file)
        self.csv_writer.writerow([
            "step", "env", "agent", "reward", "progress",
            "return_gae", "return_discounted", "done"])
        self.fig, ax = plt.subplots(
            num_envs, num_agents * 2, squeeze=False,
            figsize=(4 * num_agents * 2, 4 * num_envs))
        self.panels = [
            [AgentPanel(ax[e, 2 * a], ax[e, 2 * a + 1], history_len)
             for a in range(num_agents)]
            for e in range(num_envs)
        ]
        for e in range(num_envs):
            for a in range(num_agents):
                ax[e, 2 * a].set_title(f"env {e} agent {a} lidar")
                ax[e, 2 * a + 1].set_title(f"env {e} agent {a} reward/return")
        self.fig.tight_layout()
        plt.show(block=False)

        # Computes the same GAE value_target used as the critic's training
        # target, so "return" here means the same thing it does during training
        # instead of a raw undiscounted sum of rewards.
        self.gae = GAE(
            gamma=GAMMA, lmbda=LMBDA, value_network=value_operator,
            average_gae=True, deactivate_vmap=True, time_dim=0,
        )
        self.gae.set_keys(
            reward=("agents", "reward"),
            done=("agents", "done"),
            terminated=("agents", "terminated"),
        )
        self.episode_steps = [[[] for _ in range(num_agents)] for _ in range(num_envs)]
        self.episode_return = [[math.nan] * num_agents for _ in range(num_envs)]
        self.episode_discounted_return = [[math.nan] * num_agents for _ in range(num_envs)]

    def render_view(self, tensordict: td.TensorDict):
        # make_envs() skips ParallelEnv (and its env-count batch dim) when
        # num_envs == 1, so the raw batch_size can be just [num_agents] instead
        # of [num_envs, num_agents] -- normalise it so tensordict[e, a] below works
        # regardless of how it got here.
        tensordict = tensordict.reshape(self.num_envs, self.num_agents)

        # tag -1 is distance (see environment.py's LIDAR_BLOCK / model.py's TrunkModel)
        lidar = tensordict["next", "agents", "stacked_lidar"][..., -1, :].cpu().numpy()
        n_frames, n_rays = lidar.shape[-2:]
        lidar = lidar.reshape(self.num_envs, self.num_agents, n_frames, n_rays)

        reward = tensordict["next", "agents", "reward"].squeeze(-1) \
            .reshape(self.num_envs, self.num_agents).cpu().numpy()
        # raw per-step progress, pre-reward-shaping (see environment.py's ComposeReward)
        progress = tensordict["next", "agents", "progress"].squeeze(-1) \
            .reshape(self.num_envs, self.num_agents).cpu().numpy()
        done = tensordict["next", "agents", "done"].squeeze(-1) \
            .reshape(self.num_envs, self.num_agents).cpu().numpy()

        for e in range(self.num_envs):
            for a in range(self.num_agents):
                self.episode_steps[e][a].append(tensordict[e, a])
                if done[e, a] > 0.0:
                    episode = torch.stack(self.episode_steps[e][a], dim=0)
                    with torch.no_grad():
                        self.gae(episode)
                    # value_target at the episode's first step estimates the
                    # return for the whole episode just finished.
                    self.episode_return[e][a] = episode["value_target"][0].item()
                    self.episode_discounted_return[e][a] = discounted_return(
                        episode["next", "agents", "reward"].squeeze(-1), GAMMA)
                    self.episode_steps[e][a] = []

                self.panels[e][a].update(
                    lidar[e, a], reward[e, a], progress[e, a],
                    self.episode_return[e][a], self.episode_discounted_return[e][a])

                self.csv_writer.writerow([
                    self.step, e, a, reward[e, a], progress[e, a],
                    self.episode_return[e][a], self.episode_discounted_return[e][a],
                    bool(done[e, a] > 0.0)])
        self.csv_file.flush()
        self.step += 1

        if done.sum() > 0.0:
            print(f"Done! {torch.argwhere(tensordict['next', 'agents', 'done'])}")
        self.fig.canvas.draw_idle()
        self.fig.canvas.flush_events()
        plt.pause(0.0001)

    def close(self):
        self.csv_file.close()


if __name__ == "__main__":
    checkpoint = torch.load("checkpoints/conv1d.pt", map_location="cpu")
    model_config = checkpoint["model_config"]

    num_envs = 1
    num_agents_per_env = 1
    env = make_envs(
        num_envs=num_envs,
        num_agents_per_env=num_agents_per_env,
        time_scale=0.1,
        num_stacked_frames=model_config["num_stacked_lidar_frames"])
    tensordict = env.reset()

    model = make_model(**model_config)
    model.load_state_dict(checkpoint["model"])

    visualiser = Visualiser(
        num_envs=num_envs, num_agents=num_agents_per_env,
        value_operator=model.get_value_operator())

    try:
        with torch.no_grad(), set_exploration_type(ExplorationType.DETERMINISTIC):
            while True:
                step_result = env.step(model.get_policy_operator()(tensordict))
                visualiser.render_view(step_result)
                tensordict = env.step_mdp(step_result)
    except KeyboardInterrupt:
        pass
    finally:
        env.close()
        visualiser.close()
