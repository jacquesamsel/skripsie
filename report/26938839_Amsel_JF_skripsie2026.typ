#import "@preview/cetz:0.5.2"
#import "@preview/lilaq:0.6.0" as lq
#import "@preview/fletcher:0.5.8" as fletcher: diagram, edge, node, rect-at
#import "@preview/algorithmic:1.0.7" as algorithmic: algorithm-figure, style-algorithm
#import "@preview/latex-lookalike:0.1.4"
#import "@preview/neural-netz:0.3.0" as neural-netz: draw-network

#show: style-algorithm
#show: latex-lookalike.style-outline

// ============================================================
// Styling after the Stellenbosch University thesis class
// (stb-thesis.cls + imports.tex), see su_latex_template/.
// ============================================================

// Colours from imports.tex
// Switched on where the appendix starts: its level-1 heading is
// typeset without the "Chapter N" line above the title.
#let in-appendix = state("in-appendix", false)

#let oracle-colour = rgb("#8B8589") // running header text
#let rule-colour = rgb("#DCDCDC") // rule below the running header
#let link-colour = rgb("#000000") // gray!80!black for cites and URLs

#let argmax = $op("arg max", limits: #true)$
#let argmin = $op("arg min", limits: #true)$


// Only reference equations that are actually referenced in the text
#set math.equation(numbering: "(1)")

#show math.equation.where(block: true): it => {
  // Already processed: stop here to avoid recursion
  if it.has("label") and it.label == <eq-unnumbered> { return it }

  let referenced = (
    it.has("label") and query(ref.where(target: it.label)).len() > 0
  )

  if referenced {
    it
  } else [
    #counter(math.equation).update(n => n - 1)
    #math.equation(it.body, block: true, numbering: none)<eq-unnumbered>
  ]
}

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
  set par(justify: false, first-line-indent: 0pt)
  set text(weight: "regular")
  block(above: 0pt, below: 10pt, width: 100%, sticky: true)[
    // #if it.numbering != none [
    //   #align(right, text(size: 20pt, smallcaps[Chapter #counter(heading).display("1")]))
    //   #v(3pt)
    // ]
    //#line(length: 100%, stroke: 0.4pt)
    #v(70pt)
    #if (it.numbering != none and not in-appendix.at(it.location())) {
      text(size: 22pt, "Chapter " + numbering("1", ..counter(heading).at(it.location())))
    }


    #text(size: 26pt, smallcaps(it.body))
    #v(10pt)
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

#let todo = it => {
  set text(size: 12pt, weight: "regular", fill: rgb("#FF0000"))
  text([\[#it\]])
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


// --- Tables: booktabs rules as in the thesis class -----------
// \heavyrulewidth = 0.08em and \lightrulewidth = 0.05em at 12pt,
// \arraystretch = 1.2, \small body text, caption above the table.
#let heavy-rule = 0.96pt
#let light-rule = 0.6pt

#show figure.where(kind: table): set figure.caption(position: top)
#show figure.where(kind: table): set text(size: 11pt)

// A booktabs-style table: no vertical rules, a heavy rule at the top
// and bottom and a light rule under the header. `header` is the list of
// header cells (pass none for a table without one); everything else is
// passed straight through to `table`.
#let stb-table(header: none, ..args) = table(
  stroke: none,
  inset: (x: 0.6em, y: 0.45em),
  align: center + horizon,
  row-gutter: 0pt,
  table.hline(stroke: heavy-rule),
  ..if header != none {
    (table.header(..header), table.hline(stroke: light-rule))
  } else { () },
  ..args,
  table.hline(stroke: heavy-rule),
)
// --- Lists: \labelitemi is $\divideontimes$ ------------------
#set list(marker: text(size: 9pt, sym.circle.stroked.small), indent: 1em)
#set enum(indent: 1em)

// --- Table of contents: tocdepth = 3 (up to subsubsections) --
#set outline(depth: 4)

// --- Hyperlinks: black internal links, gray!80!black cites/URLs
#show link: set text(fill: link-colour)
#show cite: set text(fill: link-colour)

#align(center + horizon)[


  #set page(background: image("stb-thesis-frntp.pdf", width: 110%, height: 107%, fit: "stretch"))

  #title("Auxiliary learning for autonomous racing")

  by

  #text("Jacques Friedrich Amsel", size: 18pt)

  #v(1cm)

  #block(width: 400pt)[
    Report submitted in partial fulfilment of the requirements of the module
    Project (E) 448 for the degree Baccalaureus in Engineering in the Department of Electrical
    and Electronic Engineering at the University of Stellenbosch
  ]

  #v(1cm)

  *Study leader:* Prof. JC Schoeman

  #v(1cm)

  #datetime.today().display("[month repr:long] [year]")
]

#pagebreak()
#set page(numbering: "i")
#counter(page).update(1)
#set par(justify: true, first-line-indent: (amount: 1.5em, all: false))

= Acknowledgements

#pagebreak()

= Plagarism declaration

1. Plagiaat is die oorneem en gebruik van die idees, materiaal en ander intellektueleeiendom van ander persone asof dit jou eie werk is. _Plagiarism is the use of ideas, material and other intellectual property of another’s work and to present is as my own._
2. Ek erken dat die pleeg van plagiaat 'n strafbare oortreding is aangesien dit ‘n vorm van diefstal is. _I agree that plagiarism is a punishable offence because it constitutes theft._
3. Dienooreenkomstig is alle aanhalings en bydraes vanuit enige bron (ingesluit die internet) volledig verwys (erken). Ek erken dat die woordelikse aanhaal van teks sonder aanhalingstekens (selfs al word die bron volledig erken) plagiaat is. _Accordingly all quotations and contributions from any source whatsoever (including the internet) have been cited fully. I understand that the reproduction of text without quotation marks (even when the source is cited) is plagiarism._
4. Ek verklaar dat die werk in hierdie skryfstuk vervat, behalwe waar anders aangedui, my eie oorspronklike werk is en dat ek dit nie vantevore in die geheel of gedeeltelik ingehandig het vir bepunting in hierdie module/werkstuk of ‘n ander module/werkstuk nie. _I declare that the work contained in this assignment, except where otherwise stated, is my original work and that I have not previously (in its entirety or in part) submitted it for grading in this module/assignment or another module/assignment._

#v(1fr)
#table(
  columns: (1fr, 1fr),
  align: bottom + left,
  rows: (2.5cm, 2.5cm),
  [Student number #place(horizon + center)[#text("26938839", size: 24pt)]], [Signature],
  [Initials and surname #place(horizon + center)[#text("J.F. Amsel", size: 24pt)]],
  [Date #place(horizon + center)[#text(datetime.today().display("[day] [month repr:long] [year]"), size: 24pt)]],
)

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
  [$X ~ Y$], [Random variable $X$ is distributed according to distribution $Y$],
  [$X dot(~) Y$], [Random variable $X$ is approximately distributed according to distribution $Y$],
  [$N(y; mu; sigma^2)$],
  [Gaussian probability density function with mean $mu$ and variance $sigma^2$ with evaluation point $y$],
)

#pagebreak()

#set page(numbering: "1")
#counter(page).update(1)

#set heading(numbering: "1.")

= Introduction

== Background and motivation
Autonomous racing is a challenging problem in autonmous robotics: the high speed, tight control margins, and short time available to recover from bad decisions makes

== Problem statement & objectives




= Related literature

== Markov Decision Processes (MDPs)
A Markov Decision Process (MDP) is a mathematical framework for modelling problems in which an agent must make a series of decisions in an environment. At each time step $t$, the environment is in some state $s_t in cal(S)$, which is a _complete_ description of the environment at time $t$. The agent, however, only partially observes the environment; its observation $o_t in cal(O)$, where $cal(O)$ is the observation space, is a function of the state $s_t$. In this case, the environment is said to be _partially observable_, and the problem is formally a _partially observable_ MDP (POMDP). The information available in the state $s_t$ that is not available in the observation $o_t$ is called _privileged information_.

Based on its observation $o_t$, the agent chooses an action $a_t in cal(A)$. How the agent chooses is described by its _policy_, $pi$: a rule that tells the agent what to do in every situation it might encounter. One can think of the policy as the agent's strategy or rulebook: given the current observation, it returns the action the agent will take. For example, a policy for a self-driving car might say "if I observe a red light ahead, brake". The policy may also be stochastic, assigning a probability to each action rather than always picking the same one; we write $a_t ~ pi(dot | o_t)$ to mean the action is sampled from the policy. Note that we consider the policy to map observations to actions, compared to the classical mapping of states to actions in @bellman1957 and @kaelbling1998, since the agent cannot act on information it does not have. The policy is not part of the MDP itself: the policy describes the agent's behaviour, while the MDP describes the environment in which the agent operates.

Once the agent takes an action $a_t$, the environment responds by transitioning to a new state $s_(t+1) in cal(S)$, emitting a reward to the agent, $r_t in RR$, and a new observation $o_(t+1) in cal(O)$. The reward is a scalar value that indicates how good the outcome of the agent's action is. It is a function of the action taken, and both the current state and the successor state: $r_t = R(s_(t), a_t, s_(t+1))$. Note that the reward depends on the true state, not on the agent's observation of it.

The agent may experience a "life" within the same MDP many times over, and each time it does so is called an _episode_. An episode starts with the environment in some initial state $s_0 ~ rho_0$, and ends when the agent reaches a terminal state, or after a fixed number of time steps. The agent's objective is to learn a policy that maximises the expected _discounted return_, $EE_pi [G_0]$, where

$ G_t = sum_(i=t)^T gamma^(i-t) r_i $

is the discounted return from time step $t$, $T$ is the time step at which the episode terminates, and the expectation is taken over all trajectories that can arise from $rho_0$, the environment's dynamics, and the policy $pi$. The policy that achieves this maximum is called the _optimal policy_, $pi^*$.

The discount factor $gamma in [0, 1]$ controls how much the agent values future rewards relative to immediate ones. The return can be thought of as a weighted sum of all future rewards, in which a reward received $k$ steps from now is worth only $gamma^k$ times as much as the same reward received immediately. A $gamma$ close to $0$ makes the agent short-sighted, while a $gamma$ close to $1$ makes it value long-term outcomes almost as much as immediate ones.

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
Value functions are a central concept in reinforcement learning, providing a measure of how good it is for the agent to be in a particular state or to take a particular action.
The state-value function,
$
  V_pi (s) = EE_pi [G_t | S_t = s]
$ <state_value_function>

represents the expected discounted return $G_t$ the agent can achieve starting from state $s$ and following policy $pi$ thereafter. The action-value function,
$
  Q_pi (s, a) = EE_pi [G_t | S_t = s, A_t = a]
$ <action_value_function>
represents the expected discounted return the agent can achieve starting from state $s$, taking action $a$, and following policy $pi$ thereafter.
The advantage function,
$
  A_pi (s, a) = Q_pi (s, a) - V_pi (s)
$ <advantage_function>
measures the relative value of taking action $a$ in state $s$ compared to the average value of all actions in that state.

These state-value and action-value functions satisfy the Bellman equations, which express the relationship between the value of a state and the values of its successor states. @bellman1957 The Bellman equation for the state-value function is given by:

$
  V_pi (s) = EE_pi [R_{t+1} + gamma V_pi (S_{t+1}) | S_t = s]
$ <state_value_bellman_equation>

and the Bellman equation for the action-value function is given by:

$
  Q_pi (s, a) = EE_pi [R_{t+1} + gamma Q_pi (S_{t+1}, A_{t+1}) | S_t = s, A_t = a]
$ <action_value_bellman_equation>

These Bellman equations @state_value_bellman_equation and @action_value_bellman_equation provide a recursive relationship that allows the agent to update its value estimates based on the observed rewards and the estimated values of successor states.



== Reinforcement Learning (RL)
Reinforcement learning is a subfield of machine learning, where a policy $pi_theta$ is learned through an agent's interactions with an environment with the objective of maximising the expected discounted return under policy $pi_theta$, $EE_pi_theta [G_t]$, by varying the parameters $theta$ (i.e. finding the optimal policy $pi^*$)#footnote([The parameterisation restricts the search to the policy class
  $Pi_Theta = {pi_theta : theta in Theta}$, the set of policies the chosen
  model can represent. The optimal policy $pi^*$ need not lie in $Pi_Theta$:
  for example, if $pi_theta$ outputs a Gaussian over actions, it cannot
  represent an optimal policy that is multimodal or deterministic. In that
  case, RL can at best find the policy in $Pi_Theta$ with the highest
  expected return, $pi_(theta^*)$ with
  $theta^* = arg max_theta EE_(pi_theta) [G_0]$.]). This is done by sampling trajectories of the agent's interactions with the environment, and using the observed rewards to update the policy parameters $theta$ in a way that increases the probability of actions that lead to higher returns.

RL is distinct from supervised learning in that during training, the optimal or correct action is not known - the agent must explore the environment and learn from the consequences of its actions. It is also distinct from classical unsupervised learning methods in that there is a clear objective (maximising expected return) and feedback (rewards) to guide the learning process.

There exist two broad classes of RL algorithms: value-based methods and policy-based methods. Value-based methods learn a value function that estimates the expected return for each state or state-action pair ($hat(V)(s_t)$ or $hat(Q)(s_t, a_t)$ respectively), and derive a policy from this value function (for example, acting greedily in state $s$, choosing action $a = argmax_(a in cal(A)) hat(Q)(s, a)$). Policy-based methods learn a parameterised policy directly, without explicitly estimating a value function. We focus on policy-based methods in this report, as value-based methods are less suitable for continuous action spaces @lillicrap2015continuous and policy-based methods can natively learn stochastic policies, without tricks such as $epsilon$-greedy. @sutton2018

== Policy gradient methods

Policy gradient methods are a class of RL training algorithms that learn a policy $pi_theta$ with parameters $theta$ directly by maximising the expected return $EE[G_0]$ with respect to the policy parameters $theta$. Given a trajectory $tau = (s_0, o_0, a_0, r_0, s_1, o_1, a_1, r_1, dots, s_T, o_T, a_T, r_T) ~ p_theta$, where $p_theta$ is the probability of the trajectory when following the policy $pi_theta$, we intend to maximise the expected return with respect to the policy parameters $theta$:
$
  J(theta) = EE_(tau tilde p_theta) [G_0]
  = EE_(tau tilde p_theta) [sum_(t=0)^T gamma^t r_t]
  = integral p_theta (tau) G(tau) dif tau
$

Using the _log-derivative_ trick, $nabla_theta p_theta (tau) = p_theta (tau) nabla_theta log p_theta (tau)$, and assuming that the integral and derivative can be interchanged#footnote([This can be done only under certain regularity conditions not explored in this report, but generally if the functions are continuous and differentiable _almost_ everywhere, and the integral is finite.]),
the gradient of the expected return with respect to $theta$ is then
$
  nabla_theta J(theta)
  = nabla_theta integral p_theta (tau) G(tau) dif tau
  = integral nabla_theta p_theta (tau) G(tau) dif tau
  = integral p_theta (tau) nabla_theta log p_theta (tau) G(tau) dif tau
  #linebreak()
  = EE_(tau tilde p_theta) [nabla_theta log p_theta (tau) G(tau)]
$ <policy_gradient_theorem>

Considering that the probability of a trajectory can be factorised as
$
  p_theta (tau) = p(s_0) product_(t=0)^(T-1) underbrace(p(s_(t+1) | s_t, a_t), cal(P)) dot pi_theta (a_t | o_t) dot underbrace(p(o_t | s_t), cal(Z)) dot underbrace(p(r_t | s_t, a_t, s_(t+1), o_t), cal(R)),
$

since $p(s_0)$, $cal(P)$, $cal(Z)$ and $cal(R)$ do not depend on $theta$, their gradients vanish, so

$
  nabla_theta log p_theta (tau) = sum_(t=0)^(T-1) nabla_theta log pi_theta (a_t | o_t)
$

Then, the _policy gradient_ can be expressed as

$
  nabla_theta J(theta) = EE_(tau tilde p_theta) [sum_(t=0)^(T-1) nabla_theta log pi_theta (a_t | o_t) G(t)]
$

where $G_t = sum_(k=t)^(T-1) gamma^(k-t) r_k$ is the discounted reward-to-go. Replacing $G(tau)$ by $G_t$ leaves the expectation unchanged, since action $a_t$ cannot influence rewards $r_k$ with $k < t$, and it reduces variance#footnote([Strictly, the exact gradient of the discounted objective carries an extra factor $gamma^t$ on each term. Practical implementations omit it, which is the standard convention.]).

Generally, policy gradient methods use the following algorithm to learn the policy $pi_theta$:

#todo([Add algorithm table here.])
#figure(
  table(
    columns: 1,
    [

    ],
  ),
  caption: [Policy gradient algorithm for learning a policy $pi_theta$ with parameters $theta$.
  ],
)

=== REINFORCE

The REINFORCE algorithm for policy learning was introduced by Williams in 1992 in the journal _Machine Learning_ @williams1992. It is one of the simplest policy gradient methods: by sampling $N$ trajectories $tau^((i)) ~ pi_theta$, the policy gradient can be estimated in a Monte-Carlo fashion:

$
  hat(nabla_theta J)(theta) = 1/T sum_(t=0)^(T-1) log(pi_theta (a_t | o_t)) dot G_t
$

In order to run REINFORCE in an AutoGrad engine (such as PyTorch or TensorFlow), a loss function $cal(L)_"REINFORCE"$ is defined such that its gradient with respect to the policy parameters $theta$ is equal to the policy gradient estimate above. This loss function is given by:
$
  cal(L)_"REINFORCE" = -1/T sum_(t=0)^(T-1) log(pi_theta (a_t | o_t)) dot G_t
$

Although REINFORCE is simple to implement, it has several drawbacks. First, it has high variance in its gradient estimates, which can lead to slow convergence and instability during training. Second, it does not make use of a value function to estimate the expected return, which can further increase variance. Finally, it is an on-policy algorithm, meaning that it can only learn from trajectories generated by the current policy, which can limit exploration and learning efficiency (since it cannot train multiple epochs on the same rollout).

=== Proximal Policy Optimization (PPO)
PPO is a modern algorithm for policy learning introduced in 2017 by researchers at OpenAI @schulman2017ppo. It improves on REINFORCE in two ways. First, it is an actor-critic method: alongside the policy, it learns a value function $V_pi (s)$, which is used to compute an advantage estimate $hat(A)_t$ and so reduces the variance of the policy gradient estimate. Second, it optimises a _clipped surrogate objective_ that limits how far each update can move the policy. This prevents large, destructive steps and makes several epochs of updates on the same rollout possible.

Recall that the advantage function is the difference between the action-value and state-value functions:

$
  A^pi (s, a) = Q^pi (s, a) - V^pi (s),
$

where $V^pi (s) = EE_(a tilde pi)[Q^pi (s, a)]$ is the expected return of the
policy from state $s$. The advantage therefore measures how much better
(positive) or worse (negative) an action is than the policy's average action
in that state. In training, $hat(A)_t$ is computed from observed rewards and
the learned $V_phi$, for example with Generalized Advantage Estimation.


== Auxiliary learning in RL

In RL, the _primary task_ is to update a policy $pi_theta$ to maximises the expected discounted return $EE_pi_theta [G_t]$. Auxiliary learning is the practice of augmenting the primary task with additional _auxiliary tasks_ that are related to the primary task, and for which additional learning signals can be obtained. The auxiliary tasks may be supervised or unsupervised, and may involve predicting future states, rewards, or other quantities of interest.

Auxiliary learning builds on multi-task learning principles described in @caruana1997multitask. In some cases, it has been shown to improve generalization by using the training signals of related tasks as an inductive bias#footnote([Inductive bias is the set of assumptions a learning algorithm makes to predict outputs given inputs that it has not encountered before. @hullermeier2013inductive]): by learning to solve related tasks, the model is encouraged to learn representations that are useful for the primary task.

Previous work has shown that auxiliary learning can improve sample efficiency in supervised learning contexts #todo([citation needed]), and in reinforcement-learning contexts @jaderberg2017unreal, especially when the reward signal is sparse or delayed.

We shall discuss two formulations of auxiliary learning in RL: (1) auxiliary loss functions, and (2) auxiliary rewards. Some other formulations such as UNsupervised REinforcement and Auxiliary Learning (UNREAL) @jaderberg2017unreal, which uses unsupervised auxiliary tasks to improve representation learning, may seem different, but can be formulated in formulation (1).

=== 1st formulation (auxiliary loss)
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
  L_"total" = L_"policy" (A_t, G_t) + L_"aux" (S_t, hat(S_t))
$

Then, during a gradient update step, the parameters $theta$ are updated using information from both loss heads.

$
  theta_(t+1) = theta_(t) + alpha dot Delta_theta L_"total" =
$

=== 2nd formulation (auxiliary rewards)
Auxiliary learning can also be formulated as an additional task the agent receives rewards for performing (well). This formulation has the drawback that gradient information is discarded.

== Loss scaling

When composing the $L_"total"$, the question naturally arises: what should be the values of the weights ${w_1, ..., w_N}$? Since the values cannot simply be learnt by gradient descent (they would simply shrink to 0 or go negative to lower $L_"total"$), we must use another technique.

=== Hyperparameter tuning

Naïvely, one may empirically estimate the optimal weights using hyperparameter tuning tools such as Optuna @akiba2019optuna. However, when it is expensive to train a model, this method of search quickly becomes impractical, since every candidate set of weights requires its own training run.

Hyperparameter tuners differ in how they choose which weights to try next. Grid search evaluates every combination on a fixed $N$-dimensional grid, so its cost grows exponentially with the number of weights $N$. Random search samples configurations at random and is often more efficient than grid search, because usually only a few hyperparameters matter much @bergstra2012random. Bayesian optimisation methods go further by building a model of how the validation score depends on the hyperparameters and using it to choose promising candidates. Examples include Gaussian-process-based optimisation @snoek2012practical and the tree-structured Parzen estimator (TPE) @bergstra2011algorithms, which is the default sampler in Optuna.

A second way to cut cost is to stop unpromising trials early. Methods such as Hyperband @li2018hyperband and its asynchronous variant ASHA @li2020asha give each trial a small budget and only continue the best-performing ones. However, this method may kill trials that perform more exploration early on.

Even with these savings, each trial still involves training a model, and the number of trials needed grows with the number of loss terms $N$. For multi-task models that are expensive to train, this motivates methods that learn the weights during training instead.

=== Uncertainty weighting
Two kinds of uncertainty can be modelled in a model's predictions @kendall2017uncertainties:
- _Epistemic_ uncertainty: the model is unsure because it hasn't been trained on enough data. More data reduces epistemic uncertainty.
- _Aleatoric_ uncertainty: the data itself is noisy or incomplete, so even a perfect model can't predict exactly. In this case, more training data doesn't help.

Aleatoric uncertainty has two forms:
- _Data-dependent_ or _Heteroscedastic_: the noise changes from input to input (e.g. a blurry image is harder to make inference from than a clear one).
- _Task-dependent_ or _Homoscedastic_: the noise is the same for every input and depends only on the task ($L_1, ..., L_N$).

Kendall et al. propose a solution to determining the weights ${w_1, ..., w_N}$ problem by modelling the homoscedastic (task-dependent) uncertainty only.

Instead of formulating the prediction for task i, $hat(y_i) = f_i (bold(x))$, as a point estimate, it is modelled as a Gaussian with mean $f_i (x)$ and variance $sigma_i^2$:
$
  Y_i tilde.dot p(y_i | f_i (x)) = N(y_i; f_i (x); sigma_i^2)
$

The negative log-likelihood of this Gaussian probability density function evaluated at the true value $y_i$ is then the loss value for task i:

$
  L_i = -log p(y_i | f_i (x)) = 1/(2 sigma_i^2) ||y_i - f_i (x)||^2 + log sigma_i
$

Then, assuming the tasks are independent, the total loss is the sum of the individual losses:
$
  L_"total" = sum_(i=1)^N L_i = sum_(i=1)^N (1/(2 sigma_i^2) ||y_i - f_i (x)||^2 + log sigma_i)
$

Of course, in reality, the tasks are not independent, but this method has been shown to work well in practice. The log-variance $log sigma_i$ is a learnable parameter that is updated during training, allowing the model to learn the optimal weights for each loss term.

=== Huber loss
The Huber loss (with parameter $beta$ or in some literature $k$) is a loss function that is less sensitive to outliers compared to the standard Mean Squared Error (MSE) loss @huber1964robust. It is defined as:

$
  cal(L)^beta (y, hat(y)) = cases(
    1/2 (y - hat(y))^2 "if" |y - hat(y)| <= beta,
    beta |y - hat(y)| - 1/2 beta^2 "otherwise"
  )
$

In our case, since we have various loss terms, each relating to a different task where the scale of $y$ differs, we must carefully choose the parameter $beta$ and scale each loss term appropriately.

Rewriting the loss to $cal(L)^beta (y/sigma, hat(y)/sigma)$ allows us to reduce the model's bias towards learning tasks with larger scales, however, the Huber loss is not scale-invariant, so we must choose $beta$ carefully:

$
  cal(L)^beta (y/sigma, hat(y)/sigma) = (cal(L)^(beta sigma) (y, hat(y))) / sigma^2
$

@huber_loss_scale_reparameterisation details the proof for this scale reparameterisation of the Huber loss, and shows that the reparameterised $beta$ is proportional to the scale of the data, $sigma$.

In actuality, PyTorch's implementation of the Huber loss (`smooth_l1_loss`) uses a rescaled definition, $(cal(L)^beta (y, hat(y))) /beta$, to prevent the $beta$ parameter from affecting the gradient in the linear region.





= System overview

// Add a subsystem diagram

== RoboRacer

RoboRacer (formerly F1TENTH) is an open-source 1/10th scale race car platform. It is an open standard used for learning and research in the field of autonomous racing, and with over 1000 related publications, it is widely used in the research community. @roboracer_homepage The RoboRacer race car (@roboracer_car) is a small vehicle  governed by RoboRacer's rules @roboracer_rules, which includes specifications on the vehicle's dimensions, weight, and performance. During training, this vehicle is simulated with a wheelbase of $324 "mm"$, a track width of $236 "mm"$, and a maximum steering angle of $30 degree$ . The vehicle is powered by an electric motor and is equipped with a LiDAR sensor and camera for perception, as well as an onboard computer for processing and decision-making.


// ------------------------------------------------------------------
// RoboRacer vehicle, plan view.
//
// The body outline is traced from the vehicle silhouette in
// `Frame 42.svg`.  The pixel coordinates of that tracing are mapped
// onto the real vehicle dimensions by `fx()` and `fy()`, so the
// overall length, overall width, wheelbase and track width of the
// drawing are exactly the values it is annotated with.
// ------------------------------------------------------------------
#let roboracer-car(show-dimensions: true) = {
  // -- vehicle geometry [mm] ---------------------------------------
  let o-len = 568 // overall length  (rules: 568 mm +/- 10%)
  let o-wid = 296 // overall width   (rules: 296 mm +/- 10%)
  let wb = 324 // wheelbase       (AutoDrive vehicle settings)
  let tw = 236 // track width     (AutoDrive vehicle settings)
  let d-max = 30deg // steering limit  (AutoDrive vehicle settings)

  // -- tracing -> vehicle coordinates ------------------------------
  // Landmarks in the tracing: the body runs from 32 px (rear) to
  // 346.5 px (front), its centreline sits at 103.875 px, and the wheel
  // hubs are at 85 px and 290 px, 150 px apart and 74 px long.
  //
  // The scale factor `k` is taken from the wheelbase, which also puts
  // the traced track width within half a millimetre of the simulated
  // one: the chassis, its suspension and the wheels therefore line up
  // exactly.  At that scale the traced body is 71 mm shorter than the
  // overall length, so the two bumper blocks -- everything outside
  // 71 px and 311 px, which carries no suspension detail -- are
  // stretched lengthwise to make up the difference.
  let cx = (85 + 290) / 2
  let cy = 103.875
  let k = wb / (290 - 85)
  let k-rear = (o-len / 2 - (cx - 71) * k) / (71 - 32)
  let k-front = (o-len / 2 - (311 - cx) * k) / (346.5 - 311)
  let fx(x) = {
    if x <= 71 { (71 - cx) * k - (71 - x) * k-rear } else if x >= 311 {
      (311 - cx) * k + (x - 311) * k-front
    } else { (x - cx) * k }
  }
  let fy(y) = (cy - y) * k

  // The wheels are not part of the traced outline: they sit on the
  // simulated wheelbase and track, which is where the tracing has
  // them, and are as wide as the overall width allows.
  let r-w = 37 * k // wheel radius (half a traced wheel)
  let w-w = o-wid - tw // tyre width: the wheels set the overall width

  let s = 1 / 45 // canvas units per millimetre
  let p(x, y) = (x * s, y * s)

  // -- palette and strokes -----------------------------------------
  let c-wheel = luma(90%)
  let c-part = luma(96%)
  let outline = (paint: black, thickness: 0.6pt)
  let thin = (paint: luma(25%), thickness: 0.4pt)
  let hair = (paint: luma(5%), thickness: 0.35pt)
  let dashed = (paint: luma(35%), thickness: 0.4pt, dash: "dashed")
  let arrow = (start: ">", end: ">", scale: 0.45, fill: luma(25%))

  // -- key, built here so that cetz's `grid` does not shadow the
  // standard one ---------------------------------------------------
  let item(n, body) = ([#n.], body)

  cetz.canvas({
    import cetz.draw: *
    set-style(stroke: outline, content: (padding: 0pt))

    let lbl(body) = text(size: 7.5pt, body)

    // -- dimension helpers (arguments in mm) -----------------------
    let dim-h(x1, x2, y, ey, body) = {
      line(p(x1, ey), p(x1, y), stroke: hair)
      line(p(x2, ey), p(x2, y), stroke: hair)
      line(p(x1, y), p(x2, y), stroke: thin, mark: arrow)
      content(p((x1 + x2) / 2, y + 7), anchor: "south", lbl(body))
    }
    let dim-v(y1, y2, x, ex, body) = {
      line(p(ex, y1), p(x, y1), stroke: hair)
      line(p(ex, y2), p(x, y2), stroke: hair)
      line(p(x, y1), p(x, y2), stroke: thin, mark: arrow)
      content(p(x - 7, (y1 + y2) / 2), anchor: "south", angle: 90deg, lbl(body))
    }

    // -- numbered callout ------------------------------------------
    let tag(n, x, y) = {
      circle(p(x, y), radius: 15 * s, fill: white, stroke: thin)
      content(p(x, y), text(size: 7pt, [#n]))
    }

    // -- size envelope ---------------------------------------------
    if show-dimensions {
      rect(p(-o-len / 2, -o-wid / 2), p(o-len / 2, o-wid / 2), stroke: dashed)
    }

    // -- wheels ----------------------------------------------------
    // drawn first, so that the body outline runs over them
    let wheel(x, y, angle, fill: c-wheel, stroke: none) = {
      group({
        translate(p(x, y))
        rotate(angle)
        rect(p(-r-w, -w-w / 2), p(r-w, w-w / 2), fill: fill, stroke: stroke)
      })
    }
    for m in (-1, 1) {
      wheel(-wb / 2, m * tw / 2, 0deg)
      wheel(wb / 2, m * tw / 2, 0deg)
    }

    // -- body outline ----------------------------------------------
    // One half of the tracing, mirrored about the centreline by `m`.
    // Each outline runs from the centreline, around the half it
    // describes, and back to the centreline; the edge the tracing puts
    // *along* the centreline is left out, so the two halves join into
    // a single silhouette.
    let body(m) = {
      let q(x, y) = (fx(x) * s, m * fy(y) * s)

      // front bumper
      merge-path({
        line(q(71, cy), q(71, 34), q(47.5, 34))
        bezier(q(47.5, 34), q(32, 45), q(37, 34), q(32, 41))
        line(q(32, 45), q(32, cy))
      })

      // chassis tub, from the front shock tower back to the side pod
      merge-path({
        line(
          q(71, cy),
          q(71, 62),
          q(74, 43.5),
          q(92, 43.5),
          q(94, 88.5),
          q(101.5, 86),
          q(110.5, 74.5),
          q(110.5, 62),
          q(114.5, 58),
          q(227.5, 58),
        )
        bezier(q(227.5, 58), q(255, 77), q(233, 58), q(243.585, 70.6678))
        bezier(q(255, 77), q(288, 91), q(267.242, 83.791), q(275.113, 85.5327))
        line(q(288, 91), q(288, cy))
      })

      // rear suspension tower and rear bumper
      merge-path({
        line(
          q(288, cy),
          q(288, 90.5),
          q(273.5, 85),
          q(275.5, 44.5),
          q(298.5, 44.5),
          q(305.5, 94),
          q(311, 85),
          q(311, 60.5),
          q(323.5, 60.5),
          q(330.5, 42),
          q(340, 42),
        )
        bezier(q(340, 42), q(346.5, cy), q(343.507, 50.3434), q(344.779, 66.1226))
      })
    }
    body(1)
    body(-1)

    // -- on-board hardware -----------------------------------------
    let part(x1, x2, hw, radius: 4) = {
      rect(p(x1, -hw), p(x2, hw), fill: c-part, stroke: thin, radius: radius * s)
    }
    tag(1, 240, 0)
    circle(p(92, 0), radius: 34 * s, fill: c-part, stroke: thin)
    tag(2, 92, 0)
    part(8, 44, 18)
    tag(3, 26, 0)

    // -- dimensions ------------------------------------------------
    if show-dimensions {
      dim-v(-o-wid / 2, o-wid / 2, -345, -o-len / 2, [296mm #sym.plus.minus max])
      dim-v(-tw / 2, tw / 2, 345, o-len / 2, [Track width])
      dim-h(-o-len / 2, o-len / 2, -205, -o-wid / 2, [568mm max])
      dim-h(-wb / 2, wb / 2, 200, o-wid / 2, [Wheel base])

      // steering limit, drawn on the near front wheel
      let (wx, wy) = (wb / 2, tw / 2)
      let (ri, ro) = (48, 52)
      line(p(wx - ri, wy), p(wx + ro, wy), stroke: dashed)
      line(
        p(wx - ri * calc.cos(d-max), wy - ri * calc.sin(d-max)),
        p(wx + ro * calc.cos(d-max), wy + ro * calc.sin(d-max)),
        stroke: thin,
      )
      arc(
        p(wx, wy),
        start: 0deg,
        stop: d-max,
        radius: 40 * s,
        anchor: "origin",
        stroke: thin,
        mark: (end: ">", scale: 0.4, fill: luma(25%)),
      )
      line(
        p(wx + 42 * calc.cos(d-max / 2), wy + 42 * calc.sin(d-max / 2)),
        p(wx + 72, wy + 56),
        stroke: hair,
      )
      content(p(wx + 76, wy + 56), anchor: "west", lbl[$delta_max$])
    }
  })
}

#figure(
  caption: [
    Sketch of the RoboRacer vehicle: a 1:10 scale car on a Traxxas chassis
  ],
  roboracer-car(show-dimensions: true),
) <roboracer_car>



= Simulation environments

== F1Tenth Gym

The F1Tenth Gym is a python package that provides an environment for training and evaluating reinforcement learning algorithms.

== AutoDrive, Unity, and MLAgents
#figure(
  columns(2)[
    #image("figures/autodrive_isometric_birds_eye.png", width: 200pt, height: 175pt)
    #colbreak()
    #image("figures/autodrive_isometric_close_up.png", width: 200pt, height: 175pt)
  ],
  caption: "AutoDrive-insired Unity environment, showing the RoboRacer vehicle, its LIDAR rays, and forward track prediction sampling points.",
) <track_rendering>

== Track generation

During model training, having a variety of tracks is important to prevent overfitting to a single track. This improves generalisation to unseen tracks, allowing the model to learn a more robust policy.

For this purpose, a track generator was implemented in C\# in Unity to procedurally generate tracks. The track generator takes the following parameters as input: $R$ - the track radius, $n$ - the number of points to generate, $theta_max$, the maximum turn angle in a single step, $rho$ - the mean-reversion factor, $s$ - the mean-reversion exponent, $phi_max$ - the maximum heading offset, and $q$ - the probability of flipping the driving direction. The track generator outputs a list of points that define the track.

#algorithm-figure(
  "Random Closed Track",
  vstroke: .5pt + luma(200),
  {
    import algorithmic: *
    Procedure(
      "Generate-Walk",
      ($n$, $R$, $theta_"max"$, $rho$, $s$, $phi_"max"$, $q$),
      {
        Comment[Initialise the walk on the guide circle]
        Assign[$L$][$2 pi R / n$]
        Assign[$P_0$][$(R, 0)$]
        Assign[$h$][$0$]
        LineBreak
        Comment[Random walk with a mean-reverting heading offset]
        For(
          $i = 1$ + [ to ] + $n$,
          {
            Assign[$r$][$rho + (1 - rho)(i / n)^s$]
            Assign[$u$][$"Uniform"(-theta_"max", theta_"max")$]
            Assign[$h$][$"clamp"((h + u)(1 - r), -phi_"max", phi_"max")$]
            Assign[$alpha$][$(2 pi i) / n + pi / 2 + h$]
            Assign[$P_i$][$P_(i-1) + L (cos alpha, sin alpha)$]
          },
        )
        LineBreak
        Comment[Spread the closing error evenly over the lap]
        Assign[$g$][$P_n - P_0$]
        For(
          $i = 0$ + [ to ] + $n - 1$,
          {
            Assign[$Q_i$][$P_i - (i / n) g$]
          },
        )
        LineBreak
        Comment[Randomly flip the driving direction, keeping $Q_0$ fixed]
        If(
          $"Uniform"(0, 1) < q$,
          {
            Assign[$(Q_1, dots, Q_(n-1))$][$(Q_(n-1), dots, Q_1)$]
          },
        )
        Return[$Q$]
      },
    )
  },
)


#figure(
  caption: "Track generation",
  cetz.canvas({
    import cetz.draw: *
    circle((0, 0), radius: 4, stroke: (paint: luma(60%), dash: "dashed"))
    // dots: roughly trace the guide circle for 3/4 of a revolution, with a
    // little radial jitter so it reads as a walk rather than a perfect ring
    let n = 7
    let sweep = 250deg
    let jitter = (0, 0.3, -0.2, 0.4, -0.3, 0.2, -1.5)
    let angle_at = idx => sweep * (idx / (n - 1))
    let dots = range(n).map(idx => {
      let angle = angle_at(idx)
      let r = 4 + jitter.at(idx)
      (r * calc.cos(angle), r * calc.sin(angle))
    })

    let last_point = dots.at(n - 1)

    // Where dot 7 would have landed had the walk stayed on the guide circle,
    // and the unit tangent of the circle at that angle
    let last_angle = angle_at(n - 1)
    let guide_point = (4 * calc.cos(last_angle), 4 * calc.sin(last_angle))
    let tangent_dir = (-calc.sin(last_angle), calc.cos(last_angle))

    // Cone of headings reachable from dot 7, i.e. the support of
    // $u ~ "Uniform"(-theta_max, theta_max)$ about the tangent direction
    let theta_max = 60deg
    arc(
      last_point,
      start: last_angle + 90deg - theta_max,
      stop: last_angle + 90deg + theta_max,
      radius: 2.6,
      anchor: "origin",
      mode: "PIE",
      fill: color.transparentize(luma(89.8%), 50%),
      stroke: none,
    )

    for idx in range(n) {
      if idx != 0 {
        line(dots.at(idx - 1), dots.at(idx))
      }
    }

    let half_length = 2.8
    let along = (base, t) => (
      base.at(0) + t * tangent_dir.at(0),
      base.at(1) + t * tangent_dir.at(1),
    )
    // Chevron denoting the two lines as parallel
    let parallel_mark = base => line(
      along(base, -1.5),
      along(base, -1.1),
      mark: (end: ">", scale: 0.8),
      stroke: 0.8pt,
    )

    // Dotted tangent at the un-jittered position of dot 7
    circle(
      guide_point,
      radius: 8pt,
      stroke: (paint: luma(60%), dash: "dashed"),
    )
    line(
      along(guide_point, -half_length),
      along(guide_point, half_length),
      stroke: (dash: "dotted"),
    )
    parallel_mark(guide_point)

    // Its parallel, shifted inwards to cross through dot 7
    line(
      along(last_point, -half_length),
      along(last_point, half_length),
      stroke: (dash: "dotted"),
    )
    parallel_mark(last_point)

    for idx in range(n) {
      circle(dots.at(idx), radius: 8pt, fill: black)
      content(dots.at(idx))[#text(size: 12pt, fill: white)[#(idx + 1)]]
    }
  }),
)



Then, a Catmull-Rom spline is fitted to the points to create a smooth track centerline. In order to generate the inner and outer boundaries of the track, points are sampled along the centerline to generate a polygonal approximation of the track. The inner and outer boundaries are then generated by insetting/outsetting the centerline polygon by a fixed distance using the Clipper2 library @clipper2, which extends the Vatti polygon clipping algorithm @vatti1992.

Once we have the inner and outer boundaries of the track, generating a mesh by extruding a circle or square along the splines is straightforward in Unity. An example track is shown in @track_rendering.

= Auxiliary heads

Several auxiliary heads were implemented to predict the following quantities:

#figure(
  stb-table(
    columns: (1.2fr, 0.5fr, 3fr),
    align: (center, center, left),
    header: ([Auxiliary head(s)], [Unit], [Description]),
    [$v_f$],
    [m/s],
    [The car's forward velocity],
    [$v_l$],
    [m/s],
    [The car's lateral velocity (positive is to the left)],
    [$omega$],
    [rad/s],
    [The car's angular velocity around the verical axis (postive is counter-clockwise)],
    [$v_(s,x)$],
    [m/s],
    [The car's wheel slip velocity per wheel $x in {"LF", "RF", "LB", "RB"}$],
    [$kappa_d$],
    [$1/m$],
    [Reciprocal #footnote("The reciprocal of the radius of curvature is used to prevent undefined values when the track is straight.") of the radius of curvature of the track at various points $d$ along the track ahead of the car, $d in {0.5, 1.0, ..., 8.0} m$],
  ),
  caption: "Auxiliary heads implemented to predict the car's forward velocity $v_f$, lateral velocity $v_l$, and angular velocity $omega$.",
)

== The model

The model is a feedforward neural network. Its input is a stack of the 50 most
recent LIDAR scans (101 rays each), plus the previous action (steering and
throttle). Since the network has no recurrent state, the stacked scans are the
only source of temporal information.

The scans are processed by four 1D convolutional layers with ReLU activations.
The convolutions slide along the ray axis and treat the 50 time steps as input
channels, so the first layer combines the whole history at each angular
position and turns it into a set of learned feature channels. The remaining
three layers work on these features and only add spatial context along the ray
axis. The output is flattened, concatenated with the
previous action, and passed through three fully connected layers (128, 72 and
64 units) with ReLU activations and a final layer normalization.

The 64-dimensional output is shared by all heads. The last layer ("out" in
@neural_net_architecture) is a linear layer that produces the outputs of every head at once:
4 for the policy (mean and scale for steering and throttle), 1 for the value
estimate, and 27 for the auxiliary prediction targets, which are only used
as training signals.

#[

  #let get-conv1d-height = channels => {
    return channels / 10
  }
  #let get-fc-height = size => {
    return size / 30
  }
  #let main-net = draw-network(
    (
      (
        type: "input",
        image: rotate(90deg)[#image("../results/lidar_input.png", width: 4cm, height: 4cm)],
        label: "LIDAR history",
        channels: (101, 50),
      ),
      (
        type: "conv",
        widths: (0.5,),
        height: get-conv1d-height(50),
        depth: 4,
        show-relu: true,
        channels: ("", 50),
        legend: "Conv1d",
        name: "conv1d",
      ),
      (
        type: "conv",
        widths: (0.5,),
        height: get-conv1d-height(32),
        depth: 4,
        show-relu: true,
        channels: ("", 32),
        name: "conv1d",
        offset: 0.5,
      ),
      (
        type: "conv",
        widths: (0.5,),
        height: get-conv1d-height(16),
        depth: 4,
        show-relu: true,
        channels: ("", 16),
        name: "conv1d",
        offset: 0.5,
      ),
      (
        type: "conv",
        widths: (0.5,),
        height: get-conv1d-height(16),
        depth: 4,
        show-relu: true,
        channels: ("", 16),
        name: "conv1d",
        offset: 0.5,
      ),
      (
        type: "custom",
        width: 0.4,
        height: 4,
        depth: 0.5,
        label: "Flatten",
        name: "flat",
        offset: 1.5,
        legend: "Flatten",
        fill: green,
      ),
      (type: "concat", width: 0.4, height: 4, depth: 0.5, label: "Concat", name: "cat", offset: 1, fill: teal),
      (type: "fc", channels: (128,), offset: 0.5, name: "fc1", height: get-fc-height(128), label: "fc1"),
      (type: "fc", channels: (72,), name: "fc2", offset: 0.5, height: get-fc-height(72), label: "fc2"),
      (type: "fc", channels: (64,), offset: 0.5, name: "fc3", height: get-fc-height(64), label: "fc3"),
      (type: "fc", channels: (27 + 4 + 1,), offset: 0.5, name: "fc4", height: get-fc-height(32), label: "out"),
    ),
    connections: (),
    show-legend: true,
    legend-title: "Layers",
    scale: 100%,
    stroke-thickness: 1,
    depth-multiplier: 0.3,
  )

  #figure(
    caption: "Neural network architecture",
    cetz.canvas(length: 1cm, {
      import cetz.draw: *
      content((0, 0), main-net, anchor: "north-west", name: "main")
      // Second input: the previous action, concatenated with the flattened
      // conv features. Coordinates are in cm, measured from the top-left of
      // the network image; (8.95, -1.28) is the top face of the "Concat" block.
      content((8.95, 0), text(size: 8.5pt, weight: "bold")[Previous action], anchor: "south", name: "act")
      line((8.95, -0.1), (8.95, -1.28), mark: (end: ">"), stroke: (paint: rgb("#0f4d52"), thickness: 1pt))
    }),
  )<neural_net_architecture>
]
= Experiments & results

== Baseline performance <baseline_model>

The baseline model was trained in 300 PPO steps, experiencing 512 frames on each of 48 parallel agents, for a total of 16'23" training time per step (i.e. 81.9 hours of simulation time). Every 10 steps (2.73h of simulation time), the model weights were logged to allow inspection of learning characteristics, along with per-step statistics on performance.

=== Auxiliary Head Prediction

Despite not being trained with the explicit task of auxiliary prediction, we are able to extract a proxy to examine the feature representation in the model.




== Normalisation of ego-agent privledged information

Prior to applying auxiliary learning, the privileged information must be normalised. The auxiliary loss is a sum over the individual prediction targets, so a target with a larger numerical range contributes larger errors and gradients, and can dominate the shared representation at the expense of the others. Training with unnormalised targets makes hyperparameter tuning @vanhasselt2016, and training more difficult @lecun1998.

Kendall et al. proposes a solution to this problem by learning a log-variance $log sigma_i$ for each loss $L_i$ @kendall2018multitask-cvpr. Because it is expensive to perform hyperparameter searches across the loss weights ${w_1, ..., w_N}$,.


_Epistemic uncertainty_ is the uncertainty that comes as a result of lack of training data.

_Aleatoric uncertainty_ is that which cannot be reduced

An alternative method is @chen2017gradnorm, which dynamically scales the weights of each loss term to balance the $||delta_W L_i||_2$


= What I did
- *Car always going full throttle + full steering*: This is because tanhnormal saturates at 1, so the model cannot learn when the output is close to 1 or -1. This is a problem because the car is always going full throttle, and the steering angle is often close to 1 or -1. The model cannot learn to output values further away. So, the scale of weights & biases was changed to start in the center
- *LIDAR angle pointing up, causing large lidar values input* - increase wall height, mask "miss" rays to 0
- *Huber loss is invariant* to scale if the parameter beta is updated:
$
  L_beta (x/alpha, hat(x)/alpha) = (L_(alpha*beta) (x, hat(x))) / alpha^2
$

= Conclusions and recommendations
#pagebreak()
#bibliography("./hyagriva.yaml", style: "ieee", title: [Bibliography])

#in-appendix.update(true)

// The appendix chapter itself is unnumbered; its sections are
// "Appendix A", "Appendix B", ... and deeper levels "A.1", "A.1.1".
// A pattern string cannot be used here: in "Appendix A" Typst would
// read the leading "A" as a counting symbol too.
// References to appendix sections read "Appendix A", not
// "Section Appendix A".
#set heading(supplement: none)

#set heading(numbering: (..n) => {
  let nums = n.pos()
  if nums.len() == 1 {
    ""
  } else if nums.len() == 2 {
    "Appendix " + numbering("A", nums.at(1))
  } else {
    numbering("A.1.1", ..nums.slice(1))
  }
})

= Appendix
== Huber Loss Scale Reparameterisation <huber_loss_scale_reparameterisation>
$
  cal(L)^beta (y/alpha, hat(y)/alpha) = cases(
    1/2 (y/alpha - hat(y)/alpha)^2 "if" |y/alpha - hat(y)/alpha| <= beta,
    beta |y/alpha - hat(y)/alpha| - 1/2 beta^2 "otherwise"
  )
  #linebreak()
  = cases(
    1/(2 alpha^2) (y - hat(y))^2 "if" |y - hat(y)| <= alpha beta,
    beta / alpha |y - hat(y)| - 1/2 beta^2 "otherwise"
  )
  #linebreak()
  = 1/(alpha^2) cases(
    1/2 (y - hat(y))^2 "if" |y - hat(y)| <= alpha beta,
    alpha beta |y - hat(y)| - 1/2 (alpha beta)^2 "otherwise"
  )
  #linebreak()
  = (cal(L)^(alpha*beta) (y, hat(y)))/alpha^2
  #h(1cm)
  qed
$

== Auxiliary Head Regression Results
#set page(flipped: false)
#let aux_head_regression_scores = csv("../results/aux_head_regression_scores.csv")
#figure(
  stb-table(
    columns: 4,
    align: (left, center, center, center),
    header: ([Auxiliary target], [$R^2$ score], [MAE], [$sigma_x$]),

    ..aux_head_regression_scores
      .slice(1)
      .sorted(key: row => row.at(1), by: (a, b) => b < a)
      .map(row => (
        [#row.at(0)],
        ..row.slice(1).map(val => [#calc.round(float(val), digits: 4)]), // Number columns rounded
      ))
      .flatten(),
  ),
  caption: "Regression scores for the auxiliary heads, trained on the pure PPO model's hidden layer output.",
)
