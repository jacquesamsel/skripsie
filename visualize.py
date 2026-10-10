import math
from collections import deque
from collections.abc import Sequence

import numpy as np
import torch
from matplotlib import pyplot as plt
from matplotlib.colors import to_rgb
from matplotlib.patches import Patch


def _blit_frame(fig, background, artists):
    """Pushes already-updated artists onto the unchanged background.

    Returns the background to hand back next frame: the first call -- and the
    first after a resize, which drops it to None -- has to draw the whole
    figure once to capture it. Backends that cannot blit (the inline ones in a
    notebook, say) get a plain redraw instead, which is slower but correct.
    """
    canvas = fig.canvas

    if not getattr(canvas, "supports_blit", False):
        canvas.draw_idle()
        canvas.flush_events()
        return background

    if background is None:
        canvas.draw()
        background = canvas.copy_from_bbox(fig.bbox)

    canvas.restore_region(background)
    for artist in artists:
        artist.axes.draw_artist(artist)
    canvas.blit(fig.bbox)
    canvas.flush_events()
    return background


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
        """Draws one frame from a (..., stacked_timesteps, n_rays) lidar tensor.

        The tensor is distances already -- RoboRacerEnv drops the tag and miss
        channels before stacking -- so the leading batch dims are flattened and
        laid out as a square-ish grid of (stacked_timesteps x n_rays) heatmaps.
        The first call builds the figure, every later call only pushes new pixel
        data through the existing images and blits them, so nothing is
        re-laid-out per frame.
        """
        # (..., n_stacked_frames, n_rays) -> (n_cells, n_stacked_frames, n_rays)
        distances = lidar.detach().cpu().numpy().reshape(
            -1, *lidar.shape[-2:])

        if self._fig is None:
            self._build(distances)
        else:
            for image, cell in zip(self._images, distances):
                image.set_data(cell)

        self._background = _blit_frame(
            self._fig, self._background, self._images)

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
            rows, cols, figsize=(6 * cols, 5 * rows), squeeze=False)
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
            ax.set_title(f"Lidar of agent {index}", fontsize=8)

        self._fig.tight_layout()
        self._fig.canvas.mpl_connect(
            "resize_event", lambda _event: setattr(self, "_background", None))
        self._fig.show()


class OccupancyGridVisualiser:
    """Live grid of occupancy-grid images, one cell per agent/env.

    Takes the (..., n_types, breadth, height) one-hot occupancy grid Unity's
    GridSensor produces -- one channel per detectable tag, Walls and Player on
    the RoboRacer car -- and draws each type in its own colour over a blank
    background where the sensor found nothing. The channel ordering is the
    sensor's m_DetectableTags order, so pass type_names in that same order to
    label the legend.

    Same contract as LidarVisualiser: the leading batch dims (env, area) are
    flattened to one subplot each, the figure is built on the first render()
    and the batch shape is assumed constant from then on.

    As infer.py's rollout hook:

        visualiser = OccupancyGridVisualiser(type_names=["walls", "car"])
        ...
        visualiser.render(tensordict["agents", "occupancy_grid"])
    """

    # one per object type, in channel order; cycled if a sensor ever carries
    # more tags than there are colours here
    COLOURS = (
        "tab:blue", "tab:red", "tab:green", "tab:orange", "tab:purple",
        "tab:brown", "tab:pink", "tab:olive", "tab:cyan",
    )
    EMPTY_COLOUR = "white"

    def __init__(self, type_names: Sequence[str] | None = None):
        """type_names labels the legend, one per channel; defaults to the
        channel index when the tags aren't known."""
        self._type_names = None if type_names is None else list(type_names)

        self._fig = None
        self._images = []
        self._background = None

    def render(self, occupancy_grid: torch.Tensor):
        """Draws one frame from a (..., n_types, breadth, height) grid tensor.

        The first call builds the figure, every later call only pushes new
        pixel data through the existing images and blits them, so nothing is
        re-laid-out per frame.
        """
        # (..., n_types, breadth, height) -> (n_cells, n_types, breadth, height)
        grid = occupancy_grid.detach().float().cpu().numpy().reshape(
            -1, *occupancy_grid.shape[-3:])
        cells = self._to_rgb(grid)

        if self._fig is None:
            self._build(cells, n_types=grid.shape[1])
        else:
            for image, cell in zip(self._images, cells):
                image.set_data(cell)

        self._background = _blit_frame(
            self._fig, self._background, self._images)

    def close(self):
        plt.close(self._fig)
        self._fig = None

    def _to_rgb(self, grid):
        """(n_cells, n_types, breadth, height) -> (n_cells, height, breadth, 3).

        Each type's colour is blended over the empty background weighted by its
        own channel, rather than the channels being argmaxed: a strictly
        one-hot cell comes out as that type's flat colour either way, but this
        also shows a cell two types share (or one the sensor only partly
        filled) shaded between the colours involved instead of rounding it to
        whichever channel happened to win.

        Mapping to RGB here rather than handing imshow a label image and a
        ListedColormap keeps the per-frame work to one set_data() of finished
        pixels, and leaves the "no detection" background a colour of its own
        instead of a palette entry that a real type could be confused with.

        The axes are swapped on the way out, and _build draws with
        origin="lower", so the sensor's forward axis runs up the image and its
        lateral axis across it -- i.e. the car sits at the bottom centre
        looking up the page, the way its gizmo shows in the editor.
        """
        palette = np.array(
            [to_rgb(self.COLOURS[index % len(self.COLOURS)])
             for index in range(grid.shape[1])])

        # (n_cells, breadth, height, n_types), so the matmul below contracts
        # the channels against the palette
        weights = np.moveaxis(grid, 1, -1)
        occupied = np.clip(weights.sum(axis=-1, keepdims=True), 0.0, 1.0)
        rgb = weights @ palette + (1.0 - occupied) * to_rgb(self.EMPTY_COLOUR)

        # channels summing past 1 (overlapping types) would otherwise push the
        # blend out of range, which imshow reads as saturated rather than clipping
        return np.clip(rgb, 0.0, 1.0).transpose(0, 2, 1, 3)

    def _build(self, cells, n_types):
        """Creates the figure on the first render (or the first after a close())."""
        self._images = []
        self._background = None

        n_cells = cells.shape[0]
        cols = math.ceil(math.sqrt(n_cells))
        rows = math.ceil(n_cells / cols)

        plt.ion()
        self._fig, axes = plt.subplots(
            rows, cols, figsize=(4 * cols, 4 * rows), squeeze=False)
        self._fig.canvas.manager.set_window_title("Occupancy grid")

        for index, ax in enumerate(axes.flat):
            if index >= n_cells:
                ax.axis("off")
                continue
            self._images.append(ax.imshow(
                cells[index],
                origin="lower",
                aspect="equal",
                interpolation="nearest",
                # excluded from the normal draw so it isn't baked into the
                # blitting background
                animated=True,
            ))
            ax.set_xticks([])
            ax.set_yticks([])
            ax.set_title(f"Occupancy grid of agent {index}", fontsize=8)

        self._fig.legend(
            handles=[
                Patch(
                    facecolor=self.COLOURS[index % len(self.COLOURS)],
                    label=self._type_name(index))
                for index in range(n_types)],
            loc="upper right", fontsize=8)
        self._fig.tight_layout()
        self._fig.canvas.mpl_connect(
            "resize_event", lambda _event: setattr(self, "_background", None))
        self._fig.show()

    def _type_name(self, index):
        if self._type_names is None or index >= len(self._type_names):
            return f"type {index}"
        return self._type_names[index]


class RewardVisualiser:
    """Live per-step reward against each finished episode's discounted return.

    One stacked subplot per agent -- the leading batch dims of whatever is
    handed to render() are flattened, same as LidarVisualiser -- with the
    reward on the left axis, the discounted return on the right, and a
    semi-transparent vertical line at every step where the episode ended.

    The return plotted is the return-to-go, G_t = sum_k>=t gamma^(k-t) * r_k,
    which cannot be known until the episode is over: the rewards are buffered
    and the whole episode's curve is back-filled in one go when its done
    arrives (infer.py's discounted_return() is this same backward
    accumulation, and equals the first point of each back-filled segment).
    So the right axis stays blank over the episode currently in progress and
    fills in behind it, one episode at a time.

    Two things that follows from using realised rewards and no bootstrap, as
    infer.py:discounted_return() also does: the return decays toward zero
    approaching each done, and an episode that ended on a MaxStep truncation
    rather than a crash is understated near its end, because the rewards it
    would have gone on earning are not counted.

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
        which matters wherever the env runs at a high time_scale (train.py,
        test.py) and a redraw per frame would dominate the step loop."""
        self._gamma = gamma
        self._window = window
        self._draw_every = draw_every

        self._fig = None
        self._axes = []
        self._return_axes = []
        self._reward_lines = []
        self._return_lines = []

        # the reward series is contiguous, so its x values are implied by
        # _step_count and the deque length rather than stored
        self._rewards = []

        # the return series lags: it only gains points when an episode ends,
        # so it carries its own x values
        self._return_x = []
        self._return_y = []

        # rewards of the episode in progress, and the step its first one
        # landed on, held until the done that lets them be back-filled
        self._episode_rewards = []
        self._episode_start = []

        # done lines are created lazily in _draw() (render() may be called
        # before the figure exists) and removed once they scroll out of window
        self._pending_dones = []
        self._done_artists = []

        self._step_count = 0

    def render(self, reward: torch.Tensor, done: torch.Tensor):
        """Adds one step to the chart from a (..., 1) reward and (..., 1) done.

        Both come straight out of the stepped tensordict -- i.e.
        ``td["next", "agents", "reward"]`` and ``td["next", "agents", "done"]``
        -- and their leading dims (env, area) are flattened to one cell each.
        """
        rewards = reward.detach().reshape(-1).float().cpu().tolist()
        dones = done.detach().reshape(-1).bool().cpu().tolist()

        if self._fig is None:
            self._build(len(rewards))

        for index, (r, is_done) in enumerate(zip(rewards, dones)):
            self._rewards[index].append(r)
            self._episode_rewards[index].append(r)
            if is_done:
                self._pending_dones[index].append(self._step_count)
                self._backfill(index)

        self._step_count += 1

        if self._step_count % self._draw_every == 0:
            self._draw()

    def close(self):
        plt.close(self._fig)
        self._fig = None

    def _backfill(self, index):
        """Turns the episode that just ended into its return-to-go curve.

        Accumulating backwards (G = r + gamma * G) gives every step the return
        from that step onwards in one pass. An episode only half-seen -- the
        one already running when the visualiser started, or when the window
        has scrolled past its beginning -- is still exact for the steps that
        were seen, since return-to-go depends on the future alone.
        """
        returns = []
        g = 0.0
        for r in reversed(self._episode_rewards[index]):
            g = r + self._gamma * g
            returns.append(g)

        if self._return_x[index]:
            # break the line here: without a gap it runs from this episode's
            # last return-to-go straight up to the next episode's first, which
            # reads as a steep climb rather than the episode boundary it is
            self._return_x[index].append(self._episode_start[index] - 0.5)
            self._return_y[index].append(math.nan)

        step = self._episode_start[index]
        for value in reversed(returns):
            self._return_x[index].append(step)
            self._return_y[index].append(value)
            step += 1

        self._episode_rewards[index].clear()
        self._episode_start[index] = self._step_count + 1

    def _build(self, n_cells):
        """Creates the figure on the first render (or the first after a close())."""
        self._rewards = [deque(maxlen=self._window) for _ in range(n_cells)]
        self._return_x = [deque(maxlen=self._window) for _ in range(n_cells)]
        self._return_y = [deque(maxlen=self._window) for _ in range(n_cells)]
        self._episode_rewards = [[] for _ in range(n_cells)]
        self._episode_start = [self._step_count] * n_cells
        self._pending_dones = [[] for _ in range(n_cells)]
        self._done_artists = [[] for _ in range(n_cells)]

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
            return_ax.set_ylabel("discounted return", color=self.RETURN_COLOUR)
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
        # the reward deques all grow together, so one span of x serves them all
        start = self._step_count - len(self._rewards[0]) + 1
        steps = range(start, self._step_count + 1)

        for index, ax in enumerate(self._axes):
            rewards = list(self._rewards[index])
            self._reward_lines[index].set_data(steps, rewards)
            self._return_lines[index].set_data(
                list(self._return_x[index]), list(self._return_y[index]))

            for x in self._pending_dones[index]:
                self._done_artists[index].append((x, ax.axvline(
                    x, color="black", alpha=0.25, linewidth=1)))
            self._pending_dones[index].clear()

            # drop the lines that have scrolled off the left of the window,
            # otherwise they accumulate on the axes forever
            kept = []
            for x, artist in self._done_artists[index]:
                if x < start:
                    artist.remove()
                else:
                    kept.append((x, artist))
            self._done_artists[index] = kept

            ax.set_xlim(start, max(self._step_count, start + 1))
            self._fit_y(ax, rewards)
            # empty until this cell's first episode ends
            self._fit_y(self._return_axes[index], self._return_y[index])

        self._fig.canvas.draw_idle()
        self._fig.canvas.flush_events()

    @staticmethod
    def _fit_y(ax, values):
        """Rescales one y axis to its own series, since the reward and the
        return live on wildly different scales (over an episode long against
        gamma, the return approaches the reward times 1/(1-gamma))."""
        values = [value for value in values if not math.isnan(value)]
        if not values:
            return
        low, high = min(values), max(values)
        if low == high:
            low, high = low - 0.5, high + 0.5
        pad = 0.05 * (high - low)
        ax.set_ylim(low - pad, high + pad)
