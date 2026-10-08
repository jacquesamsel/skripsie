import math

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
