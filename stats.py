import tensordict as td


def rollout_stats(rollout: td.TensorDict) -> dict[str, float]:
    """Summary stats for a collected rollout, used as the score a hyperparameter
    search reads off without a separate eval pass (see train.py).

    Reward and post-step observations live under "next" (the env.step()
    convention GAE/ClipPPOLoss also read their reward/done/terminated keys
    through). "terminated" is reported rather than "done" so collision_rate
    reflects actual crashes (Agent.EndEpisode() in F1TenthRacing.cs) and isn't
    inflated by ordinary MaxStep timeouts, which end episodes as "truncated".
    """
    return {
        "reward_mean": rollout["next", "agents", "reward"].mean().item(),
        "velocity_forward_mean": rollout["next", "agents", "velocity_forward"].mean().item(),
        "progress_mean": rollout["next", "agents", "progress"].mean().item(),
        "collision_rate": rollout["next", "agents", "terminated"].float().mean().item(),
    }
