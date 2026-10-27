import torch
from tqdm import tqdm
from environment import RoboRacerEnv
from model import advance_recurrent_state, initial_recurrent_state, load_model, step_operator


MODELS = ["curvature_close_w1_s1", "baseline_w0_s2"]
models = [load_model(
    f"checkpoints/{model}/iteration_00600.pt")[0] for model in MODELS]

env = RoboRacerEnv(
    file_name=None,
    num_stacked_frames=50,
    num_areas=len(models),
    no_graphics=False,
    time_scale=10.0,
)

tensordict = env.reset()
# One area per model, so each gets its own (batch_size=1) recurrent state to carry
# across steps.
recurrent_states = [
    initial_recurrent_state(model, torch.Size([1])) for model in models]

trajectories = [[] for model in models]

with torch.no_grad(), torch.inference_mode():
    for i in tqdm(range(1000)):
        # Step each model on its own area slice, then stitch the per-agent
        # actions back into one batch before stepping the shared env.
        agent_steps = [
            step_operator(
                model.get_policy_operator(),
                tensordict[agent_idx:agent_idx + 1],
                recurrent_states[agent_idx],
            )
            for agent_idx, model in enumerate(models)
        ]
        tensordict = torch.cat(agent_steps, dim=0)
        tensordict = env.step(tensordict)
        for agent_idx in range(len(models)):
            trajectories[agent_idx].append(
                tensordict[agent_idx:agent_idx + 1].exclude(
                    ("agents", "lidar"), ("agents", "stacked_lidar"),
                    ("next", "agents", "lidar"), ("next", "agents", "stacked_lidar"),
                )
            )
        recurrent_states = [
            advance_recurrent_state(
                recurrent_states[agent_idx], tensordict[agent_idx:agent_idx + 1])
            for agent_idx in range(len(models))
        ]
        tensordict = env.step_mdp(tensordict)

for i, trajectory in enumerate(trajectories):
    trajectory = torch.cat(trajectory, dim=0)
    torch.save(trajectory, f"results/trajectory_{MODELS[i]}.pt")
