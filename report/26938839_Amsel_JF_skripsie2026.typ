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
  columns: (1fr, 2fr),
  gutter: 8pt,
  stroke: none,
  [$gamma$], [Discount rate],
  [$r_t$], [Reward received at time $t$],
  [$R_t = sum_(i=t)^T gamma^(i-t) dot r_t$], [Discounted return at time $t$],
  [$S$], [State space],
  [$S_t$], [Random variable for state at time $t$],
  [$O_t$], [Agent's observation at time $t$],
  [$A$], [Action space],
  [$a_t$], [Observed action taken at time $t$],
  [$A_t$], [Random variable for action taken at time $t$],
  [$pi_theta (O_t) -> "dist"(A)$], [Policy given parameters $theta$],
  [],
)

#pagebreak()

#set page(numbering: "1")
#counter(page).update(1)

#set heading(numbering: "1.")

= Introduction

where the background to the project and the project aims
are described. A short summary of the report can also be given.

= Reinforcement Learning
Reinforcement learning is a subfield of machine learning, where a policy $pi(s in S) -> P(A)$ is learned through an agent's interactions with an environment. The policy takes as input the state, and outputs a distribution over the actions $A$. When the agent interacts with the environemnt it does so by performing an action $a in A$. The environment responds by updating its state from $s_t in S$ to $s_(t+1) in S$, and emitting a reward $R_t in Re$, which may depend on the action performed and the successor state $s_(t+1)$.

#figure(
  caption: "Flow diagram of an MDP",
  diagram(
    node-stroke: 1pt,
    edge((-2, 0), "r", "-|>", [Start], label-pos: 0, label-side: center),
    node((-1, 0), $s_t$, radius: 3em),
    edge([Sample $pi(s_t)$], "-|>"),
    node((1, 0), $a_t$, radius: 3em),
    edge([Perform $a_t$], "-|>"),
    node((3, 0), [$r_t$ and $s_(t+1)$], radius: 3em),
    edge((3, 0), (-1, 0), "-|>", bend: -40deg),
  ),
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
  L_"total" = L_"policy" (A_t, R_t) - L_"aux" (S_t, hat(S_t))
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




