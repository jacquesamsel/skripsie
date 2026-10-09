from tensordict import TensorDict
from torch.nn.functional import smooth_l1_loss

from environment import CURVATURE_LOOKAHEAD_DISTANCES, track_curvature_key
from model import curvature_aux_name


def gen_aux_losses(td: TensorDict):
    aux_losses = TensorDict(dict(
        velocity_forward=smooth_l1_loss(
            td["aux", "velocity_forward"], td["agents", "velocity_forward"]),
        velocity_lateral=smooth_l1_loss(
            td["aux", "velocity_lateral"], td["agents", "velocity_lateral"]),
        **{
            curvature_aux_name(metres): smooth_l1_loss(
                td["aux",
                   curvature_aux_name(metres)],
                td[track_curvature_key(metres)])
            for metres in CURVATURE_LOOKAHEAD_DISTANCES
        },
        wheel_slip_lf_forward=smooth_l1_loss(
            td["aux", "wheel_slip_lf_forward"], td["agents", "wheel_slip_forward_front_left"]),
        wheel_slip_lf_lateral=smooth_l1_loss(
            td["aux", "wheel_slip_lf_lateral"], td["agents", "wheel_slip_lateral_front_left"]),
        wheel_slip_lr_forward=smooth_l1_loss(
            td["aux", "wheel_slip_lr_forward"], td["agents", "wheel_slip_forward_back_left"]),
        wheel_slip_lr_lateral=smooth_l1_loss(
            td["aux", "wheel_slip_lr_lateral"], td["agents", "wheel_slip_lateral_back_left"]),
        wheel_slip_rf_forward=smooth_l1_loss(
            td["aux", "wheel_slip_rf_forward"], td["agents", "wheel_slip_forward_front_right"]),
        wheel_slip_rf_lateral=smooth_l1_loss(
            td["aux", "wheel_slip_rf_lateral"], td["agents", "wheel_slip_lateral_front_right"]),
        wheel_slip_rr_forward=smooth_l1_loss(
            td["aux", "wheel_slip_rr_forward"], td["agents", "wheel_slip_forward_back_right"]),
        wheel_slip_rr_lateral=smooth_l1_loss(
            td["aux", "wheel_slip_rr_lateral"], td["agents", "wheel_slip_lateral_back_right"]),
        angular_velocity_y=smooth_l1_loss(
            td["aux", "angular_velocity_y"], td["agents", "angular_velocity_y"])
    ))
    return aux_losses
