#import "@preview/cetz:0.5.2"
#import "@preview/fletcher:0.5.8" as fletcher: diagram, edge, node, rect-at

// ============================================================
// Styling after the Stellenbosch University thesis class
// (stb-thesis.cls + imports.tex), see su_latex_template/.
// ============================================================

// Colours from imports.tex
#let oracle-colour = rgb("#8B8589") // running header text
#let rule-colour = rgb("#DCDCDC") // rule below the running header
#let link-colour = rgb("#666666") // gray!80!black for cites and URLs

// --- Fonts and text: 12pt Latin Modern Roman -----------------
#set text(font: "New Computer Modern", size: 12pt, lang: "en", region: "ZA")
#show math.equation: set text(font: "New Computer Modern Math")
#show raw: set text(font: "DejaVu Sans Mono", size: 10pt)

// --- Paragraphs: justified, \onehalfspacing, \parindent, \parskip=0
// The title page itself stays centred and unindented, so justification
// and the paragraph indent are switched on where the front matter starts.
#set par(leading: 1.05em, spacing: 1.05em)

// --- Page: \usepackage[left=3cm,right=2cm,top=2.5cm,bottom=2.5cm]{geometry}
// with the fancyhdr header (centred running mark + rule) and the
// page number in the bottom-right corner.
#set page(
  paper: "a4",
  margin: (left: 2.5cm, right: 2.5cm, top: 2.5cm, bottom: 2.5cm),
  number-align: right + bottom,
  header: context {
    let this-page = here().page()
    let seen = query(heading).filter(h => h.location().page() <= this-page)
    // \fancypagestyle{plain}: no header on chapter-opening pages
    if seen.any(h => h.level == 1 and h.location().page() == this-page) { return }
    let marks = seen.filter(h => h.level <= 2)
    if marks.len() == 0 { return }
    let mark = marks.last()
    let number = if mark.numbering != none {
      numbering(mark.numbering, ..counter(heading).at(mark.location())) + " "
    } else { "" }
    set par(justify: false, leading: 0.65em, first-line-indent: 0pt)
    set align(center)
    text(fill: oracle-colour)[#number#smallcaps(mark.body)]
    v(-0.4em)
    line(length: 100%, stroke: 0.1pt + rule-colour)
  },
)

// --- Headings: \titleformat from imports.tex -----------------
// Chapters: right-aligned "Chapter N" in small caps, a rule, the title
// centred in \Huge small caps, and a second rule.
#show heading.where(level: 1): it => {
  counter(figure.where(kind: image)).update(0)
  counter(figure.where(kind: table)).update(0)
  counter(figure.where(kind: raw)).update(0)
  pagebreak(weak: true)
  set par(justify: false, leading: 0.6em, first-line-indent: 0pt)
  set text(weight: "regular")
  block(above: 30pt, below: 10pt, width: 100%, sticky: true)[
    // #if it.numbering != none [
    //   #align(right, text(size: 20pt, smallcaps[Chapter #counter(heading).display("1")]))
    //   #v(3pt)
    // ]
    //#line(length: 100%, stroke: 0.4pt)
    #v(1.5em)
    #let count_text = if it.numbering != none {
      numbering(it.numbering, ..counter(heading).at(it.location())) + " "
    } else { "" }
    #align(center, text(size: 25pt, count_text + smallcaps(it.body)))
    #v(1.5em)
    //#line(length: 100%, stroke: 0.4pt)
  ]
}

// Sections, subsections and subsubsections: ragged-right small caps,
// the number followed by \quad.
#let stb-heading(size, above, below) = it => {
  set par(justify: false, leading: 0.6em, first-line-indent: 0pt)
  set text(size: size, weight: "regular")
  block(above: above, below: below, width: 100%, sticky: true)[
    #smallcaps[
      #if it.numbering != none [
        #counter(heading).display(it.numbering)#h(1em)
      ]
      #it.body
    ]
  ]
}
#show heading.where(level: 2): stb-heading(17pt, 1.8em, 1em)
#show heading.where(level: 3): stb-heading(14pt, 1.6em, 0.8em)
#show heading.where(level: 4): stb-heading(12pt, 1.4em, 0.7em)

// --- Title page: \LARGE, no bold (stb-titlepage.sty) ---------
#show title: set text(size: 20pt, weight: "regular")

// --- Figures and tables: numbered per chapter, captions at
// \small with a bold label (caption package: small, bf, rm).
#set figure(numbering: n => numbering("1.1", counter(heading).get().first(), n), gap: 8pt)
#show figure: set block(above: 1.8em, below: 1.8em)
#show figure.caption: it => context {
  set text(size: 11pt)
  set par(justify: false, leading: 0.65em, first-line-indent: 0pt)
  pad(x: 1.5em)[
    #align(center)[
      #strong[#it.supplement~#it.counter.display(it.numbering)#it.separator]#it.body
    ]
  ]
}

// --- Lists: \labelitemi is $\divideontimes$ ------------------
#set list(marker: text(size: 9pt, sym.circle.stroked.small), indent: 1em)
#set enum(indent: 1em)

// --- Table of contents: tocdepth = 3 (up to subsubsections) --
#set outline(depth: 4)

// --- Hyperlinks: black internal links, gray!80!black cites/URLs
#show link: set text(fill: link-colour)
#show cite: set text(fill: link-colour)

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
#set par(justify: true, first-line-indent: (amount: 1.5em, all: false))

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
Autonomous racing is a challenging problem in robotics and artificial intelligence, requiring the development of algorithms that can make real-time decisions in complex and dynamic environments. The goal is to create an autonomous agent capable of navigating a race track at high speeds while avoiding obstacles and (in some cases) competing against other agents. However, traditional reinforcement learning (RL) methods often struggle to learn effective policies in such environments due to the high-dimensional state and action spaces, as well as the sparse and delayed rewards. Auxiliary learning has emerged as a promising approach to address these challenges by providing additional learning signals that can improve the agent's performance and sample efficiency.

= Background

== Markov Decision Processes (MDPs)
A Markov Decision Process (MDP) is a mathematical framework for modelling problems in which an agent must make a series of decisions in an environment. At each time step $t$, the environment is in some state $s_t in cal(S)$, which is a _complete_ description of the environment at time $t$. The agent, however, only partially observes the environment - its observation is $o_t in cal(O)$, where $cal(O)$ is the observation space. In this case, the environment is said to be _partially observable_, and the problem is formally a _partially observable_ MDP (POMDP). The information available in the state $s_t$ that is not available in the observation $o_t$ is called _privileged information_.

Based on its observation $o_t$, the agent chooses an action $a_t in cal(A)$. How the agent chooses is described by its _policy_, $pi$: a rule that tells the agent what to do in every situation it might encounter. One can think of the policy as the agent's strategy or rulebook: given the current observation, it returns the action the agent will take. For example, a policy for a self-driving car might say "if the light ahead is red, brake". The policy may also be stochastic, assigning a probability to each action rather than always picking the same one; we write $a_t ~ pi(dot | o_t)$ to mean the action is sampled from the policy. Note that we consider the policy to map observations to actions, compared to the classical mapping of states to actions in @bellman1957 and @kaelbling1998, since the agent cannot act on information it does not have. The policy is not part of the MDP itself: the policy describes the agent's behaviour, while the MDP describes the environment in which the agent operates.

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

#let party(pos, body) = node(pos, strong(body), stroke: 1pt, corner-radius: 3pt)
#let step(pos, body) = node(pos, body, stroke: 0.5pt, fill: white)
#let msg(from, to, label) = edge(from, to, "-|>", label, label-angle: auto)
#let lifeline(x, end) = edge((x, 0), (x, end), stroke: (paint: gray, dash: "dashed"), layer: -1)

#figure(
  diagram(
    spacing: (15em, 2.5em),
    node-inset: 6pt,

    // Participants and lifelines
    party((0, 0), [Agent]),
    party((1, 0), [Environment]),
    lifeline(0, 6),
    lifeline(1, 6),

    edge((-0.3, 2), (-0.3, 3), layer: -1, "-|>", $t$),

    // Local computations
    step((1, 1), $s_0 ~ rho_0$),
    step((0, 2), $a_0 ~ pi(dot | s_0)$),
    step((1, 3), $s_1 ~ P(dot | s_0, a_0)$),
    step((0, 4), $a_1 ~ pi(dot | s_1)$),
    step((1, 5), $s_2 ~ P(dot | s_1, a_1)$),
    node((0, 6), $dots.v$, fill: white),
    node((1, 6), $dots.v$, fill: white),

    // Messages
    msg((1, 1), (0, 2), $o_0 = cal(Z)(s_0)$),
    msg((0, 2), (1, 3), $a_0$),
    msg((1, 3), (0, 4), $r_0 = R(s_0, a_0, s_1), o_1 = cal(Z)(s_1)$),
    msg((0, 4), (1, 5), $a_1$),
    msg((1, 5), (0, 6), $r_1 = R(s_1, a_1, s_2), o_2 = cal(Z)(s_2)$),
  ),
  caption: [
    Interaction between the agent and the environment over time ($t$).
  ],
)


=== Value functions
// TODO: finish

== Reinforcement Learning (RL)
Reinforcement learning is a subfield of machine learning, where a policy $pi_theta$ is learned through an agent's interactions with an environment with the objective of maximising the expected return $EE[G_t]$ by varying the parameters $theta$ of the policy (i.e. finding the optimal policy $pi^*$). This is done by sampling trajectories of the agent's interactions with the environment, and using the observed rewards to update the policy parameters $theta$ in a way that increases the probability of actions that lead to higher returns.

RL is distinct from supervised learning in that during training, the optimal or correct action is not known - the agent must explore the environment and learn from the consequences of its actions. It is also distinct from classical unsupervised learning methods in that there is a clear objective (maximising expected return) and feedback (rewards) to guide the learning process.

There exist two primary classes of RL algorithms: value-based methods and policy-based methods. Value-based methods learn a value function that estimates the expected return for each state or state-action pair ($hat(V)(s_t)$ or $hat(Q)(s_t, a_t)$ respectively), and derive a policy from this value function (for example, acting greedily). Policy-based methods learn a parameterised policy directly, without explicitly estimating a value function. We focus on policy-based methods in this report, as they are more suitable for continuous action spaces and can natively learn stochastic policies, without tricks such as $epsilon$-greedy. @sutton2018

== Policy gradient methods

Policy gradient methods are a class of RL algorithms that learn a parameterised policy $pi_theta$ directly by optimising the expected return $EE[G_t]$ with respect to the policy parameters $theta$. Given a trajectory $tau = (s_0, a_0, r_0, s_1, a_1, r_1, dots, s_T, a_T, r_T) ~ p_theta$, where $p_theta$ is the probability of the trajectory under the policy $pi_theta$, the expected return must be maximised with respect to the policy parameters $theta$:
$
  J(theta) = EE_(tau~pi_theta) [G_0] = EE_(tau~pi_theta) [sum_(t=0)^T gamma^t r_t]
$

Using the _log-derivative_ trick, the gradient of the expected return with respect to the policy parameters $theta$ can be calculated as follows:

$
$


== REINFORCE

The REINFORCE algorithm for policy learning was introduced by Williams in 1992 in the journal _Machine Learning_ @williams1992. It is one of the simplest policy gradient methods. The algorithm works by sampling trajectories of the agent's interactions with the environment, and using the observed rewards to compute an estimate of the policy gradient, which is then used to update the policy parameters $theta$ in a way that increases the probability of actions that lead to higher returns.

The loss,
$
  L = -1/T sum_(t=0)^T log(pi_theta (a_t | o_t)) dot G_t
$
where $T$ is the length of the trajectory, $G_T$ is the observed discounted return from time step $t$, and $pi_theta (a_t | o_t)$ is the probability of taking action $a_t$ given observation $o_t$ under the current policy parameters $theta$, is minimised using gradient descent after each episode. Intuitively, the loss function encourages the policy to increase the probability of actions that lead to higher returns, and decrease the probability of actions that lead to lower returns.

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




