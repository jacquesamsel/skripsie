= REINFORCEMENT LEARNING WITH UNSUPERVISED AUXILIARY TASKS
DeepMind, 2016
"UNREAL"
https://arxiv.org/pdf/1611.05397

The auxiliary head produces a tensor $Q^"aux" "of size" N_"act" × 20 × 20$. Entry (a, i, j) is the agent's estimate of the discounted future pixel change in cell (i, j) if it takes action a now and then acts optimally for that cell.

This is a PPO agent so the the above is the value estimate.

Basically there's many auxiliary tasks (predicting amount of future change in pixel patches), and each one is trained *off-policy* using PPO & the experience replay buffer.


= Curiosity-driven Exploration by Self-supervised Prediction
https://proceedings.mlr.press/v70/pathak17a/pathak17a.pdf

Split changes in the environment into three kinds:

+ things the agent controls,
+ things it doesn't control but that affect it (e.g. another driver),
+ things it can't control and that don't affect it (e.g. TV static).

Curiosity should respond to (1) and (2) only.

Encode the state as $phi_t = phi(s_t)$. Train two heads on top of the encoder:

- An *inverse model* predicts the action from the feature pair, $hat(a)_t = g(phi_t, phi_(t+1))$. This only trains $phi$, so it keeps action-relevant information and discards the rest. The inverse error is *not* the reward.
- A *forward model* predicts the next features, $hat(phi)_(t+1) = f(phi_t, a_t)$.

The intrinsic reward is the forward prediction error:

$ r_t^"i" = norm(hat(phi)_(t+1) - phi_(t+1))_2^2 $

Because $phi$ discards category 3, such changes never produce forward prediction error, and so never produce reward.

= Policy Invariance Under Reward Transformations: Theory and Application to Reward Shaping
http://luthuli.cs.uiuc.edu/~daf/courses/Games/AIpapers/ml99-shaping.pdf

Andrew Ng

If shaped rewards have the form $r_t^"shaped" = r_t + underbrace((gamma F(s_(t+1)) - F(s_t)), Delta tilde(F))$, then the optimal policy is invariant to the shaping function F. This is called *potential-based reward shaping*. (i.e. the optimal policy is the same as if the agent was trained on the original reward function, but may just learn faster)

Imagine giving rewards for progress along a track. Since driving forward and backward along the track cancels out in terms of reward, it is a "potential" where $F(s)$ gives the distance along the track.

Interestingly, this is also the case when that $gamma$ is included which is surprising & cool!

Learning to Navigate in Complex Environments
https://arxiv.org/pdf/1611.03673



