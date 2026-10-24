import numpy as np
import jax
import jax.numpy as jnp
from flax import struct

from car_model import quat_to_mat


@struct.dataclass
class Track:
    seg: jax.Array              # (S, 2, 2) panel endpoints in the ground plane
    z: jax.Array                # (S, 2) [lo, hi] height span of each panel


@struct.dataclass
class CollisionParams:
    box_lo: jax.Array           # (3,) chassis box corner in body frame
    box_hi: jax.Array           # (3,)
    lidar_mount: jax.Array      # (3,) sensor position in body frame
    lidar_range: float          # m, also the value reported for a clear ray
