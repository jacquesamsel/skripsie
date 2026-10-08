import tensordict as td

from environment import REWARD_TERM_KEYS


def rollout_stats(rollout: td.TensorDict) -> dict[str, float]:
    """Summary stats for a collected rollout, used as the score a hyperparameter
    search reads off without a separate eval pass (see train.py).

    Reward and post-step observations live under "next" (the env.step()
    convention GAE/ClipPPOLoss also read their reward/done/terminated keys
    through).

    Three groups come back:

    - "reward_mean" and one "reward_<term>_mean" per entry of REWARD_TERM_KEYS.
      The terms are the reward broken into what it was made of, in reward units,
      and they sum to reward_mean.
    - "progress_mean" and "velocity_forward_mean": the raw quantities two of
      those terms are computed from, in metres per step and m/s. Useful
      precisely because they do not move when a weight changes.
    - two collision rates, over different denominators. See below.
    """
    next_td = rollout["next"]
    terminated = next_td["agents", "terminated"]
    # Crashes are the only terminations; a timeout or a track regeneration
    # interrupts the episode instead, and Car.cs reports those as truncations.
    crashes = terminated.sum()
    episodes = next_td["agents", "done"].sum()

    stats = {
        "reward_mean": next_td["agents", "reward"].mean().item(),
        "velocity_forward_mean": next_td["agents", "velocity_forward"].mean().item(),
        "progress_mean": next_td["agents", "progress"].mean().item(),
        # Per step: the chance that any given step is a car hitting a wall. Scales
        # with how long episodes last, so it moves when episodeTimeoutSeconds does.
        "collision_rate_per_step": terminated.float().mean().item(),
        # Per episode: the share of the episodes that ended in this rollout which
        # ended in a crash rather than in a timeout. The one to read as "how often
        # does it still crash", since it does not depend on episode length.
        #
        # nan rather than zero when no episode finished at all: a rollout shorter
        # than an episode has no answer, and zero would read as a clean sweep.
        "collision_rate_per_episode": (crashes / episodes).item() if episodes > 0 else float("nan"),
    }
    stats.update({
        f"reward_{name}_mean": next_td[key].mean().item()
        for name, key in REWARD_TERM_KEYS.items()
    })
    return stats
