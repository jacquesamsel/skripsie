from environment import RoboRacerEnv
from model import make_model
import torch
from torch.optim import Adam

from utils import gen_aux_losses


def train_aux_head(
):

    checkpoint = torch.load(
        "checkpoints/conv1d_fixed_lidar_try_2.pt", map_location="cpu")
    env = RoboRacerEnv(
        file_name="TestUnityProject/Test speed/build.app",
        num_stacked_frames=checkpoint["model_config"]["num_stacked_lidar_frames"],
        no_graphics=False,
        seed=1,
        num_areas=1,
        worker_id=0
    )
    model = make_model(
        **checkpoint["model_config"]
    )
    model.load_state_dict(checkpoint["model"])

    # Freeze the trunk of the model
    model.get_trunk_operator().requires_grad_(False)

    optimizer = Adam(model.get_aux_head().parameters(), lr=1e-4)

    td = env.reset()
    while True:
        # Do a rollout
        for i in range(512):
            td = model.forward(td)
            td = env.step(td)
            aux_losses = gen_aux_losses(td)
            loss = sum(aux_losses.values())
            loss.backward()
            optimizer.step()
            optimizer.zero_grad()
            print(f"Step {i}, loss: {loss.item()}")


if __name__ == "__main__":
    train_aux_head()
