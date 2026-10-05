#set text(size: 12pt)
#set page(margin: 2.5cm)
#import "@preview/latex-lookalike:0.1.1": style-outline
#import "@preview/cetz:0.5.2"
#import "@preview/fletcher:0.5.8" as fletcher: diagram, edge, node, rect-at
#show heading.where(level: 1): set block(above: 4em, below: 1em)
#show heading.where(level: 1): set text(size: 24pt, weight: "bold")

#show: style-outline

#align(center + horizon)[
  #title("Auxiliary learning for autonomous racing")

  #image("./frontmatter/UScrest-WM.jpg", width: 120pt)

  #v(1cm)

  #text("Jacques Friedrich Amsel", size: 16pt, weight: "bold")

  Student number: 26938839

  #v(1cm)

  #block(width: 400pt)[
    Report submitted in partial fulfilment of the requirements of the module
    Project (E) 448 for the degree Baccalaureus in Engineering in the Department of Electrical
    and Electronic Engineering at the University of Stellenbosch
  ]

  #v(1cm)

  *Study leader:* Prof. JC Schoeman

  #v(1cm)

  *Date*: #datetime.today().display("[month repr:long] [year]")
]

#pagebreak()
#set page(numbering: "i")
#counter(page).update(1)

= Acknowledgements

#pagebreak()

= Plagarism declaration

#pagebreak()

= Abstract

#pagebreak()

#outline(title: "Table of contents")

#pagebreak()

= Notation & acronyms
#table(
  columns: (1.5fr, 2fr),
  gutter: 8pt,
  stroke: none,
  [$gamma$], [Discount rate],
  [$lambda$], [GAE discount rate],
  [$r_t$], [Reward received at time $t$],
  [$G_t = sum_(i=t)^T gamma^(i-t) dot r_i$], [Discounted return at time $t$],
  [$cal(S)$], [Set of all states],
  [$S_t$], [Random variable for state at time $t$],
  [$s_t$], [State at time $t$],
  [$cal(O)$], [Observation space],
  [$O_t$], [Random variable for agent's observation at time $t$],
  [$o_t$], [Agent's observation at time $t$],
  [$cal(A)$], [Action space],
  [$A_t$], [Random variable for action taken at time $t$],
  [$a_t$], [Observed action taken at time $t$],
  [$pi_theta$], [Policy given parameters $theta$],
  [$pi_theta (a_t | o_t)$],
  [Probability density for action $a_t$ given observation $o_t$ and policy parameters $theta$],

  [$Delta_cal(Y) (X)$], [Set of all probability distributions over variable X with support $cal(Y)$],
  [$V^pi (s) = EE_pi [R_t | S_t = s]$], [Value function for policy $pi$ at state $s$],
  [$Q^pi (s, a) = EE_pi [R_t | S_t = s, A_t = a]$ ],
  [Action-value function for policy $pi$ at state $s$ and action $a$],

  [$hat(X)$], [Estimator for random variable $X$],
  [$hat(x)$], [Sample estimate of random variable $X$],
  [$A^pi (s, a) = Q^pi (s, a) - V^pi (s)$], [Advantage function for policy $pi$ at state $s$ and action $a$],
  [$RR$], [The set of real numbers],
  [$EE[X]$], [Expected value of random variable $X$],
  [$"Var"(X)$], [Variance of random variable $X$],
  [$rho_0 (s)$], [Initial state distribution],
)

#pagebreak()

#set page(numbering: "1")
#counter(page).update(1)

#set heading(numbering: "1.")

= Introduction

where the background to the project and the project aims
are described. A short summary of the report can also be given.

= Background

== Markov Decision Processes (MDPs)
A Markov Decision Process (MDP) is a mathematical framework for modelling problems in which an agent must make a series of decisions in an environment. At each time step $t$, the environment is in some state $s_t in cal(S)$, which is a _complete_ description of the environment at time $t$. The agent, however, only partially observes the environment - its observation is $o_t in cal(O)$, where $cal(O)$ is the observation space. In this case, the environment is said to be _partially observable_, and the problem is formally a _partially observable_ MDP (POMDP). The information available in the state $s_t$ that is not available in the observation $o_t$ is called _privileged information_.

Based on its observation $o_t$, the agent chooses an action $a_t in cal(A)$. How the agent chooses is described by its _policy_, $pi$: a rule that tells the agent what to do in every situation it might encounter. One can think of the policy as the agent's strategy or rulebook: given the current observation, it returns the action the agent will take. For example, a policy for a self-driving car might say "if the light ahead is red, brake". The policy may also be stochastic, assigning a probability to each action rather than always picking the same one; we write $a_t ~ pi(dot | o_t)$ to mean the action is sampled from the policy. Note that we consider the policy to map observations to actions, compared to the classical mapping of states to actions in @bellman1957, since the agent cannot act on information it does not have. The policy is not part of the MDP itself: the policy describes the agent's behaviour, while the MDP describes the environment in which the agent operates.

Once the agent takes an action $a_t$, the environment responds by transitioning to a new state $s_(t+1) in cal(S)$, emitting a reward to the agent, $r_t in RR$, and a new observation $o_(t+1) in cal(O)$. The reward is a scalar value that indicates how good the outcome of the agent's action is. It is a function of the action taken, and both the current state and the successor state: $r_t = R(s_(t), a_t, s_(t+1))$. Note that the reward depends on the true state, not on the agent's observation of it.

The agent may experience a "life" within the same MDP many times over, and each time it does so is called an _episode_. An episode starts with the environment in some initial state $s_0 ~ rho_0$, and ends when the agent reaches a terminal state, or after a fixed number of time steps. The agent's objective is to learn a policy that maximises the expected _discounted return_, $EE_pi [G_0]$, where

$ G_t = sum_(i=t)^T gamma^(i-t) r_i $

is the discounted return from time step $t$, $T$ is the time step at which the episode terminates, and the expectation is taken over all trajectories that can arise from $rho_0$, the environment's dynamics, and the policy $pi$. The policy that achieves this maximum is called the _optimal policy_, $pi^*$.

The discount factor $gamma in [0, 1]$ controls how much the agent values future rewards relative to immediate ones. The return can be thought of as a weighted sum of all future rewards, in which a reward received $k$ steps from now is worth only $gamma^k$ times as much as the same reward received immediately, akin to an interest rate in a discounted cashflow model. A $gamma$ close to $0$ makes the agent short-sighted, while a $gamma$ close to $1$ makes it value long-term outcomes almost as much as immediate ones.

Formally, a POMDP is defined by a tuple $(cal(S), cal(A), cal(O), cal(P), cal(Z), R, rho_0, gamma)$, where

- *$cal(S)$* is the state space, which is the set of all possible states the environment can be in.

- *$cal(A)$* is the action space, which is the set of all possible actions the agent can take. An action $a_t in cal(A)$ is a decision made by the agent at time $t$ that (may) affect the environment.

- *$cal(O)$* is the observation space, which is the set of all possible observations the agent can receive.

- *$cal(P): cal(S) times cal(A) -> Delta(cal(S))$* is the transition function, which defines the probability of transitioning to a successor state $s_(t+1)$ given the current state $s_t$ and action $a_t$, formally $s_(t+1) ~ cal(P)(dot | s_t, a_t)$.

- *$cal(Z): cal(S) -> Delta(cal(O))$* is the observation function, which defines the probability of the agent receiving observation $o_t$ when the environment is in state $s_t$, formally $o_t ~ cal(Z)(dot | s_t)$.

- *$R: cal(S) times cal(A) times cal(S) -> RR$* is the reward function, which defines the reward received by the agent given the action taken and the successor state, formally $r_t = R(s_t, a_t, s_(t+1))$.

- *$rho_0 in Delta(cal(S))$* is the initial state distribution, formally $s_0 ~ rho_0$.

- *$gamma in [0, 1]$* is the discount factor described above.

Transitions satisfy the _Markov property_: the successor state depends only on the current state and action, and not on the rest of the history,

$ P(s_(t+1) | s_t, a_t, s_(t-1), a_(t-1), dots, s_0, a_0) = P(s_(t+1) | s_t, a_t). $

This property holds for the states, but generally not for the observations: a single observation $o_t$ does not, in general, contain enough information to predict $o_(t+1)$.

#let s-node(pos, body) = node(pos, body, shape: circle, radius: 1.1em)
#let o-node(pos, body) = node(
  pos,
  body,
  shape: circle,
  radius: 1.1em,
  stroke: (thickness: 1pt, dash: "dashed"),
)
#let a-node(pos, body) = node(pos, body, shape: rect, width: 2.2em, height: 2.2em)
#let r-node(pos, body) = node(pos, body, shape: fletcher.shapes.diamond, inset: 5pt)

@mdp_trajectory illustrates how, at each step, the agent receives an observation $o_t$ (dashed circle) of the state $s_t$ (circle), and samples an action $a_t$ (square) from its policy $pi$ given that observation. The successor state $s_(t+1)$ is drawn from $cal(P)(dot | s_t, a_t)$, so it depends only on the current state and action (the Markov property). The reward $r_t$ (diamond) depends on the action $a_t$ and the successor state $s_(t+1)$.

#figure(
  diagram(
    node-stroke: 1pt,
    spacing: (4em, 2.5em),

    // Initial state distribution
    edge((-1, 0), (0, 0), "-|>", $rho_0$),

    // Nodes
    s-node((0, 0), $s_0$),
    o-node((0, 1), $o_0$),
    a-node((0, 2), $a_0$),
    r-node((0.75, 2), $r_0$),
    s-node((2, 0), $s_1$),
    o-node((2, 1), $o_1$),
    a-node((2, 2), $a_1$),
    r-node((3, 2), $r_1$),
    s-node((4, 0), $s_2$),
    o-node((4, 1), $o_2$),
    node((5, 0), $dots$, stroke: none),

    // Step 0
    edge((0, 0), (0, 1), "-|>", $cal(Z)(dot|s_0)$),
    edge((0, 1), (0, 2), "-|>", $pi(dot|o_0)$),
    edge((0, 0), (2, 0), "-|>", $cal(P)(dot|s_0, a_0)$, label-side: right, label-pos: 0.6),
    edge((0, 2), (2, 0), "-|>"),
    edge((0, 2), (0.75, 2), "-|>"),
    edge((2, 0), (0.75, 2), "-|>"),

    // Step 1
    edge((2, 0), (2, 1), "-|>", $cal(Z)(dot|s_0)$, label-side: left),
    edge((2, 1), (2, 2), "-|>", $pi(dot|o_1)$),
    edge((2, 0), (4, 0), "-|>", $cal(P)(dot|s_1, a_1)$, label-side: right, label-pos: 0.6),
    edge((2, 2), (4, 0), "-|>"),
    edge((2, 2), (3, 2), "-|>"),
    edge((4, 0), (3, 2), "-|>"),

    // Step 2
    edge((4, 0), (4, 1), "-|>", $cal(Z)$, label-side: left),
    edge((4, 0), (5, 0), "-|>"),
  ),
  caption: [
    The first two steps of a trajectory in a partially observable MDP.
  ],
) <mdp_trajectory>


=== Value functions
In an MDP, 

== Reinforcement Learning (RL)
Reinforcement learning is a subfield of machine learning, where a policy $pi_theta$ is learned through an agent's interactions with an environment with the objective of maximising the expected return $EE[G_t]$ by varying the parameters $theta$ of the policy. This is done by sampling trajectories of the agent's interactions with the environment, and using the observed rewards to update the policy parameters $theta$ in a way that increases the probability of actions that lead to higher returns.

RL is distinct from supervised learning in that the agent does not know the correct or optimal action to take at any given time, and must learn this through trial and error. 

#v(2em)

#let party(pos, body) = node(pos, strong(body), stroke: 1pt, corner-radius: 3pt)
#let step(pos, body) = node(pos, body, stroke: 0.5pt, fill: white)
#let msg(from, to, label) = edge(from, to, "-|>", label, label-angle: auto)
#let lifeline(x, end) = edge((x, 0), (x, end), stroke: (paint: gray, dash: "dashed"), layer: -1)

#figure(
  diagram(
    spacing: (8em, 1.8em),
    node-inset: 6pt,

    // Participants and lifelines
    party((0, 0), [Agent]),
    party((1, 0), [Environment]),
    lifeline(0, 6),
    lifeline(1, 6),

    edge((-0.5, 2), (-0.5, 3), layer: -1, "-|>", $t$),

    // Local computations
    step((1, 1), $s_0 ~ rho_0$),
    step((0, 2), $a_0 ~ pi(dot | s_0)$),
    step((1, 3), $s_1 ~ P(dot | s_0, a_0)$),
    step((0, 4), $a_1 ~ pi(dot | s_1)$),
    step((1, 5), $s_2 ~ P(dot | s_1, a_1)$),
    node((0, 6), $dots.v$, fill: white),
    node((1, 6), $dots.v$, fill: white),

    // Messages
    msg((1, 1), (0, 2), $o_0$),
    msg((0, 2), (1, 3), $a_0$),
    msg((1, 3), (0, 4), $r_0, o_1$),
    msg((0, 4), (1, 5), $a_1$),
    msg((1, 5), (0, 6), $r_1, o_2$),
  ),
  caption: [
    Interaction between the agent and the environment over time.
  ],
)

== REINFORCE

The REINFORCE algorithm for policy learning was introduced in \_\_\_ at NeurIPS by \_\_\_. It is one of the simplest policy gradient methods. The central idea is
1. $pi_theta (s) <- "initial policy"$
2. $s_0 <- "initial state"$
3. $t <- 0$
4. $a_t <- "SAMPLE" [pi_theta (s_t)]$
5. Perform action $a_t$
6. Environment emits reward $r_t$ and updates to state $s_(t+1)$
7. If the episode is not over, increment t and return to step 4, else continue
8. Calculate the discounted returns $R_i = sum_(k=i)^T gamma^(k-i) dot r_k$
9. Minimise the loss $L(theta) = - 1/T sum_(t=0)^T log(P_(pi_theta (s_t))(a_t)) dot R_t$ using Stochastic Gradient Descent (SGD) varying parameters $theta$.
10. Return to step 2

== Proximal Policy Optimization (PPO)
PPO is a modern algorithm for policy learning introduced in \_\_\_ at ICML by \_\_\_. It is a more advanced policy gradient method than REINFORCE. It improves upon REINFORCE by using a surrogate loss function which prevents large and destructive policy updates and by approximating the value function, reducing the variance of the policy gradient estimate.

The model we train no longer only outputs a distribution over actions, but also an estimate of the value function $hat(V) (s_t)$ for each oberserved state $s_t$. Then, the advantage $A_t = R_t - hat(V) (s_t)$ is computed, a measure of the suprise the model experiences at time $t$ (i.e. how much better it actually was to be in state $s_t$ compared to the model's estimate).

$
  L_"clipped" (theta) = 1/T sum_(t=0)^T min((pi_theta (s_t))/(pi (s_t)) dot (hat(A)_t))
$

= Auxiliary learning in RL

== 1st formulation (auxiliary loss)
Auxiliary learning is the practice of augmenting the loss function with heads for auxiliary tasks. For example, the model may be trained to simultaneously (a) produce a distribution over actions, and (b) estimate estimate the state $S_t$ which is partially observed in its observation $O_t$. Auxiliary learning has been empirically shown to improve sample efficiency in "complex enough" environments, and in certain situations, average reward too.
#text("https://ieeexplore.ieee.org/document/10166271/", fill: red)



#figure(
  caption: "1st formulation of auxiliary learning in RL",
  diagram(
    node-stroke: 1pt,
    node((-1.25, -0.), align(top + left)[Environment], height: 60pt, width: 120pt),
    node((-1.5, 0), $S_t$, shape: circle, name: <S_t>),
    edge(<S_t>, <O_t>, "-|>"),
    node((-1, 0), $O_t$, shape: circle, name: <O_t>),
    edge(<O_t>, <Model>, "-|>"),
    node(
      (0, 0),
      [Model #linebreak() (parameters $theta$)],
      width: 90pt,
      height: 60pt,
      corner-radius: 0pt,
      name: <Model>,
    ),
    edge(<Model>, <hatS_t>, "-|>"),
    node((1, -0.5), $hat(S_t)$, name: <hatS_t>),
    edge(<Model>, <A_t>, "-|>"),
    node((1, 0.5), $A_t$, name: <A_t>, shape: circle),
  ),
)

The loss function can then be written as
$
  L_"total" = L_"policy" (A_t, R_t) + L_"aux" (S_t, hat(S_t))
$

Then, during a gradient update step, the parameters $theta$ are updated using information from both loss heads.

$
  theta_(t+1) = theta_(t) + alpha dot Delta_theta L_"total" =
$

== 2nd formulation (auxiliary rewards)
Auxiliary learning can also be formulated as an additional task the agent receives rewards for performing (well). This formulation has the drawback that gradient information is discarded.

= The environment

== F1Tenth Gym

== AutoDrive, Unity, and MLAgents

=== Track generation

#figure(
  caption: "Track generation",
  cetz.canvas({
    import cetz.draw: *
    circle((0, 0), radius: 4)
    // dots: roughly trace the guide circle for 3/4 of a revolution, with a
    // little radial jitter so it reads as a walk rather than a perfect ring
    let n = 8
    let sweep = 270deg
    let jitter = (0, 0.3, -0.2, 0.4, -0.3, 0.2, -1.5, 0.1)
    let dots = range(n).map(idx => {
      let angle = sweep * (idx / (n - 1))
      let r = 4 + jitter.at(idx)
      (r * calc.cos(angle), r * calc.sin(angle))
    })

    for idx in range(n) {
      if idx != 0 {
        line(dots.at(idx - 1), dots.at(idx))
      }
    }
    for idx in range(n) {
      circle(dots.at(idx), radius: 8pt, fill: black)
      content(dots.at(idx))[#text(size: 12pt, fill: white)[#(idx + 1)]]
    }

    let last_point = dots.at(n - 1)
    let second_last_point = dots.at(n - 2)

    let last_point_tanget_of_circle = last_point.at(0) / last_point.at(1)

    // Draw tangent from last point
    let tangent_length = 4

    let tangent_end = (
      last_point.at(0) + tangent_length,
      last_point.at(1) + tangent_length * last_point_tanget_of_circle,
    )

    line(last_point, tangent_end)
  }),
)

= The model

#figure(
  caption: "Simplified model",
  diagram(
    node-stroke: 1pt,
    node((-2.75, -0.5), "Lidar", name: <Lidar>),
    node((-2.75, 0), "Cur steering angle", name: <Steering>),
    node((-2.75, 0.5), "Cur throttle angle", name: <Throttle>),

    edge(<Lidar>, <Trunk>, "-|>"),
    edge(<Steering>, <Trunk>, "-|>"),
    edge(<Throttle>, <Trunk>, "-|>"),
    node((-1.25, -0.), "Trunk", height: 30pt, width: 60pt, name: <Trunk>),

    edge(<Trunk>, <Policy>, "-|>"),
    edge(<Trunk>, <Value>, "-|>"),
    edge(<Trunk>, <Aux>, "-|>"),

    node((0, -0.75), "Policy", height: 30pt, width: 70pt, name: <Policy>),
    node((0, 0), "Value head", height: 30pt, width: 70pt, name: <Value>),
    node((0, 0.75), "Auxiliary head", height: 30pt, width: 70pt, name: <Aux>),
  ),
)

= Results

== Training curves

= Conclusions and recommendations
#pagebreak()
#bibliography("./hyagriva.yaml", style: "ieee", title: [Bibliography])




