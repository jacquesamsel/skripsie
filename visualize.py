import math

import matplotlib.pyplot as plt
from matplotlib.collections import LineCollection
from matplotlib.colors import BoundaryNorm, ListedColormap
import torch


class LidarAndOccupancyGridVisualisation:
    def __init__(self, occupancy_grid_shape: torch.Size = None, lidar_shape: torch.Size = None,
                 velocity_shape: torch.Size = None, grid_cell_size=0.1, lidar_scale=20.0, lidar_fov=270.0,
                 velocity_scale=1.0):
        num_agents_by_source = {}
        if occupancy_grid_shape is not None:
            n, self.num_object_categories, self.grid_height, self.grid_width = occupancy_grid_shape
            num_agents_by_source["occupancy_grid_shape"] = n
        if lidar_shape is not None:
            n, _, self.num_lidar_points = lidar_shape
            num_agents_by_source["lidar_shape"] = n
        if velocity_shape is not None:
            n, _ = velocity_shape
            num_agents_by_source["velocity_shape"] = n

        if not num_agents_by_source:
            raise ValueError(
                "At least one of occupancy_grid_shape, lidar_shape, velocity_shape must be provided")
        if len(set(num_agents_by_source.values())) > 1:
            raise ValueError(
                f"Mismatched agent counts across provided shapes: {num_agents_by_source}")
        self.num_agents = next(iter(num_agents_by_source.values()))

        self.show_grid = occupancy_grid_shape is not None
        self.show_lidar = lidar_shape is not None
        self.show_velocity = velocity_shape is not None

        self.grid_cell_size = grid_cell_size
        self.lidar_scale = lidar_scale
        self.lidar_fov = lidar_fov
        self.velocity_scale = velocity_scale

        if self.show_grid:
            # empty cells (-1) render white, categories get distinct colors
            category_colors = plt.cm.get_cmap("tab10")(range(self.num_object_categories))
            cmap = ListedColormap(["white", *category_colors])
            boundaries = [i - 0.5 for i in range(-1, self.num_object_categories + 1)]
            self.norm = BoundaryNorm(boundaries, cmap.N)
            self.cmap = cmap

        ncols = math.ceil(math.sqrt(self.num_agents))
        nrows = math.ceil(self.num_agents / ncols)
        self.fig, axes = plt.subplots(nrows, ncols, squeeze=False, figsize=(4 * ncols, 4 * nrows))
        self.axes = axes.flatten()

        if self.show_grid:
            world_width = self.grid_width * self.grid_cell_size
            world_height = self.grid_height * self.grid_cell_size
            extent = (0, world_width, 0, world_height)
            # lidar source sits at the center of the grid, facing right (angle 0 = +x),
            # with rays fanned symmetrically across the FOV around that direction
            self.lidar_origin = (world_width / 2.0, world_height / 2.0)
        else:
            self.lidar_origin = (0.0, 0.0)
            # no grid to size the plot against — fall back to whichever other
            # scale is available so rays/arrows stay in view
            half_extent = self.lidar_scale if self.show_lidar else self.velocity_scale * 5

        if self.show_lidar:
            half_fov = math.radians(self.lidar_fov) / 2.0
            angles = torch.linspace(-half_fov, half_fov, self.num_lidar_points)
            self.lidar_cos = torch.cos(angles)
            self.lidar_sin = torch.sin(angles)

        self.images = []
        self.lidar_collections = []
        self.velocity_quivers = []
        for i, ax in enumerate(self.axes):
            if i >= self.num_agents:
                ax.axis("off")
                continue

            if self.show_grid:
                image = ax.imshow(
                    torch.full((self.grid_height, self.grid_width), -1),
                    cmap=self.cmap,
                    norm=self.norm,
                    origin="lower",
                    extent=extent,
                    interpolation="nearest",
                )
                self.images.append(image)

            if self.show_lidar:
                lidar_collection = LineCollection([], colors="red", linewidths=0.8, zorder=3)
                ax.add_collection(lidar_collection)
                self.lidar_collections.append(lidar_collection)

            if self.show_velocity:
                # forward (0th entry) plotted along +x, lateral (1st entry) along +y —
                # same convention as the lidar rays (angle 0 = +x = forward)
                velocity_quiver = ax.quiver(
                    *self.lidar_origin, 0, 0,
                    angles="xy", scale_units="xy", scale=1,
                    color="blue", zorder=4,
                )
                self.velocity_quivers.append(velocity_quiver)

            ax.set_title(f"Agent {i}")
            ax.set_aspect("equal")
            if self.show_grid:
                ax.set_xticks([j * self.grid_cell_size for j in range(self.grid_width + 1)], minor=True)
                ax.set_yticks([j * self.grid_cell_size for j in range(self.grid_height + 1)], minor=True)
                ax.grid(which="minor", color="gray", linewidth=0.5)
            else:
                ax.set_xlim(-half_extent, half_extent)
                ax.set_ylim(-half_extent, half_extent)
            ax.tick_params(which="both", bottom=False, left=False, labelbottom=False, labelleft=False)

        self.fig.tight_layout()

    def update(self, occupancy_grid: torch.Tensor = None, lidar: torch.Tensor = None, velocity: torch.Tensor = None):
        if (occupancy_grid is not None) != self.show_grid:
            raise ValueError(
                "occupancy_grid must be given iff occupancy_grid_shape was given at construction")
        if (lidar is not None) != self.show_lidar:
            raise ValueError("lidar must be given iff lidar_shape was given at construction")
        if (velocity is not None) != self.show_velocity:
            raise ValueError("velocity must be given iff velocity_shape was given at construction")

        if self.show_grid:
            # (num_agents, grid_height, grid_width)
            occupancy_argmax = torch.argmax(occupancy_grid, dim=1)
            max_vals = torch.amax(occupancy_grid, dim=1)
            is_empty = max_vals == 0
            occupancy_argmax[is_empty] = -1

            for agent_idx, image in enumerate(self.images):
                image.set_data(occupancy_argmax[agent_idx].cpu().numpy())

        if self.show_lidar:
            # per ray block: [T_1..T_n, Miss, Distance] -> Miss/Distance are always the last two channels
            # (num_agents, num_lidar_points)
            misses = lidar[:, -2, :].cpu()
            distances = lidar[:, -1, :].cpu() * self.lidar_scale
            cx, cy = self.lidar_origin

            for agent_idx, lidar_collection in enumerate(self.lidar_collections):
                hit_mask = misses[agent_idx] == 0
                d = distances[agent_idx][hit_mask]
                end_x = cx + d * self.lidar_cos[hit_mask]
                end_y = cy + d * self.lidar_sin[hit_mask]
                segments = [[(cx, cy), (float(ex), float(ey))] for ex, ey in zip(end_x, end_y)]
                lidar_collection.set_segments(segments)

        if self.show_velocity:
            # (num_agents, 2) -> forward (0th entry) along +x, lateral (1st entry) along +y
            velocity = velocity.cpu() * self.velocity_scale
            for agent_idx, velocity_quiver in enumerate(self.velocity_quivers):
                forward, lateral = velocity[agent_idx]
                velocity_quiver.set_UVC(float(forward), float(lateral))

        self.fig.canvas.draw_idle()
        self.fig.canvas.flush_events()
        plt.pause(0.001)

    def show(self, block=False):
        plt.show(block=block)
