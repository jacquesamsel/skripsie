#import "@preview/cetz:0.5.2"
#import "@preview/lilaq:0.6.0" as lq
#import "@preview/fletcher:0.5.8" as fletcher: diagram, edge, node, rect-at
#import "@preview/algorithmic:1.0.7" as algorithmic: algorithm-figure, style-algorithm
#import "@preview/latex-lookalike:0.1.4"
#import "@preview/neural-netz:0.3.0" as neural-netz: draw-network
#import "@preview/simple-plot:1.1.0": hline, note, plot, vline

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


  #block(title("Backseat driver: Auxiliary learning for autonomous racing"), width: 400pt)

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

= Notation
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
  [$"Var"(X)$], [Variance of random variable $X$],
  [$rho_0 (s)$], [Initial state distribution],
  [$X ~ Y$], [Random variable $X$ is distributed according to distribution $Y$],
  [$X dot(~) Y$], [Random variable $X$ is approximately distributed according to distribution $Y$],
  [$RR$], [The set of real numbers],
  [$EE[X]$], [Expected value of random variable $X$],
  [$EE_(x~p)[f(x)]$], [Expected value of function $f(x)$ when x is distributed according to p],
  [$N(y; mu; sigma^2)$],
  [Gaussian probability density function with mean $mu$ and variance $sigma^2$ with evaluation point $y$],
)

= Acronyms and abbreviations

#let acronyms = (
  ("LiDAR", "Light Detection and Ranging"),
  ("RL", "Reinforcement Learning"),
  ("MDP", "Markov Decision Process"),
  ("POMDP", "Partially Observable Markov Decision Process"),
  ("PPO", "Proximal Policy Optimization"),
  ("MSE", "Mean Squared Error"),
  ("RMSE", "Root Mean Squared Error"),
  ("MAE", "Mean Absolute Error"),
)

#table(
  columns: (1.5fr, 2fr),
  gutter: 8pt,
  stroke: none,
  ..acronyms.sorted(key: item => item.at(1)).flatten()
)



#pagebreak()

#set page(numbering: "1")
#counter(page).update(1)

#set heading(numbering: "1.")

= Introduction

== Background and motivation
Autonomous racing is a challenging problem in autonmous robotics: the high speed, tight control margins, and short time available to recover from bad decisions makes for a demanding testbed to develop and evaluate autonomous driving algorithms. Studying autonomous racing is a proxy for development of autonomous driving algorithms, which have the potential to reduce severe and fatal accidents (e.g. severe lane-departure accidents @olofsson2021crashdatabases), improve traffic flow @VanDriel2010congestion, and reduce emissions @ignlinski2017autonomous-vehicles-ghg.

Generally, there exist two broad approaches to autonomous driving: end-to-end learning, where a model is trained to map sensor inputs directly to control outputs, and modular pipelines, where the problem is broken down into subproblems such as perception, planning, and control. End-to-end learning has the advantage of being able to learn a policy directly from data, without requiring hand-engineered features or intermediate representations. However, it can be difficult to interpret and debug, and may require large amounts of data to learn effectively. Modular pipelines, on the other hand, can be more interpretable and easier to debug, but may require more domain knowledge and engineering effort to design and tune @chen2020interpretableendtoendurbanautonomous.

Auxiliary learning is a technique involving training a model to perform additional (auxiliary) tasks alongside the primary task, in the hope that these tasks will help the model learn representations that are useful for the primary task. In some cases, it can be used to improve the performance of reinforcement learning models by providing additional supervisory signals during training that improve the model's learned representations @rafiee2022makesusefulauxiliarytasks, while also aiding in interpretability of the learned representations  @chen2020interpretableendtoendurbanautonomous.

== Problem statement & objectives

An end-to-end RL agent that drives from LiDAR alone has to learn a representation of privledged information it can’t directly observe in the real world (e.g. its own velocity and slip, the curvature ahead, and its opponent's location in the case of head-to-head (H2H) racing). The agent may struggle to learn these representations early in training, when it has not yet learned to drive well enough to explore the environment effectively, which can lead to slow convergence.

However, since the privledged information is available in simulation, we can use auxiliary learning to provide additional supervisory signals to the agent during training, which may help it learn better representations of the privledged information and improve its performance or training speed.

The objectives of this Skripsie are to (a) select an appropriate simulation environment for autonomous racing, (b) implement a baseline end-to-end RL agent that drives from LiDAR alone, (c) gain an understanding of what representations the baseline agent natively encodes, (d) implement auxiliary learning to provide additional supervisory signals to the agent during training, and (e) evaluate the performance of the auxiliary learning agent against the baseline agent.

= Related literature

== Partially Observable Markov Decision Processes (POMDPs)
Many control and robotics problems require an agent to make a sequence of
decisions in an environment, where each decision influences what happens next
and where the agent can sense only part of the environment. We model such
problems as a _partially observable Markov decision process_ (POMDP) defined by the tuple $(cal(S), cal(O), cal(A), cal(P), rho_0, cal(R), gamma, cal(Z))$
@kaelbling1998, whose interaction loop is shown in @mdp_interation_diagram.

At each time step $t$, the environment is in a state $s_t in cal(S)$, where
$cal(S)$ is the state space. The state is a complete description of the
environment. The first state is sampled from an initial state distribution,
$s_0 ~ rho_0$. The agent does not see $s_t$ directly. Instead, it receives an observation
$o_t in cal(O)$ drawn from the observation function,
$o_t ~ cal(Z)(dot | s_t)$, where $cal(O)$ is the observation space. The information in $s_t$ that is missing from
$o_t$ is called _privileged information_. For example, a car may observe its lidar measurements, but not the road surface conditions directly.

Based on its observation, the agent chooses an action $a_t in cal(A)$, where
$cal(A)$ is the action space. It does so using a _policy_ $pi$, which maps an
observation to a probability distribution over actions; we write
$a_t ~ pi(dot | o_t)$. The policy is what we want to find: it describes the
agent's behaviour, whereas the POMDP describes the environment in which the agent
acts. (For simplicity, we let the policy depend only on the current observation;
should the policy depend on a history of observations, we would write $pi(dot | o_t, o_(t-1), dots.h)$.) After the agent has taken action $a_t$, the environment moves
to a new state, $s_(t+1) ~ P(dot | s_t, a_t)$, where $P$ is the transition
function. By the _Markov property_, the next state depends only on the current
state and action, not on earlier history @sutton2018. Then, the agent receives a scalar reward
$r_t = R(s_t, a_t, s_(t+1))$, where $R$ is the reward function, together with
the next observation $o_(t+1)$. The agent's goal is to maximise the expected
discounted return
$EE[G_0] = EE[sum_(t=0)^infinity gamma^t r_t]$, where $gamma in [0, 1)$ is a
discount factor. The return represents a weighted sum of all future rewards, where later rewards are worth less than immediate ones. The discount rate $gamma$ describes how much the agent values future rewards relative to immediate ones. The policy that maximises the expected discounted return is called the _optimal policy_ $pi^*$.

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
  scale(80%, reflow: true, diagram(
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
    step((0, 2), $a_0 ~ pi(dot | o_0)$),
    step((1, 3), $s_1 ~ P(dot | s_0, a_0)$),
    step((0, 4), $a_1 ~ pi(dot | o_1)$),
    step((1, 5), $s_2 ~ P(dot | s_1, a_1)$),
    node((0, 6), $dots.v$, fill: white),
    node((1, 6), $dots.v$, fill: white),

    // Messages
    msg((1, 1), (0, 2), $o_0 = cal(Z)(s_0)$),
    msg((0, 2), (1, 3), $a_0$),
    msg((1, 3), (0, 4), $r_0 = R(s_0, a_0, s_1), o_1 = cal(Z)(s_1)$),
    msg((0, 4), (1, 5), $a_1$),
    msg((1, 5), (0, 6), $r_1 = R(s_1, a_1, s_2), o_2 = cal(Z)(s_2)$),
  )),
  caption: [
    Interaction between the agent and the environment over time ($t$).
  ],
) <mdp_interation_diagram>

=== Value functions
Throughout this section we assume a memoryless policy $pi(dot | o_t)$. Since
$o_t = cal(Z)(s_t)$, the agent's action distribution in state $s$ is
$pi(dot | cal(Z)(s))$, and because the state is Markov, the expected return from
time $t$ depends only on $s_t$. The value functions below are therefore well
defined as functions of the state.

Value functions are a central concept in reinforcement learning, providing a measure of how good it is for the agent to be in a particular state or to take a particular action.
The state-value function,
$
  V^pi (s) = EE_pi [G_t | S_t = s]
$ <state_value_function>

represents the expected discounted return, the agent can achieve starting from state $s$ and following policy $pi$ thereafter. The action-value function,
$
  Q^pi (s, a) = EE_pi [G_t | S_t = s, A_t = a]
$ <action_value_function>
represents the expected discounted return the agent can achieve starting from state $s$, taking action $a$, and following policy $pi$ thereafter.
The advantage function,
$
  A^pi (s, a) = Q^pi (s, a) - V^pi (s)
$ <advantage_function>
measures the relative value of taking action $a$ in state $s$ compared to the average value of all actions in that state .

These state-value and action-value functions satisfy the Bellman equations, which express the relationship between the value of a state and the values of its successor states. @bellman1957 The Bellman equation for the state-value function is given by:

$
  V^pi (s) = EE_pi [R_(t+1) + gamma V^pi (S_(t+1)) | S_t = s]
$ <state_value_bellman_equation>

and the Bellman equation for the action-value function is given by:

$
  Q^pi (s, a) = EE_pi [R_(t+1) + gamma Q^pi (S_(t+1), A_(t+1)) | S_t = s, A_t = a]
$ <action_value_bellman_equation>

These Bellman equations @state_value_bellman_equation and @action_value_bellman_equation provide a recursive relationship that allows the agent to update its value estimates based on the observed rewards and the estimated values of successor states.



== Reinforcement Learning (RL)
Reinforcement learning (RL) is a subfield of machine learning concerned with
finding a policy $pi$ that maximises the expected discounted return
$J(pi) = EE_pi [G_0]$ using only data sampled from interaction with the
environment, without labelled optimal actions or a known model. RL differs from
supervised learning in that feedback is evaluative rather than instructive: the
agent is told how good its actions were, not which action was correct, and
rewards may arrive long after the actions that caused them. Furthermore, the
data distribution depends on the agent's own policy, so the agent must explore.

RL algorithms fall into three broad classes. _Value-based_ methods learn the
optimal action-value function
$Q^*(s, a) = max_pi Q^pi (s, a)$, which satisfies the Bellman optimality
equation
$
  Q^*(s, a) = EE[r_t + gamma max_(a' in cal(A)) Q^*(s_(t+1), a') | s_t = s, a_t = a],
$
and act greedily with respect to it, $pi(s) = argmax_(a in cal(A)) Q^*(s, a)$.
In a fully observable MDP this greedy policy is optimal, but the agent is
restricted to deterministic policies, and the maximisation over $cal(A)$ can be
intractable for continuous actions @lillicrap2015continuous. In a POMDP, the
observation is not necessairily Markov, so $Q(o, a)$ does not satisfy a Bellman equation,
and a state-based $Q(s, a)$ cannot define a deployable policy
as the agent does not observe $s$. Value-based methods therefore require a
Markov input such as the observation history. _Policy-based_ methods instead
learn a parameterised policy $pi_theta$ directly by ascending the gradient of
$J(pi_theta)$ with respect to $theta$, and do not need the Markov property of the observations or an
$arg max$ over actions. They can also represent stochastic policies, which may be
necessary for optimal behaviour in some POMDPs @singh1994learningwithoutstateestimation (although there always exists a deterministic optimal policy in fully-observed MDPs). _Actor-critic_ methods
combine both: a learned value function (the critic) is used to reduce the variance
of the policy gradient, and since the critic is only used in training, it may
condition on privileged information. We focus on policy-based and actor-critic
methods in this report @sutton2018.

== Policy gradient methods

Policy gradient methods are a class of RL training algorithms that learn a policy $pi_theta$ with parameters $theta$ directly by maximising the expected return $EE[G_0]$ with respect to the policy parameters $theta$. Given a trajectory $tau = (s_0, o_0, a_0, r_0, s_1, o_1, a_1, r_1, dots, s_(T-1), o_(T-1), a_(T-1), r_(T-1)) ~ p_theta$, where $p_theta$ is the probability of the trajectory when following the policy $pi_theta$, we intend to maximise the expected return with respect to the policy parameters $theta$:
$
  J(theta) = EE_(tau tilde p_theta) [G_0]
  = EE_(tau tilde p_theta) [sum_(t=0)^T gamma^t r_t]
  = integral p_theta (tau) G(tau) dif tau
$

Using the _log-derivative_ trick, $nabla_theta p_theta (tau) = p_theta (tau) nabla_theta log p_theta (tau)$, and assuming that the integral and derivative can be interchanged#footnote([This can be done only under certain regularity conditions not explored in this report, but generally if the functions are continuous and differentiable everywhere, and the integral is finite.]),
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
  p_theta (tau) = p(s_0) product_(t=0)^(T-1)
  underbrace(p(o_t | s_t), cal(Z)) dot pi_theta (a_t | o_t) dot
  underbrace(p(r_t | s_t, a_t, s_(t+1), o_t), cal(R)) dot
  underbrace(p(s_(t+1) | s_t, a_t), cal(P))
$

since $p(s_0)$, $cal(P)$, $cal(Z)$ and $cal(R)$ do not depend on $theta$, their gradients vanish, so

$
  nabla_theta log p_theta (tau) = sum_(t=0)^(T-1) nabla_theta log pi_theta (a_t | o_t)
$

Then, the _policy gradient_ can be expressed as

$
  nabla_theta J(theta) = EE_(tau tilde p_theta) [sum_(t=0)^(T-1) nabla_theta log pi_theta (a_t | o_t) G(tau)]
$

Write $G(tau) = G_0$. Splitting the return at time $t$,
$
  G_0 = sum_(k=0)^(t-1) gamma^k r_k + gamma^t G_t,
  quad G_t = sum_(k=t)^(T-1) gamma^(k-t) r_k,
$
where $G_t$ is the discounted _reward-to-go_,

$
  nabla_theta J(theta) = EE_(tau tilde p_theta) [sum_(t=0)^(T-1) nabla_theta log pi_theta (a_t | o_t) (sum_(k=0)^(t-1) gamma^k r_k + gamma^t G_t)]
$

However, since the expectation of the fixed past-reward terms is zero, they can be removed from the policy gradient without introducing bias. This can be seen by conditioning on the history $h_t = (s_0, o_0, a_0, r_0, dots, s_(t-1), o_(t-1), a_(t-1), r_(t-1), s_t, o_t)$:

$
  EE_(a_t tilde pi_theta) [nabla_theta log pi_theta (a_t | o_t) | h_t]
  = integral_a nabla_theta pi_theta (a | o_t)
  = nabla_theta integral_a pi_theta (a | o_t)
  = nabla_theta 1 = 0,
$
The past-reward terms therefore vanish in expectation, leaving
$
  nabla_theta J(theta) = EE_(tau tilde p_theta) [sum_(t=0)^(T-1) gamma^t nabla_theta log pi_theta (a_t | o_t) G_t].
$
Removing these zero-mean terms typically reduces the variance of the
Monte Carlo estimate. In practice the factor $gamma^t$ is usually dropped;
this yields a biased estimate of $nabla_theta J(theta)$ for $gamma < 1$
@thomas2014bias.

=== REINFORCE

The REINFORCE algorithm for policy learning was introduced by Williams in 1992 in the journal _Machine Learning_ @williams1992. It is one of the simplest policy gradient methods: by sampling $N$ trajectories $tau^((i)) ~ pi_theta$ of length $T_i$ timesteps each, the policy gradient can be estimated in a Monte-Carlo fashion:

$
  hat(nabla_theta J)(theta) = 1/(N dot overline(T)) sum_(i=1)^N sum_(t=0)^(T_i-1) log(pi_theta (a^((i))_t | o^((i))_t)) dot G^((i))_t
$

where $overline(T)$ is the average trajectory length. In order to run REINFORCE in an AutoGrad engine (such as PyTorch or TensorFlow), a loss function $cal(L)_"REINFORCE"$ is defined such that its gradient with respect to the policy parameters $theta$ is equal to the policy gradient estimate above. This loss function is given by:
$
  cal(L)_"REINFORCE" = -1/(N dot overline(T)) sum_(i=1)^N sum_(t=0)^(T_i-1) log(pi_theta (a^((i))_t | o^((i))_t)) dot G^((i))_t
$

Although REINFORCE is simple to implement, it has several drawbacks. First, it has high variance in its gradient estimates, which can lead to slow convergence and instability during training. Second, it does not make use of a value function to estimate the expected return, which can further increase variance. Finally, it is an on-policy algorithm, meaning that it can only learn from trajectories generated by the current policy, which can limit exploration and learning efficiency (since it cannot train multiple epochs on the same rollout).

=== Proximal Policy Optimization (PPO)
PPO is a modern algorithm for policy learning introduced in 2017 by researchers at OpenAI @schulman2017ppo. It improves on REINFORCE in two ways. First, it is an actor-critic method: alongside the policy, it learns a value function $V^pi (s)$, which is used to compute an advantage estimate $hat(A)_t$ and so reduces the variance of the policy gradient estimate. Second, it optimises a _clipped surrogate objective_, $cal(L)_"PPO"$, that limits how far each update can move the policy. This prevents large, destructive steps and makes several epochs of updates on the same rollout possible.

Recall that the advantage function in @advantage_function is the difference between the action-value and state-value functions. It therefore measures how much better (positive) or worse (negative) an action is than the policy's average action in that state. In training, $hat(A)_t (s_t, a_t)$ is estimated from observed rewards and the learned value function, $hat(V)^pi (s)$, for example with Generalized Advantage Estimation @schulman2018highdimensionalcontinuouscontrolusing.
In PPO, the clipped surrogate objective is given by
$
  cal(L)_"PPO" = -1/(N dot overline(T)) sum_(i=1)^N sum_(t=0)^(T_i-1) min(r_t (theta) dot hat(A)_t, "clip"(r_t (theta), 1 - epsilon, 1 + epsilon) dot hat(A)_t)
$

where $r_t (theta) = (pi_theta (a_t | o_t)) / (pi_theta_"old" (a_t | o_t))$ is the ratio of the new policy's probability of taking action $a_t$ given observation $o_t$ to the old policy's, and $epsilon$ is a hyperparameter that controls how much the policy is allowed to change in a single update. The $"clip"$ function ensures that a policy update that would make $r_t (theta)$ fall outside of the interval $[1 - epsilon, 1 + epsilon]$ is clipped to the nearest endpoint of that interval. This prevents large policy updates that could destabilise training. The $min$ function on the other hand ensures that, while the policy's update is capped when an update makes a good action ($A_t > 0$) more likely, it is not protected from penalties if an update makes a bad action ($A_t < 0$) more likely.


== Auxiliary Learning in RL

In RL, the _primary task_ is to update a policy $pi_theta$ to maximises the expected discounted return $EE_(tau ~ pi_theta) [G_0]$. _Auxiliary learning_ augments this with _auxiliary tasks_ whose learning signals are used only to improve the agent's representations. Unline general multi-task learning, perfromance on the auxiliary tasks is not itself the goal, and their outputs are typically discarded at inference time. Because auxiliary tasks can supply training signal when the reward is sparse or delayed @jaderberg2017unreal, they can improve sample efficiency, and, by acting as an inductive bias#footnote([Inductive bias is the set of assumptions a learning algorithm makes to predict outputs given inputs that it has not encountered before. @hullermeier2013inductive]), generalisation @caruana1997multitask. We consider two
formulations: auxiliary *losses*, which leave the RL objective unchanged and
shape only the shared representation, and auxiliary *rewards*, which modify the
objective itself and can therefore change the optimal policy.

=== Auxiliary Losses

In this formulation, the agent is trained on a weighted sum of the primary
loss and $K$ auxiliary losses. Each loss is computed by a separate _auxiliary head_ that
reads from a representation shared with the policy. Writing the parameters as
$theta = (theta_"s", theta_pi, theta_"a"^((1)), dots, theta_"a"^((K)))$, where
$theta_"s"$ are the shared (encoder) parameters, $theta_pi$ the policy head
and $theta_"a"^((k))$ the $k$-th auxiliary head, the total loss is

$
  cal(L)_"total" (theta) =
  cal(L)_"primary" (theta_"s", theta_pi)
  + sum_(k=1)^K w^((k)) cal(L)_"aux"^((k)) (theta_"s", theta_"a"^((k))),
$

where $w^((k)) >= 0$ weights each auxiliary task relative to the primary loss
(only relative weights matter, so the primary weight is fixed to 1). The
gradients with respect to each parameter group are

$
  nabla_(theta_pi) cal(L)_"total" = nabla_(theta_pi) cal(L)_"primary",
  #linebreak()
  nabla_(theta_"a"^((k))) cal(L)_"total" = w^((k)) nabla_(theta_"a"^((k))) cal(L)_"aux"^((k)),
  quad
  nabla_(theta_"s") cal(L)_"total" =
  nabla_(theta_"s") cal(L)_"primary"
  + sum_(k=1)^K w^((k)) nabla_(theta_"s") cal(L)_"aux"^((k)).
$

Only the shared parameters $theta_"s"$ receive gradients from both the primary
and auxiliary losses, which is how the auxiliary tasks influence the policy:
they shape the representation it is built on

The primary loss, such as $cal(L)_"PPO"$, is still a policy-gradient surrogate
with a high-variance gradient estimate. Auxiliary losses, by contrast, are
usually ordinary supervised or self-supervised objectives (for example
predicting the next observation, or the immediate reward), so their gradients
are exact and low-variance, and do not depend on the reward being observed
#todo([citation]). This is what makes them useful when rewards are sparse or
delayed. Their cost is that the auxiliary and primary gradients can conflict
on the shared parameters, $theta_"s"$ so the weights $w^((k))$ must be chosen
with care.

=== Auxiliary Rewards/Shaped Rewards
Alternatively, the auxiliary task can be incorporated into the reward. The
agent is given the modified reward

$
  r_t^"total" = r_t^"primary" + sum_(k=1)^K w^((k)) r_(t)^("aux", (k)),
$

where each $r_t^("aux", (k))$ rewards behaviour that is expected to help with
the primary task, such as an intrinsic curiosity bonus
@pathak2017curiositydriven or progress towards a subgoal. The policy is then trained
to maximise the expected return of $r_t^"total"$ with the same policy gradient
machinery as before.

Unlike auxiliary losses, this changes the objective being optimised: the agent
now solves a different (PO)MDP, whose optimal policy need not be the same as
$pi^*$ for the primary reward. Poorly chosen auxiliary rewards can therefore
lead the agent to exploit them at the expense of the primary task (_reward
hacking_). The exception is _potential-based shaping_, where the auxiliary
reward has the form $gamma Phi(s_(t+1)) - Phi(s_t)$ for some potential function
$Phi$, which is guaranteed to leave the optimal policy unchanged
@ng1999policy.

The auxiliary rewards do influence the policy, but only indirectly through the
return $G_t$, and therefore through the same high-variance score-function
estimator as the primary reward. No exact gradient is available, and the agent
must work out through its own exploration which auxiliary rewards actually
contribute to the primary task. This credit-assignment problem is harder
still when the auxiliary rewards are themselves sparse or delayed.

== Loss scaling

When composing the $L_"total"$, the question naturally arises: what should be the values of the weights ${w^((1)), ..., w^((N))}$? Since the values cannot simply be learnt by gradient descent (they would simply shrink to 0 or go negative to lower $cal(L)_"total"$), we must use another technique.

=== Hyperparameter tuning

One may empirically estimate the optimal weights using hyperparameter tuning tools such as Optuna @akiba2019optuna, or a simple grid search. However, when it is expensive to train a model, this method of search quickly becomes impractical, since every candidate set of weights requires its own training run.

Hyperparameter tuners differ in how they choose which weights to try next. Grid search evaluates every combination on a fixed $N$-dimensional grid, so its cost grows exponentially with the number of weights $N$. Random search samples configurations at random and is often more efficient than grid search, because usually only a few hyperparameters matter much @bergstra2012random. Bayesian optimisation methods go further by building a model of how the score depends on the hyperparameters and using it to choose promising candidates. Examples include Gaussian-process-based optimisation @snoek2012practical and the tree-structured Parzen estimator (TPE) @bergstra2011algorithms, which is the default sampler in Optuna. Methods such as Hyperband @li2018hyperband and its asynchronous variant ASHA @li2020asha give each trial a small budget and only continue the best-performing ones. However, this method may kill RL trials that perform more exploration early on, so are not ideal for such scenarios.

Even with these savings, each trial still involves training a model, and the number of trials needed grows with the number of loss terms $N$. For multi-task models that are expensive to train, this motivates methods that learn the weights during training instead.

=== Uncertainty weighting
Two kinds of uncertainty can be modelled in a model's predictions @kendall2017uncertainties:
- _Epistemic_ uncertainty: the model is unsure because it hasn't been trained on enough data. More data reduces epistemic uncertainty.
- _Aleatoric_ uncertainty: the data itself is noisy or incomplete, so even a perfect model can't predict exactly. In this case, more training data doesn't help.

Aleatoric uncertainty has two forms:
- _Data-dependent_ or _Heteroscedastic_: the noise changes from input to input (e.g. a blurry image is harder to make inference from than a clear one).
- _Task-dependent_ or _Homoscedastic_: the noise is the same for every input and depends only on the task

Kendall et al. propose a solution to determining the weights ${w_1, ..., w_N}$ problem by modelling the homoscedastic (task-dependent) uncertainty only @kendall2018multitask-cvpr.

Instead of formulating the prediction for task i, $hat(y_i) = f_i (bold(x))$, as a point estimate, it is modelled as a Gaussian with mean $f_i (x)$ and variance $sigma_i^2$:
$
  hat(Y)_i tilde.dot p(y_i | f_i (x)) = N(y_i; f_i (x); sigma_i^2)
$

The negative log-likelihood of this Gaussian probability density function evaluated at the true value $y_i$ is then the loss value for task i:

$
  L_i = -log p(y_i | f_i (x)) = 1/(2 sigma_i^2) ||y_i - f_i (x)||_2^2 + log sigma_i
$


A similar derivation can be made for L1 loss functions by assuming the predictions are $Y_i dot(~) "Laplace"(f_i (x), b_i)$:

$
  L_i = -log p(y_i | f_i (x)) = 1/(b_i) ||y_i - f_i (x)||_1 + log b_i
$

Then, assuming the tasks are independent, the total loss is the sum of the individual losses. The log-variance $log sigma_i$ or log-scale parameter $log b_i$ is a learnable parameter that is updated during training, allowing the model to learn the optimal weights for each loss term.

Of course, in reality, the tasks are not independent, but this method has empirically been shown to work well in practice @kendall2018multitask-cvpr. With some caveats like the fact that it produces a bias towards easy tasks, since they result in smaller $sigma_i$ values. This has led to the development of other methods not explored in this Skripsie, such as so-called Optimal Uncertainty Weighting @kirchdorfer2026investigatingoptimaluw.

== Huber loss
The Huber loss (with parameter $beta$ or in some literature $k$) is a loss function that is less sensitive to outliers compared to the standard Mean Squared Error (MSE) L2 loss @huber1964robust. It is defined as:

$
  cal(L)^beta (y, hat(y)) = cases(
    1/2 (y - hat(y))^2 "if" |y - hat(y)| <= beta,
    beta |y - hat(y)| - 1/2 beta^2 "otherwise"
  )
$

In our case, since we have various loss terms, each relating to a different task where the scale of $y$ differs, we must carefully choose the parameter $beta$ and scale each loss term appropriately.

Rewriting the loss to $cal(L)^beta ((y-mu)/sigma, hat(y))$ allows us to reduce the model's bias towards learning tasks with larger scales, since the loss is now computed on a normalised scale.

In actuality, PyTorch's implementation of the Huber loss (`smooth_l1_loss`) uses a rescaled definition, $(cal(L)^beta (y, hat(y))) /beta$, to prevent the $beta$ parameter from affecting the gradient in the linear region.



= System overview

// Add a subsystem diagram

#figure(
  scale(60%, reflow: true, diagram(
    node-stroke: 0.8pt,
    node-fill: luma(200).transparentize(50%),
    node-inset: 8pt,
    spacing: (2.5em, 1.5em),
    edge-stroke: 0.8pt,
    mark-scale: 80%,

    // ---------- Unity ----------
    node((1, 0), [Track generation], name: <track>),
    node((1, 1), [Spline Extruder], name: <spline>),

    node((2.5, 0), [Car Manager], width: 15em, name: <cm>),
    node((2, 1), [Lidar], name: <lidar>),
    node((3, 1), [Vehicle Controller], name: <vc>),
    node((3, 2), [Wheel Colliders], name: <wheels>),

    node((4, 0), [MLAgents], name: <mla>),

    // ---------- Python training ----------
    node((7, 0), [TorchRL], name: <torch>),
    node((7, 1), [Environment Transforms], name: <env>),
    node((7, 2), [PPO], name: <ppo>),

    // ---------- Connections ----------
    edge(<track>, "<->", <cm>),
    edge(<track>, "<->", <spline>),
    edge(<cm>, "<->", <mla>),
    edge(<mla>, "<->", <torch>),

    // Car Manager -> Lidar / Vehicle Controller (drop down from the wide box)
    edge((2, 0), "<->", <lidar>),
    edge((3, 0), "<->", <vc>),
    edge(<vc>, "<->", <wheels>),

    edge(<torch>, "<->", <env>),
    edge(<env>, "<->", <ppo>),

    // ---------- Group boxes ----------
    // node(
    //   align(top + center, move([*Hyperparameter search*], dy: -14pt)),
    //   enclose: (<python>, <unity>),
    //   stroke: (dash: "dashed", thickness: 1pt),
    //   inset: 24pt,
    //   name: <loop>,
    // ),
    node(
      align(top + center, move([*Unity simulator*], dy: -14pt)),
      enclose: (<track>, <spline>, <cm>, <lidar>, <vc>, <wheels>, <mla>),
      stroke: (dash: "dashed", thickness: 1pt),
      inset: 24pt,
      snap: false,
      name: <unity>,
    ),
    node(
      align(top + center, move([*Python training*], dy: -14pt)),
      enclose: (<torch>, <env>, <ppo>),
      stroke: (dash: "dashed", thickness: 1pt),
      inset: 24pt,
      snap: false,
      name: <python>,
    ),
  )),
  caption: "System overview",
)

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

The F1Tenth Gym @okelly2020f1tenthgym is a python package that provides an environment for training and evaluating autonomous racing agents in simulation. It is built on top of the OpenAI Gym framework and features a simple bicycle model, which lumps tyre forces per axle and has no wheel-level states, so quantities such as per-wheel slip are unavailable. The F1Tenth Gym is therefore unsuitable for methods like ours that require per-wheel information.

== AutoDrive
AutoDrive is another simulator for autonomous driving reseach based on Unity and the MLAgents toolkit.

== Unity
Unity is a game engine developed by Unity Technologies which provides a platform wherein simulations can be built and run, simplifying interations with Nvidia's PhysX physics engine and other low-level libraries.

Unity was chosen over the F1Tenth Gym because its `WheelCollider` component exposes the per-wheel slip quantities that are used as privileged information for the auxiliary heads in #todo("WHERE"), and because it allows the tyre and suspension parameters to be varied between episodes. It features built-in LiDAR simulation, occupancy grid generation, and an API built for agent training (MLAgents).

=== Vehicle model
==== The WheelCollider <sec_wheelcollider>
Unity simulates vehicle dynamics with PhysX. Each wheel of the RoboRacer is
modelled as a `WheelCollider`, which simulates the wheel's suspension,
rotation and tyre friction @unitydocsWheelFrictionCurve. The parameters used
are listed in @wheel_collider_properties.

The tyre model is built on the idea of _slip_: how much the tyre slides over
the road instead of rolling on it. A wheel slips when it spins faster than
the car moves (wheelspin), turns slower than the car moves (braking), or is
dragged sideways (cornering). Slip is expressed as a ratio, so a freely
rolling wheel has a slip of 0 and a locked wheel has a slip of 1.

A tyre needs some slip to produce force. The `WheelCollider` computes the
force from the slip using a friction curve (@wheel_friction_curve). Force
rises with slip until it reaches a peak, the _extremum_, which is the
tyre's maximum grip. Beyond the peak, the tyre begins to slide and the force
falls to a lower, constant value, the _asymptote_. Pushing the car harder
therefore gives less force, not more, which is a regime a racing agent must
learn to avoid. The curve is defined separately for the forward direction
(accelerating and braking) and the sideways direction (cornering). Note that in real life, at low slip values, the rubber stretches instead of actually sliding on the road. This is modelled by the rising part of the curve at low slip values.

#[
  #let asymptote-slip = 0.25
  #let asymptote-value = 0.58
  #let extremum-slip = 0.15
  #let extremum-value = 0.9
  #let stiffness = 1.0
  #let wheel-curve(xe, ve, xa, va, k: 1) = x => {
    if x < 0 {
      0
    } else if x < xe {
      let t = x / xe
      k * ve * (2 * t - t * t)
    } else if x < xa {
      let t = (x - xe) / (xa - xe)
      k * (ve + (va - ve) * (3 * t * t - 2 * t * t * t))
    } else {
      k * va
    }
  }

  #figure(
    plot(
      xmin: 0,
      xmax: 0.4,
      ymin: 0,
      ymax: 1,
      width: 400pt,
      xlabel: "Slip ratio",
      ylabel: "Friction coefficient",
      ylabel-pos: (0.04, 1.1),
      minor-grid-step: 0.01,
      samples: 1000,
      show-grid: "major",
      xtick: (0, 0.1, 0.2, 0.3, 0.4),
      ytick: (0.0, 0.2, 0.4, 0.6, 0.8, 1.0),
      vline(asymptote-slip, stroke: (dash: "dashed")),
      note(rotate(90deg, "Asymptote slip"), (asymptote-slip + 0.01, 0.2), anchor: "center"),
      vline(extremum-slip, stroke: (dash: "dashed")),
      note(rotate(90deg, "Extremum slip"), (extremum-slip + 0.01, 0.2), anchor: "center"),
      hline(asymptote-value, stroke: (dash: "dashed")),
      note("Asymptote value", (0.01, asymptote-value - 0.04), anchor: "west"),
      hline(extremum-value, stroke: (dash: "dashed")),
      note("Extremum value", (0.01, extremum-value - 0.04), anchor: "west"),
      (
        fn: wheel-curve(extremum-slip, extremum-value, asymptote-slip, asymptote-value, k: stiffness),
        stroke: blue + 1.5pt,
        label-pos: 0.8,
      ),
    ),
    caption: [Approximated WheelCollider friction curves for the RoboRacer @unitydocsWheelFrictionCurve #footnote([The parameter values detailed in this chart are the default values configured in the AutoDrive simulator for the F1TENTH vehicle's `WheelColliders`])],
  )<wheel_friction_curve>
]

==== Car RigidBody

The car is modelled using a `RigidBody` and various `BoxColliders` to represent the chassis, bumpers, and other parts of the vehicle. The `RigidBody` is responsible for simulating the car's own physics, such as its inertia, and keeping the wheels attached to the car. The `BoxColliders` are used to detect collisions with the track walls and other objects in the environment. The `RigidBody` is configured with a mass of 3.47 kg as in the original AutoDrive simulator.



== MLAgents
=== Training throughput

Training was performed on a single machine with an AMD Ryzen Threadripper PRO 3995WX CPU (64 cores, 128 hardware threads) and 128 GB of RAM. To make experiments finish in a practical time, we first measured how best to use this hardware, aiming to maximise _aggregate_ throughput: environment timesteps collected and learned from per second, summed across all models training simultaneously.

We ran a grid search over the parameters in @training_performance_variables: concurrent trainers (2, 4, 8, 12), Python threads per trainer (8, 16) and parallel environments per trainer (4, 8, 10, 16). For each configuration, `concurrent_trainers` identical processes were launched at once, each running five PPO iterations (a 256-frame rollout plus four epochs of minibatch updates) with checkpointing and TensorBoard logging disabled. Configurations with more than 8 trainers and 16 environments (>128 concurrent Unity instances) exhausted memory and were excluded, leaving 28 single-run configurations. Throughput per trainer was computed from the mean wall-clock time per iteration:

$ "throughput" = ("rollout length" times "parallel envs" times "areas per env") / "seconds per iteration" $

We report the throughput per trainer, showing how much each model slows as the machine gets busier, and summed across trainers, showing where adding trainers stops paying off.

As shown in @training_performance_results, summed throughput peaks at 8 trainers (4172 timesteps/s with 8 environments and 16 threads) and falls at 12 (at most 3853 timesteps/s), while per-trainer throughput roughly halves from 2 to 8 trainers. The best settings use $8 times 16 = 128$ threads in total, matching the hardware thread count; at 12 trainers the 16-thread configurations are oversubscribed and fall behind the 8-thread ones. We therefore chose $("concurrent_trainers", "parallel_envs", "python_threads") = (8, 8, 16)$, though its margin over the next-best configurations (4020 and 3962 timesteps/s) is within likely run-to-run variation. Using 8 or 12 areas per environment at this configuration did not help (3844 and 3999 timesteps/s).

By default, Unity spawns `n_cpus` garbage-collector threads; we set this to 8 with the `-gc-helper-count` launch argument for all runs.

#figure(
  stb-table(
    columns: 3,
    align: (left, center, left),
    header: ("Parameter", "Values considered", "Description"),
    [`concurrent_trainers`],
    [${2, 4, 8, 12}$],
    [Number of independent models training simultaneously, each in its own process.],
    [`python_threads`],
    [${8, 16}$],
    [Threads available to each trainer's PyTorch, OpenMP, and OpenBLAS thread pools.],
    [`parallel_envs`],
    [${4, 8, 10, 16}$],
    [Number of Unity environment instances per trainer. Each contains 6 training areas, so each instance steps 6 agents in parallel.],
  ),
  caption: "Parameters varied in the training performance grid search.",
) <training_performance_variables>

// HERE

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

Once we have the inner and outer boundaries of the track, generating a mesh by extruding a circle or square along the splines is straightforward in Unity. An example track is shown in #todo("ADD PLACE").

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


=== Features already encoded in the model

Despite not being trained with the explicit task of auxiliary prediction, we are able to extract a proxy to examine the feature representation in the model.





== Normalisation of ego-agent privledged information

Prior to applying auxiliary learning, the privileged information must be normalised. The auxiliary loss is a sum over the individual prediction targets, so a target with a larger numerical range contributes larger errors and gradients, and can dominate the shared representation at the expense of the others. Training with unnormalised targets makes hyperparameter tuning @vanhasselt2016, and training more difficult @lecun1998.

Kendall et al. proposes a solution to this problem by learning a log-variance $log sigma_i$ for each loss $L_i$ @kendall2018multitask-cvpr. Because it is expensive to perform hyperparameter searches across the loss weights ${w_1, ..., w_N}$,.


_Epistemic uncertainty_ is the uncertainty that comes as a result of lack of training data.

_Aleatoric uncertainty_ is that which cannot be reduced

An alternative method is @chen2017gradnorm, which dynamically scales the weights of each loss term to balance the $||delta_W L_i||_2$

== Features learnt by the model


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
  )<neural_net_architecture2>
]

Setting up a linear regression model to predict the auxiliary targets from the hidden layer (fc3) output of the tunk model, we are able to understand the representation encoded by the model @alain2018understandingintermediatelayersusing. The results over the training period of three different training configurations at different auxiliary head loss scale weights are shown in @features_learnt_over_time_curvature_close. The three configurations are:
+ trained with all auxiliary heads simultaneously,
+ trained with only the curvature_close heads, and
+ trained without auxiliary heads.

Interestingly, the linear probe model achieves a high $R^2$ score for the velocity_forward, velocity_lateral, and angular_velocity_y before even training (i.e. just LeCun initialised weights).

#todo([
  I'm not sure why this happens. I hypothesise that because the velocity is just a linear function of the difference between the length of a single LiDAR ray between two consecutive time steps (i.e. $x^"center"_t - x^"center"_(t-1)$), that each layer's projection into a subspace is likely to preserve this linear relationship, and therefore the hidden layer output encodes this information automatically.
])

I've only included the curvature_close auxiliary head results in the figure to keep it legible.

More complex features, such as the track curvature at various distances ahead of the car, are not encoded well in the model before training, and the linear proble model is unable to predict them $R_"baseline"^2 in [0, 0.2]$ late in training for the baseline model. However, with an auxiliary head, the model is able to learn a representation that encodes this information with $R^2_"curvature_head" in [0.4, 0.8]$ later in training for lengths ahead < 3m.

#figure(
  image("../results/figures/r2_scores_per_time_per_aux_head/curvature_close.png"),
  caption: [$R^2$ scores for auxiliary head predictions as a function of time. Each subplot is a different auxiliary head. Orange = trained with all aux heads simulatenously, blue = trained with only the curvature_close heads. green = trained without auxiliary heads. Transparency = auxiliary head loss scale weight $w^((i))$.

    Note that the ],
) <features_learnt_over_time_curvature_close>


= What I did
- *Car always going full throttle + full steering*: This is because tanhnormal saturates at 1, so the model cannot learn when the output is close to 1 or -1. This is a problem because the car is always going full throttle, and the steering angle is often close to 1 or -1. The model cannot learn to output values further away. So, the scale of weights & biases was changed to start in the center
- *LIDAR angle pointing up, causing large lidar values input* - increase wall height, mask "miss" rays to 0
- *Huber loss is invariant* to scale if the parameter beta is updated:
$
  L_beta (x/alpha, hat(x)/alpha) = (L_(alpha*beta) (x, hat(x))) / alpha^2
$
- *Regression based on the hidden layer output of the PPO model*: The PPO model is trained to predict the value function and policy, so the hidden layer output contains information about the state of the environment. This information can be used to predict the auxiliary targets. The regression results show that the hidden layer output contains information about the auxiliary targets, and that this information can be extracted by a simple linear regression model. @alain2018understandingintermediatelayersusing
- By default, BLAS spawns 128 threads. Did hyperparameter tuning to find the best combination of (num_pytorch_threads, num_parallel_trainers, num_envs_per_trainer). Also Unity spawns 128 GC threads, which can be controlled via `"-job-worker-count", str(num_unity_threads), "-gc-helper-count", str(num_unity_threads)`

= Conclusions and recommendations
#pagebreak()
#bibliography("./hyagriva.yaml", style: "ieee", title: [Bibliography])

#in-appendix.update(true)
#set heading(supplement: none, numbering: none)

= Appendix
#set heading(numbering: (..n) => {
  let nums = n.pos()
  if nums.len() == 1 {
    none
  } else if nums.len() == 2 {
    "Appendix " + numbering("A", nums.at(1))
  } else {
    numbering("A.1.1", ..nums.slice(1))
  }
})
== WheelCollider properties <wheel_collider_properties>

#figure(
  stb-table(
    columns: 3,
    align: (left, left, left),
    header: ("Property", "Description", "Value for RoboRacer"),
    [`radius`],
    [Radius of the wheel],
    [5.8 cm],
    [`width`],
    [Radius of the wheel],
    [5.8 cm],
    [`mass`],
    [Mass of each wheel; determines its rotational inertia],
    [109 g],
    [`suspension_distance`],
    [Maximum travel of the suspension along the wheel's local Y axis],
    [5 cm],
    [`suspension_spring`],
    [Spring stiffness pulling the wheel toward its target position],
    [500 N/m],
    [`suspension_damper`],
    [Damping that resists the speed of suspension movement],
    [100 (N·s/m)],
    [`extremum_slip`\*],
    [Slip at which the friction curve peaks (maximum grip)],
    [0.15 fwd / 0.01 side],
    [`extremum_value`\*],
    [Friction at the peak of the curve],
    [0.9 fwd / 1 side],
    [`asymptote_slip`\*],
    [Slip beyond which the tyre is fully sliding],
    [0.25 fwd / 0.1 side],
    [`asymptote_value`\*],
    [Friction while sliding],
    [0.58 fwd / 0.5 side],
    [`stiffness`\*],
    [Multiplier applied to the whole friction curve],
    [0.8 fwd / 1 side],
  ),
  caption: "Relevant parameters of the WheelCollider model. * = forward & sideways",
)

#pagebreak()
#set page(flipped: true)
== Auxiliary Head Regression Results
#[
  #let aux_head_regression_scores = csv("../results/aux_head_regression_scores.csv")


]
#set page(flipped: false)

#pagebreak()
== Training Performance Benchmark Results <training_performance_results>

#[
  #let training_performance_results = (
    csv("../results/bench_perf.csv").slice(1).sorted(key: row => float(row.at(8)), by: (a, b) => a > b)
  )

  #let row-to-content = row => (
    (
      row.at(1),
      row.at(2),
      row.at(3),
      [#calc.round(float(row.at(8)), digits: 2)],
      [#calc.round(float(row.at(8)) / 25, digits: 2)x],
    )
  )
  #figure(
    stb-table(
      columns: 5,
      align: (center, center, center, right, right),
      header: (
        "Concurrent trainers",
        "Python threads",
        [Parallel envs#footnote("It was not possible to run 16 parallel envs on 12 trainers, because the machine ran out of memory.")],
        "Throughput (timesteps/sec)",
        [Speedup vs realtime#footnote("Assuming 25 Hz decision frequency")],
      ),
      ..training_performance_results.map(row-to-content).flatten(),
    ),
    caption: "Training performance results, sorted by throughput.",
  )
]
