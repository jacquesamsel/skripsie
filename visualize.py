import math
from collections import deque

import torch
from matplotlib import pyplot as plt


class LidarVisualiser:
    """Live grid of lidar distance heatmaps, one cell per agent/env.

    Assumes every render() gets the same batch shape -- the figure is built on
    the first call and reused verbatim after that.
    """

    # lidar distances are normalised, and the scale is fixed (rather than fitted
    # to each frame) so set_data() never has to renormalise -- which would both
    # cost a pass over the data and make colours flicker between frames
    VMIN = 0.0
    VMAX = 1.0

    def __init__(self):
        self._fig = None
        self._images = []
        self._background = None

    def render(self, lidar: torch.Tensor):
        """Draws one frame from a (..., stacked_timesteps, n_tags, n_rays) lidar tensor.

        The last tag is the distance channel, so only ``[..., :, -1, :]`` is
        shown; the leading batch dims are flattened and laid out as a square-ish
        grid of (stacked_timesteps x n_rays) heatmaps. The first call builds the
        figure, every later call only pushes new pixel data through the existing
        images and blits them, so nothing is re-laid-out per frame.
        """
        # (..., n_stacked_frames, n_rays) -> (n_cells, n_stacked_frames, n_rays)
        distances = lidar[..., :, -1, :]
        distances = distances.detach().cpu().numpy().reshape(
            -1, *distances.shape[-2:])

        if self._fig is None:
            self._build(distances)
        else:
            for image, cell in zip(self._images, distances):
                image.set_data(cell)

        self._blit()

    def close(self):
        plt.close(self._fig)
        self._fig = None

    def _build(self, distances):
        """Creates the figure on the first render (or the first after a close())."""
        self._images = []
        self._background = None

        n_cells = distances.shape[0]
        cols = math.ceil(math.sqrt(n_cells))
        rows = math.ceil(n_cells / cols)

        plt.ion()
        self._fig, axes = plt.subplots(
            rows, cols, figsize=(3 * cols, 2.5 * rows), squeeze=False)
        self._fig.canvas.manager.set_window_title("Lidar")

        for index, ax in enumerate(axes.flat):
            if index >= n_cells:
                ax.axis("off")
                continue
            self._images.append(ax.imshow(
                distances[index],
                cmap="viridis",
                vmin=self.VMIN,
                vmax=self.VMAX,
                aspect="auto",
                interpolation="nearest",
                # excluded from the normal draw so it isn't baked into the
                # blitting background
                animated=True,
            ))
            ax.set_xticks([])
            ax.set_yticks([])
            ax.set_title(str(index), fontsize=8)

        self._fig.tight_layout()
        self._fig.canvas.mpl_connect(
            "resize_event", lambda _event: setattr(self, "_background", None))
        self._fig.show()

    def _blit(self):
        canvas = self._fig.canvas

        if not getattr(canvas, "supports_blit", False):
            canvas.draw_idle()
            canvas.flush_events()
            return

        if self._background is None:
            canvas.draw()
            self._background = canvas.copy_from_bbox(self._fig.bbox)

        canvas.restore_region(self._background)
        for image in self._images:
            image.axes.draw_artist(image)
        canvas.blit(self._fig.bbox)
        canvas.flush_events()


class RewardVisualiser:
    """Live per-step reward against the discounted return accumulated so far.

    One stacked subplot per agent -- the leading batch dims of whatever is
    handed to render() are flattened, same as LidarVisualiser -- with the
    reward on the left axis, the discounted return on the right, and a
    semi-transparent vertical line at every step where the episode ended.

    The return is accumulated *forwards* from the start of the episode
    (G += gamma**t * r_t), which is the only direction available while the
    rollout is still being collected; it therefore reads as "discounted return
    earned so far", and the value sitting against each done line is that whole
    episode's discounted return (infer.py's discounted_return() of the same
    episode). It is reset to zero after each done.

    Like LidarVisualiser, the figure is built on the first render() and the
    batch shape is assumed constant from then on.

    In train.py's rollout loop:

        visualiser = RewardVisualiser(gamma=gamma)
        ...
        tensordict = env.step(model.get_policy_operator()(tensordict))
        visualiser.render(tensordict["next", "agents", "reward"],
                          tensordict["next", "agents", "done"])

    or as infer.py's on_step hook:

        visualiser = RewardVisualiser(gamma=GAMMA)
        run_rollout(model, env, tensordict, num_steps=1000,
                    on_step=lambda step: visualiser.render(
                        step["next", "agents", "reward"],
                        step["next", "agents", "done"]))
    """

    REWARD_COLOUR = "tab:blue"
    RETURN_COLOUR = "tab:red"

    def __init__(self, gamma: float, window: int = 500, draw_every: int = 1):
        """window = steps kept on screen; draw_every > 1 redraws less often,
        which matters in train.py where the env runs at a high time_scale and a
        redraw per frame would dominate the rollout."""
        self._gamma = gamma
        self._window = window
        self._draw_every = draw_every

        self._fig = None
        self._axes = []
        self._return_axes = []
        self._reward_lines = []
        self._return_lines = []

        # x values are absolute step counts, so the plotted window scrolls
        # rather than resetting; the deques drop whatever falls off the left
        self._steps = deque(maxlen=window)
        self._rewards = []
        self._returns = []

        # done lines are created lazily in _draw() (render() may be called
        # before the figure exists) and removed once they scroll out of window
        self._pending_dones = []
        self._done_artists = []

        self._episode_step = []
        self._episode_return = []
        self._step_count = 0

    def render(self, reward: torch.Tensor, done: torch.Tensor):
        """Adds one step to the chart from a (..., 1) reward and (..., 1) done.

        Both come straight out of the stepped tensordict -- i.e.
        ``td["next", "agents", "reward"]`` and ``td["next", "agents", "done"]``
        -- and their leading dims (env, agent) are flattened to one line each.
        """
        rewards = reward.detach().reshape(-1).float().cpu().tolist()
        dones = done.detach().reshape(-1).bool().cpu().tolist()

        if self._fig is None:
            self._build(len(rewards))

        self._steps.append(self._step_count)
        for index, (r, is_done) in enumerate(zip(rewards, dones)):
            self._episode_return[index] += \
                self._gamma ** self._episode_step[index] * r
            self._rewards[index].append(r)
            self._returns[index].append(self._episode_return[index])

            if is_done:
                self._pending_dones[index].append(self._step_count)
                self._episode_return[index] = 0.0
                self._episode_step[index] = 0
            else:
                self._episode_step[index] += 1

        self._step_count += 1

        if self._step_count % self._draw_every == 0:
            self._draw()

    def close(self):
        plt.close(self._fig)
        self._fig = None

    def _build(self, n_cells):
        """Creates the figure on the first render (or the first after a close())."""
        self._rewards = [deque(maxlen=self._window) for _ in range(n_cells)]
        self._returns = [deque(maxlen=self._window) for _ in range(n_cells)]
        self._pending_dones = [[] for _ in range(n_cells)]
        self._done_artists = [[] for _ in range(n_cells)]
        self._episode_step = [0] * n_cells
        self._episode_return = [0.0] * n_cells

        plt.ion()
        self._fig, axes = plt.subplots(
            n_cells, 1, figsize=(10, 2.5 * n_cells), squeeze=False, sharex=True)
        self._fig.canvas.manager.set_window_title("Reward")

        self._axes = list(axes.flat)
        self._return_axes = []
        self._reward_lines = []
        self._return_lines = []

        for index, ax in enumerate(self._axes):
            return_ax = ax.twinx()
            self._return_axes.append(return_ax)

            self._reward_lines.append(ax.plot(
                [], [], color=self.REWARD_COLOUR, linewidth=1,
                label="reward")[0])
            self._return_lines.append(return_ax.plot(
                [], [], color=self.RETURN_COLOUR, linewidth=1.5,
                label="discounted return")[0])

            ax.set_ylabel("reward", color=self.REWARD_COLOUR)
            ax.tick_params(axis="y", labelcolor=self.REWARD_COLOUR)
            return_ax.set_ylabel("discounted return",
                                 color=self.RETURN_COLOUR)
            return_ax.tick_params(axis="y", labelcolor=self.RETURN_COLOUR)
            ax.set_title(str(index), fontsize=8)
            ax.grid(alpha=0.2)

        self._axes[-1].set_xlabel("step")
        # one legend for the whole figure -- every cell plots the same two series
        self._fig.legend(
            handles=[self._reward_lines[0], self._return_lines[0]],
            loc="upper right", fontsize=8)
        self._fig.tight_layout()
        self._fig.show()

    def _draw(self):
        steps = list(self._steps)

        for index, ax in enumerate(self._axes):
            rewards = list(self._rewards[index])
            returns = list(self._returns[index])

            self._reward_lines[index].set_data(steps, rewards)
            self._return_lines[index].set_data(steps, returns)

            for x in self._pending_dones[index]:
                self._done_artists[index].append((x, ax.axvline(
                    x, color="black", alpha=0.25, linewidth=1)))
            self._pending_dones[index].clear()

            # drop the lines that have scrolled off the left of the window,
            # otherwise they accumulate on the axes forever
            kept = []
            for x, artist in self._done_artists[index]:
                if x < steps[0]:
                    artist.remove()
                else:
                    kept.append((x, artist))
            self._done_artists[index] = kept

            ax.set_xlim(steps[0], max(steps[-1], steps[0] + 1))
            self._fit_y(ax, rewards)
            self._fit_y(self._return_axes[index], returns)

        self._fig.canvas.draw_idle()
        self._fig.canvas.flush_events()

    @staticmethod
    def _fit_y(ax, values):
        """Rescales one y axis to its own series, since the reward and the
        return live on wildly different scales (the return is roughly the
        reward times 1/(1-gamma))."""
        low, high = min(values), max(values)
        if low == high:
            low, high = low - 0.5, high + 0.5
        pad = 0.05 * (high - low)
        ax.set_ylim(low - pad, high + pad)
