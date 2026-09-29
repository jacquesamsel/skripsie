#set text(size: 12pt)
#set page(margin: 2.5cm)
#import "@preview/latex-lookalike:0.1.1": style-outline
#import "@preview/fletcher:0.5.8" as fletcher: diagram, edge, node, rect-at

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
  [$R_t = sum_(i=t)^T gamma^(i-t) dot r_i$], [Discounted return at time $t$],
  [$cal(S)$], [State space],
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
  [$Re$], [The set of real numbers],
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
A Markov Decision Process (MDP) is a mathematical framework for modelling sequential decision making problems where the environment is fully observable and the next state depends only on the current state $s_t$ and the action taken $a_t$. This makes the current state a _sufficient summary_ of the past: an agent loses nothing by ignoring the history.

#let s-node(pos, body) = node(pos, body, shape: circle, radius: 1.1em)
#let a-node(pos, body) = node(pos, body, shape: rect, width: 2.2em, height: 2.2em)
#let r-node(pos, body) = node(pos, body, shape: fletcher.shapes.diamond, inset: 5pt)


The initial state $s_0$ is
drawn from $rho_0$. At each step, the agent samples an action $a_t$
(square) from its policy $pi$ given the state $s_t$ (circle). The successor
state $s_(t+1)$ is drawn from $P(dot | s_t, a_t)$, so it depends only on the
current state and action (the Markov property). The reward $r_t$ (diamond)
depends on the action $a_t$ and the successor state $s_(t+1)$.


#figure(
  diagram(
    node-stroke: 1pt,
    spacing: (3em, 2.5em),

    // Initial state distribution
    edge((-1, 0), (0, 0), "-|>", $rho_0$),

    // Nodes
    s-node((0, 0), $s_0$),
    a-node((1, 1), $a_0$),
    s-node((2, 0), $s_1$),
    r-node((2, 1), $r_0$),
    a-node((3, 1), $a_1$),
    s-node((4, 0), $s_2$),
    r-node((4, 1), $r_1$),
    node((5, 0), $dots$, stroke: none),

    // Step 0
    edge((0, 0), (1, 1), "-|>", $pi(s_0)$, label-side: left, label-pos: 0.6, label-sep: 0.1em),
    edge((0, 0), (2, 0), "-|>", $P$),
    edge((1, 1), (2, 0), "-|>"),
    edge((1, 1), (2, 1), "-|>"),
    edge((2, 0), (2, 1), "-|>"),

    // Step 1
    edge((2, 0), (3, 1), "-|>", $pi(s_1)$, label-side: left, label-pos: 0.6, label-sep: 0.1em),
    edge((2, 0), (4, 0), "-|>", $P$),
    edge((3, 1), (4, 0), "-|>"),
    edge((3, 1), (4, 1), "-|>"),
    edge((4, 0), (4, 1), "-|>"),

    edge((4, 0), (5, 0), "-|>"),
  ),
  caption: [
    The first two steps of a trajectory in an MDP.
  ],
)

An MDP is defined by a tuple $(cal(S), cal(A), cal(P), R, gamma)$, where $cal(S)$ is the state space, $cal(A)$ is the action space, $P(s_t, a_t, s_(t+1)) -> [0, 1]$ is the transition probability function, $R(a_t, s_(t+1)) -> Re$ is the reward function, and $gamma in [0, 1]$ is the discount factor.


The objective of an agent interacting with an MDP is to learn a policy $pi(s) -> Delta(cal(A))$ that maximises the expected discounted return $EE[R_t]$, where $R_t = sum_(i=t)^T gamma^(i-t) dot r_i$ is the discounted return at time $t$, and $T$ is the time step at which the episode terminates.

== Reinforcement Learning
Reinforcement learning is a subfield of machine learning, where a policy $pi$ is learned through an agent's interactions with an environment with the objective of maximising the expected return $EE[R_t]$. The policy takes as input the observation of the environment $o_t in cal(O)$, and outputs a distribution over actions $cal(A)$. When the agent interacts with the environmnet, it does so by performing an action $a_t ~ pi(o_t)$. The environment responds by updating its state from $s_t in cal(S)$ to $s_(t+1) in cal(S)$, and emitting a scalar reward $r_t in Re$, which may depend on the action $a_t$ performed and the successor state $s_(t+1)$.

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

Note that this is distinct from the classical formulation where the agent directly observes the state $s_t$. In our case, the environment is said to be _partially observable_, and the agent must learn a policy that maps from observations to actions (compared to the classical mapping of states to actions). The information available in the state $s_t$ that is not available in the observation $o_t$ is called privledged information.

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

= Our model

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

= Conclusions and recommendations
#pagebreak()
#bibliography("./hyagriva.yaml", style: "ieee", title: [Bibliography])




