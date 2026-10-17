#import "@preview/cetz:0.5.2" as cetz: canvas, draw
#import "@preview/lilaq:0.6.0" as lq
#import "@preview/fletcher:0.5.8" as fletcher: diagram, edge, node, rect-at
#import "@preview/algorithmic:1.0.7" as algorithmic: algorithm-figure, style-algorithm
#import "@preview/latex-lookalike:0.1.4"
#import "@preview/neural-netz:0.3.0" as neural-netz: draw-network
#import "@preview/simple-plot:1.1.0": hline, note, plot, vline
#import "@preview/lilaq:0.5.0" as lq
#import "@preview/neural-viz:0.1.0": *

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
#show heading.where(level: 3): stb-heading(14pt, 1.6em, 1em)
#show heading.where(level: 4): stb-heading(12pt, 1.4em, 1em)

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

#let heavy-rule = 1pt
#let light-rule = 0.6pt

#show figure.where(kind: table): set figure.caption(position: top)
#show figure.where(kind: table): set text(size: 11pt)

// A booktabs-style table: no vertical rules, a heavy rule at the top
// and bottom and a light rule under the header. `header` is the list of
// header cells (pass none for a table without one); everything else is
// passed straight through to `table`.
#let stb-table(
  header: none,
  line-between-rows: false,
  columns: auto,
  ..args,
) = {
  let cells = args.pos()
  let ncols = if type(columns) == int { columns } else if type(columns) == array { columns.len() } else if (
    header != none
  ) { header.len() } else { 1 }

  // Interleave a light hline after every row except the last
  let body = if line-between-rows {
    let out = ()
    let nrows = calc.ceil(cells.len() / ncols)
    for r in range(nrows) {
      out += cells.slice(r * ncols, calc.min((r + 1) * ncols, cells.len()))
      if r < nrows - 1 { out.push(table.hline(stroke: light-rule)) }
    }
    out
  } else { cells }

  table(
    columns: columns,
    stroke: none,
    inset: (x: 0.6em, y: 0.45em),
    align: center + horizon,
    row-gutter: 0pt,
    table.hline(stroke: heavy-rule),
    ..if header != none {
      (table.header(..header), table.hline(stroke: heavy-rule))
    } else { () },
    ..body,
    table.hline(stroke: heavy-rule),
    ..args.named(),
  )
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


  #set page(background: image("stb-thesis-frntp.pdf", width: 110%, height: 107%, fit: "stretch"))



  #block(title("Backseat driver: Privileged-information auxiliary loss in autonomous racing"), width: 400pt)

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

#outline(title: "Table of contents", indent: 32pt)

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
#todo("Why does this problem matter? Bigger picture e.g. saving lives")

Road traffic crashes remain a leading cause of death and serious injury worldwide, and most are attributed to human error. Autonomous driving promises to reduce severe and fatal accidents (e.g. severe lane-departure accidents @olofsson2021crashdatabases), improve traffic flow @VanDriel2010congestion, and reduce emissions @ignlinski2017autonomous-vehicles-ghg. Before such systems can be trusted on public roads, however, they must handle situations at the limits of vehicle dynamics, where grip is nearly exhausted and small mistakes compound quickly.

Autonomous racing is a demanding testbed for exactly these situations. The high speeds, tight control margins, and short time available to recover from bad decisions make it a proxy for developing and evaluating autonomous driving algorithms. In head-to-head (H2H) racing, the agent must additionally reason about an opponent, which adds a further source of information that cannot be read off the vehicle's own sensors.

Generally, there exist two broad approaches to control in autonomous driving: end-to-end learning, where a model is trained to map sensor inputs (e.g. LiDAR, camera frames) directly to control outputs (e.g. speed and steering angle), and modular pipelines, where the problem is broken down into subproblems such as perception, planning, and control. End-to-end learning has the advantage of being able to learn a policy directly from data, without requiring hand-engineered features or intermediate representations. However, it can be difficult to interpret and debug, and may require large amounts of data to learn effectively. Modular pipelines, on the other hand, can be more interpretable and easier to debug, but may require more domain knowledge and engineering effort to design and tune @chen2020interpretableendtoendurbanautonomous.

Auxiliary learning is a technique in which a model is trained to perform additional (auxiliary) tasks alongside the primary task, in the hope that these tasks help it learn intermediate representations that are useful for the primary task. In reinforcement learning, auxiliary tasks can improve performance by providing additional supervisory signals during training @rafiee2022makesusefulauxiliarytasks, while also aiding the interpretability of the learned representations @chen2020interpretableendtoendurbanautonomous. This is attractive for end-to-end racing: a simulator knows the car's true velocity, slip and the geometry of the track ahead, so these quantities can supervise the network during training even though they will not be available to the deployed policy.

== Problem statement
An end-to-end reinforcement learning (RL) agent that drives from LiDAR alone has to learn representations of privileged information that it cannot directly observe in the real world: its own velocity and slip, the curvature of the track ahead, and, in H2H racing, the opponent's location. Early in training, the agent has not yet learned to drive well enough to explore the track effectively, so the reward signal that would teach it these representations is sparse and noisy. This can lead to slow convergence.

Privileged information is, however, available in simulation. This report investigates whether _auxiliary losses_ that predict this privileged information from the policy's shared representation can improve the learning of a LiDAR-only end-to-end racing agent. The research question is:

#align(center)[
  _Does training with privileged-information auxiliary losses improve the performance or training speed of an end-to-end RL racing agent that drives from LiDAR alone, and does it change what the agent's representation encodes?_
]

== Objectives
The objectives of this Skripsie are to:

#set enum(numbering: "(a)")
+ select an appropriate simulation environment for autonomous racing;
+ implement a baseline end-to-end RL agent that drives from LiDAR alone;
+ gain an understanding of what representations the baseline agent natively encodes;
+ implement auxiliary learning to provide additional supervisory signals to the agent during training; and
+ evaluate the performance of the auxiliary learning agent against the baseline agent.
#set enum(numbering: "1.")

Meeting these objectives answers the research question: (a) and (b) provide the experimental platform and the baseline, (c) establishes what auxiliary learning must improve on, and (d) and (e) test the proposed method directly.

== Summary of work
A custom racing simulator was built in Unity, using PhysX-based vehicle dynamics for the RoboRacer vehicle and a procedural track generator that produces a new closed track for each training area. It was benchmarked against the F1Tenth gym and found to run only about 20% slower despite its higher-fidelity physics, and so it was chosen over the F1Tenth gym. The simulator communicates with a Python PPO training script over gRPC, and the training pipeline was tuned for throughput on a 64-core machine.

The baseline agent is a feedforward network that takes a stack of 50 LiDAR scans and the previous action, and is trained with PPO and a dense progress-based reward. To understand what this baseline encodes, linear regression probes were fitted to the activations of its final shared layer to predict privileged quantities. Even at random initialisation, some quantities are already linearly decodable: the car's lateral and angular velocity are predicted with mean out-of-sample $R^2$ of 92% and 85% respectively. Auxiliary heads predicting forward, lateral and angular velocity, per-wheel slip, and upcoming track curvature were then added to the network and trained with a weighted auxiliary loss. Their effect was assessed through changes in probe $R^2$ relative to the baseline and through the area under the primary-task reward curve.

#todo(
  "Summarise the key findings once the auxiliary-vs-baseline analysis is final: which targets became more decodable, and whether primary task performance/training speed improved, stayed the same, or degraded.",
)

== Scope
This report is limited to simulation; no sim-to-real transfer to a physical RoboRacer was attempted. The agent drives from LiDAR and its previous action only, and uses a memoryless feedforward policy with a stacked observation history rather than a recurrent architecture. Learning is done with PPO alone, and other RL algorithms were not compared. Only auxiliary _losses_ are studied; auxiliary rewards and reward shaping (@ng1999policy) are discussed as background but not evaluated. Auxiliary loss weights were chosen by fixed weighting rather than learned weighting, so methods such as uncertainty weighting @kendall2018multitask-cvpr are discussed in the literature review but #todo("not implemented / implemented: must update to match what was done"). Representations are analysed with linear probes only, so non-linearly encoded information is not measured.

#todo("state whether H2H racing with an opponent was evaluated or left as future work")

== Roadmap

*Chapter 2* reviews the background and related literature: POMDPs and value functions, policy gradient methods up to PPO, auxiliary losses and rewards, loss weighting, and linear probing of representations, and closes with related work on auxiliary tasks in RL.

*Chapter 3* describes the system: the Unity simulator and its comparison with the F1Tenth gym, the vehicle and tyre model, procedural track generation, performance tuning of the trainer, and the reward function and evaluation metrics, as well as the auxiliary targets and the network architecture.

*Chapter 4* presents the experiments and results: linear probing of the baseline, the change in probed representations after auxiliary learning, and the effect on primary task performance.

*Chapter 5* concludes by showing how the objectives were met and makes recommendations for future work.

= Background and Related Literature

== Partially Observable Markov Decision Processes (POMDPs)
Many control and robotics problems require an agent to make a sequence of
decisions in an environment, where each decision influences what happens next
and where the agent can sense only part of the environment. We model such
problems as a _partially observable Markov decision process_ (POMDP) defined by the tuple $(cal(S), cal(O), cal(A), cal(P), rho_0, cal(R), gamma, cal(Z))$
@kaelbling1998, whose interaction loop is shown in @mdp_iteration_diagram.

At each time step $t$, the environment is in state $s_t in cal(S)$, where
$cal(S)$ is the state space. This state is a _complete_ description of the
environment at that time. The first state is sampled from an initial state distribution,
$s_0 ~ rho_0$. The agent does not see $s_t$ directly. #todo("REWORD:")Instead, it receives an observation $o_t in cal(O)$, typically its sensor inputs (e.g. LiDAR, camera frames), drawn from the observation function,
$o_t ~ cal(Z)(dot | s_t)$, where $cal(O)$ is the observation space. The information in $s_t$ that is missing from
$o_t$ is called _privileged information_. For example, a car may observe its lidar measurements, but not the road surface conditions directly.

Based on its observation, the agent uses its policy $pi$ to choose an action $a_t in cal(A)$, where
$cal(A)$ is the action space. The policy maps an
observation to a probability distribution over actions; we write
$a_t ~ pi(dot | o_t)$. The policy is what we want to find: it describes the
agent's behaviour, whereas the POMDP describes the environment in which the agent
acts. For simplicity, we let the policy depend only on the current observation;
should the policy depend on a history of observations, we would write $pi(dot | o_t, o_(t-1), dots.h)$. After the agent has taken action $a_t$, the environment moves
to a new state, $s_(t+1) ~ P(dot | s_t, a_t)$, where $P$ is the transition
function. By the _Markov property_, the next state depends only on the current
state and action, not on earlier history @sutton2018. Then, the agent receives a scalar reward
$r_t = R(s_t, a_t, s_(t+1))$, where $R$ is the reward function, together with
the next observation $o_(t+1)$. The agent's goal is to maximise the expected discounted return. The
_return_ from time step $t$ is the discounted sum of all rewards the agent
receives from $t$ onward,
$ G_t = sum_(k=0)^(T-t) gamma^k r_(t+k), $
where $T$ is the final time step and $gamma in [0, 1)$ is the discount
factor. A reward received $k$ steps ahead is scaled by $gamma^k$, so later
rewards are worth less than immediate ones: when $gamma$ is close to 1 the
agent is far-sighted, and when $gamma$ is close to 0 it is short-sighted.
Since $G_t$ depends on random states, observations and actions, it is a
random variable, and the agent maximises its expectation $EE[G_0]$ from the
start of the episode. The policy that achieves this is the _optimal policy_ $pi^*$.

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
    spacing: (18em, 2.5em),
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
    msg((1, 1), (0, 2), $o_0 ~ cal(Z)(dot | s_0)$),
    msg((0, 2), (1, 3), $a_0$),
    msg((1, 3), (0, 4), $r_0 = R(s_0, a_0, s_1), o_1 ~ cal(Z)(dot | s_1)$),
    msg((0, 4), (1, 5), $a_1$),
    msg((1, 5), (0, 6), $r_1 = R(s_1, a_1, s_2), o_2 ~ cal(Z)(dot | s_2)$),
  )),
  caption: [
    Interaction between the agent and the environment over time ($t$).
  ],
) <mdp_iteration_diagram>

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
measures the relative value of taking action $a$ in state $s$ compared to the average value of all actions in that state.

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
restricted to deterministic policies (which are not always optimal in partially observed problems), and the maximisation over $cal(A)$ can be
intractable for continuous actions @lillicrap2015continuous. In a POMDP, the
observation is not necessairily Markov, so $Q(o, a)$ does not satisfy a Bellman equation,
and a state-based $Q(s, a)$ cannot define a deployable policy
as the agent does not observe $s$. _Policy-based_ methods, on the other hand,
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
  hat(nabla_theta J)(theta) = 1/(sum_(i=0)^N T_i) sum_(i=1)^N sum_(t=0)^(T_i-1) log(pi_theta (a^((i))_t | o^((i))_t)) dot G^((i))_t
$

In order to run REINFORCE in an AutoGrad engine (such as PyTorch or TensorFlow), a loss function $cal(L)_"REINFORCE"$ is defined such that its gradient with respect to the policy parameters $theta$ is equal to the policy gradient estimate above. This loss function is given by:
$
  cal(L)_"REINFORCE" = -1/(sum_(i=0)^N T_i) sum_(i=1)^N sum_(t=0)^(T_i-1) log(pi_theta (a^((i))_t | o^((i))_t)) dot G^((i))_t
$

Although REINFORCE is simple to implement, it has several drawbacks. First, it has high variance in its gradient estimates, which can lead to slow convergence and instability during training. Second, it does not make use of a value function to estimate the expected return, which can further increase variance. Finally, it is an on-policy algorithm, meaning that it can only learn from trajectories generated by the current policy, which can limit exploration and learning efficiency (since it cannot train multiple epochs on the same rollout).

=== Proximal Policy Optimization (PPO) <sec_ppo>
PPO is a modern algorithm for policy learning introduced in 2017 by researchers at OpenAI @schulman2017ppo. It improves on REINFORCE in two ways. First, it is an actor-critic method: alongside the policy, it learns a value function $V^pi (s)$, which is used to compute an advantage estimate $hat(A)_t$ and so reduces the variance of the policy gradient estimate. Second, it optimises a _clipped surrogate objective_, $cal(L)_"PPO"$, that limits how far each update can move the policy. This prevents large, destructive steps and makes several epochs of updates on the same rollout possible.

Recall that the advantage function in @advantage_function is the difference between the action-value and state-value functions. It therefore measures how much better (positive) or worse (negative) an action is than the policy's average action in that state. In training, $hat(A)_t (s_t, a_t)$ is estimated from observed rewards and the learned value function, $hat(V)^pi (s)$, for example with Generalized Advantage Estimation @schulman2018highdimensionalcontinuouscontrolusing.
In PPO, the clipped surrogate objective is given by
$
  cal(L)_"PPO" = -1/(sum_(i=0)^N T_i) sum_(i=1)^N sum_(t=0)^(T_i-1) min(r_t (theta) dot hat(A)_t, "clip"(r_t (theta), 1 - epsilon, 1 + epsilon) dot hat(A)_t)
$

where $r_t (theta) = (pi_theta (a_t | o_t)) / (pi_theta_"old" (a_t | o_t))$ is the ratio of the new policy's probability of taking action $a_t$ given observation $o_t$ to the old policy's, and $epsilon$ is a hyperparameter that controls how much the policy is allowed to change in a single update. The $"clip"$ function ensures that a policy update that would make $r_t (theta)$ fall outside of the interval $[1 - epsilon, 1 + epsilon]$ is clipped to the nearest endpoint of that interval. This prevents large policy updates that could destabilise training. The $min$ function on the other hand ensures that, while the policy's update is capped when an update makes a good action ($A_t > 0$) more likely, it is not protected from penalties if an update makes a bad action ($A_t < 0$) more likely.


== Auxiliary Learning in Policy-Based Methods

In RL, the _primary task_ is to update a policy $pi_theta$ to maximises the expected discounted return $EE_(tau ~ pi_theta) [G_0]$. This primary task is typically formulated as minimising a loss (e.g. $cal(L)_"PPO"$) in the policy-based approach. _Auxiliary learning_ augments this task with _auxiliary tasks_ whose learning signals are used to improve the agent's representations. Unline general multi-task learning, perfromance on the auxiliary tasks is not itself the goal, and the auxiliary head outputs are typically discarded at inference time. Because auxiliary tasks can supply training signal when the reward is sparse or delayed @jaderberg2017unreal, they can improve sample efficiency, and, by acting as an inductive bias#footnote([Inductive bias is the set of assumptions a learning algorithm makes to predict outputs given inputs that it has not encountered before. @hullermeier2013inductive]), generalisation @caruana1997multitask. We consider two
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
are exact and low-variance. This is what makes them useful when rewards are sparse or
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
#todo("Will only include this if I have time to implement UW")
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

== Linear Probing of Representations

#figure(
  caption: "Example network architecture",
  scale(80%, reflow: true, draw-network(
    (
      (
        type: "input",
        image: rotate(90deg)[#image("figures/lidar_input.png", width: 4cm, height: 4cm)],
        label: "LIDAR history",
        channels: ("", 50),
      ),
      (
        type: "conv",
        label: "Conv1D",
        channels: (1, 50),
      ),
      (
        type: "conv",
        label: "Conv1D",
        channels: (1, 50),
      ),
      (
        type: "fc",
        label: "fc1",
      ),
      (
        type: "fc",
        label: "fc2",
      ),
      (
        type: "fc",
        label: "fc3",
      ),
      (
        type: "output",
        label: "output",
      ),
    ),
    show-relu: true,
  )),
) <example_network_diagram>

Consider the network in @example_network_diagram. Once trained, each layer $l$
maps an input $bold(x)$ to an intermediate representation
$bold(h)^((l)) = f_l (bold(x); theta) in RR^(d_l)$. We would like to know what
information these representations encode, and in particular whether they encode
privileged state variables (e.g. velocity, slip, upcoming curvature) that.

Alain and Bengio @alain2018understandingintermediatelayersusing introduced
_linear probes_ for this purpose. The main network's weights are frozen, and a
separate linear classifier (the probe) is trained on the representations
$bold(h)^((l))$ of each layer to predict the desired target. Since the
probe cannot change the representation, its test accuracy measures how much
class information is _linearly_ available at that layer. Anand et al.
@anand2020unsupervisedstaterepresentationlearning extended this idea to
reinforcement learning, probing an encoder's representations for ground-truth
state variables of Atari games (read from the console's RAM) rather than for
the network's own targets.

The choice of a _linear_ probe is deliberate. A sufficiently expressive probe
(e.g. a deep MLP) could compute the target from almost any input, including the
raw observation, so high probe accuracy would say more about the probe than
about the representation @belinkov2021probingclassifierspromisesshortcomings.
Restricting the probe to a linear map means that it can only succeed if the
network has already done the work of encoding the target along some direction in the representation space.

Many of the privileged variables of interest are continuous rather than
categorical, so we use a linear _regression_ probe instead of a classifier, as
done by McGrath et al. @mcgrath2022alphazero to probe AlphaZero for chess
concepts and by Gurnee and Tegmark @gurnee2024languagemodelsrepresentspace to probe language
models for spatial and temporal encodings.

== Related work
#todo("For each, the objective, method, and results. What were shortcomings")

Lample and Chaplot @lample2017fps explore a similar problem of training an RL agent to play doom using Deep Q-Networks (DQN) from first-person visual input. They find that auxiliary losses for presence of enemies in the agent's field of view significantly improves performance, approximately doubling agent's kill-to-death ratio. They, however, find that these auxiliary losses only significantly improve performance in the case of Deep _Recurrent_ Q-Networks (DRQN), which receive single-frame inputs and are able to maintain a memory, and not in the case of DQNs, which are memoryless, and instead receive a stack of $N$ previous observations as input. #todo("Why do we not use DRQN?")


= System overview

The system trains an end-to-end RL agent to drive a simulated RoboRacer vehicle from LiDAR. It runs entirely in simulation and has two subsystems, shown in @system_diagram: a Unity simulator, which models the vehicle, track and physics interactions, and a Python training script, which computes rewards given the state communicated by the simulator, and updates the policy. The two communicate over gRPC through the ML-Agents toolkit @ml-agents @juliani2018unity.

The subsystems advance in lockstep, following the interaction loop in @mdp_iteration_diagram. At each timestep, the simulator sends each agent's observation, along with privileged state information, to the training script. The script replies with the action each vehicle should take next. The privileged information is used only during training and is never given to the policy, so the trained agent can drive from LiDAR alone. Rewards are computed in Python rather than in Unity, so the reward function can be changed without rebuilding the simulator.

To speed up data collection, the simulator is replicated: each Unity instance contains `num_areas` independent training areas - each with its own unique agent, and each trainer runs `num_inst` instances in parallel (the stacked boxes in @system_diagram). The rest of this chapter describes the components in turn.

// Add a subsystem diagram
#figure(
  scale(55%, reflow: true)[

    #let enclose-color = luma(230)
    #let offset-rect(dx, dy) = (node, extrude) => {
      let (w, h) = node.size.map(i => i / 2 + extrude)
      fletcher.cetz.draw.rect((-w + dx, -h + dy), (w + dx, h + dy))
    }
    #let stack-shadow(enclose, inset: 24pt, layer: -2) = node(
      enclose: enclose,
      inset: inset,
      snap: false,
      layer: layer,
      shape: offset-rect(-5pt, 5pt),
      fill: enclose-color,
      stroke: (dash: "dashed", thickness: 1pt),
    )
    #diagram(
      node-stroke: 0.8pt,
      node-fill: white,
      node-inset: 8pt,
      spacing: (0.1em, 1.5em),
      edge-stroke: 0.8pt,
      mark-scale: 80%,
      node((1, 0), [Track generation], name: <track>),
      node((1, 1), [Spline Extruder], name: <spline>),
      node([Car Manager], enclose: ((2, 0), (4, 0)), layer: 0, name: <cm>),
      node((2, 1), [Lidar], name: <lidar>),
      node((3, 1), [Auxiliary feature\ extractor], name: <aux>),
      node((4, 1), [Vehicle Controller], name: <vc>),
      node((4, 2), [Wheel Colliders], name: <wheels>),
      node((5.3, 0), [ML Agents], name: <mla>),
      node((40, 0), [TorchRL], name: <torch>),
      node((40, 1), [Environment Transforms], name: <env>),
      node((40, 1.75), [Reward Calculator], name: <reward>),
      node((40, 2.75), [PPO], name: <ppo>),
      edge(<track>, "<->", <cm>),
      edge(<track>, "<->", <spline>),
      edge(<cm>, "<->", <mla>),
      edge(<mla>, "<->", <torch>, [gRPC], label-pos: 0.7, label-side: right),
      edge((2, 0), "<->", <lidar>),
      edge((3, 0), "<->", <aux>),
      edge((4, 0), "<->", <vc>),
      edge(<vc>, "<->", <wheels>),
      edge(<torch>, "<->", <env>),
      edge(<env>, "<->", <reward>),
      edge(<reward>, "<->", <ppo>),

      stack-shadow((<track>, <spline>, <cm>, <lidar>, <aux>, <vc>, <wheels>), layer: -2),
      node(
        align(top + center, move([*Training area* ($times$ `num_areas`)], dy: -18pt)),
        enclose: (<track>, <spline>, <cm>, <lidar>, <aux>, <vc>, <wheels>),
        fill: enclose-color,
        stroke: (dash: "dashed", thickness: 1pt),
        inset: 24pt,
        snap: false,
        layer: -1,
        name: <training_area>,
      ),

      stack-shadow((<training_area>, <mla>), layer: -4),
      node(
        align(top + center, move([*Unity simulator*  ($times$ `num_inst`)], dy: -18pt)),
        enclose: (<training_area>, <mla>),
        fill: enclose-color,
        stroke: (dash: "dashed", thickness: 1pt),
        inset: 24pt,
        snap: false,
        layer: -3,
        name: <unity>,
      ),
      node(
        align(top + center, move([*Python training script*], dy: -18pt)),
        enclose: (<torch>, <env>, <ppo>),
        fill: enclose-color,
        stroke: (dash: "dashed", thickness: 1pt),
        inset: 24pt,
        snap: false,
        name: <python>,
      ),
    )
  ],
  caption: "System diagram",
) <system_diagram>

== Simulator

Previous work on end-to-end driving has largely made use of the F1Tenth gym, with the F1Tenth gym being the most common simulator among methods suveyed in @evans2024unifyingf1tenthautonomousracing. The F1Tenth gym is a Python-based 2D simulator for the F1Tenth (now RoboRacer) vehicle. This simulator is easy to use, and runs in Numba-compiled Python, but features a simplified bicycle model of the vehicle, which approximates slip dynamics using a linear function  @okelly2020f1tenthgym.

The AutoDrive simulator @AutoDRIVESimulator2021, which uses the Unity game engine, is a 3D simulator that models the vehicle and its environment using PhysX, a physics engine developed by NVIDIA. PhysX simulates rigid-body dynamics, including collisions, friction and gravity, and allows for higher-fidelity simulations, including weight transfer dynamics, and suspsension deformation.

#figure(
  stb-table(
    columns: (1fr, 2fr, 2fr),
    line-between-rows: true,
    header: ([], [*Unity (PhysX)*], [*F1Tenth gym*]),
    align: (left, left, left),
    [Integrator],
    [Runge-Kutta 4th order],
    [Euler],
    [Car model],
    [3D, 4-wheel rigid body with suspension, weight transfer, non-linear wheel slip dynamics],
    [2-wheel bicycle model with linearised slip dynamics],
    [Sensors],
    [LiDAR (max 101 rays per agent), IMU, wheel encoders #footnote("The IMU and wheel encoders are modules available in the AutoDrive simulator, not native Unity"), occupancy grids],
    [LiDAR, IMU (excl. pitch, roll) ],
    [Track generation],
    [No],
    [In Beta @f1tenth_gym_trackgen],
  ),
  caption: "Feature comparison of the Unity (PhysX) and F1Tenth gym simulators",
)

However, the AutoDrive simulator by default does not provide various features that are important for end-to-end training in our auxiliary learning setup. For example, it is missing track generation & privileged information reporting. Therefore, a custom simulator was implemented in Unity using components from the AutoDrive simulator. Specifically, the `VehicleController` and `IMU` components were not re-implemented, but instead used directly from the AutoDrive simulator.

=== Simulator performance comparison

In order to ensure the custom Unity simulator is suitable for training and not just evaluation, its performance was compared to the F1Tenth gym. Both environments were configured for 100Hz physics and 25Hz control with one vehicle per environment. Then, a rollout of 10 000 control timesteps (400 sim-seconds) was performed in each environment on an M4 MacBook Air, and the average time per control step was measured. Both environments were run in headless mode.


Despite the Unity simulator being significantly more complex than the F1Tenth gym, it runs at a comparable speed in this environment, as shown in @sim_benchmarks. The Unity simulator is slower than the F1Tenth gym by $20%$. The memory usage of the Unity simulator is also higher than that of the F1Tenth gym, but this is a marginal diffence of 115 MB on average.

Due to the relatively minor performance difference, and Unity's more realistic 3D physics #todo("Do I need to cite here/prove it? I feel as though it's obvious."), the Unity simulator was chosen for training the RL agent.

#figure(
  image("../results/sim_benchmarks.pdf"),
  caption: "Benchmark of Unity simulator vs F1Tenth gym. Note that memory y-axis does not start at 0 to aid interpretability.",
) <sim_benchmarks>

=== Unity Vehicle Model
The vehicle is modelled as a `Rigidbody` with four wheels, each simulated by a
`WheelCollider`. The two components divide the work: the `Rigidbody` represents the
car as a single moving mass, and the `WheelCollider`s generate the forces that move it. Near the front of the car, a `RayPerceptionSensor` from the ML-Agents toolkit simulates a 2D LiDAR sensor with 101 rays, which is used as the agent's observation.

==== The Rigidbody
A `Rigidbody` is the Unity component that gives an object physical behaviour. It
stores the car's mass, centre of mass and moment of inertia. At each fixed timestep
the physics engine (PhysX) integrates the forces and torques acting on it to update
its linear and angular velocity and its pose. The car's body is covered by simple
box colliders (@unity_colliders), which handle collisions with walls and other
objects. They play no part in the tyre-road interaction, which is handled entirely
by the wheels. `BoxColliders` were used to model the car's body and collisions between the wheels and walls.

#figure(
  image("figures/unity_isometric_colliders.png", width: 300pt),
  caption: [Custom Unity car's colliders: the body colliders handle collisions, and
    the four `WheelCollider`s handle suspension and tyre forces.],
) <unity_colliders>

==== The WheelCollider <sec_wheelcollider>
In our custom simulator, each wheel of the RoboRacer is
modelled as a `WheelCollider`, which simulates the wheel's suspension,
rotation and tyre friction @unitydocsWheelFrictionCurve. This kind of collider uses physics similar to that modelled by the semi-empirical "magic formula" wheel dynamics proposed by Pacejka et al. in @pacejka1992magicformula, and further described in @pacejka2002tyre.

The tyre model is built on the idea of _slip_. _Longitudinal slip_, $kappa$, is the ratio between the longitudinal slip velocity and the wheel center velocity. _Lateral slip_, $tan(alpha)$, is the ratio between the lateral slip velocity and the wheel center velocity. A wheel slips when it spins faster than
the wheel center moves (wheelspin), turns slower than the wheel center moves (braking), or is dragged sideways (cornering). A slip value of $0$ therefore indicates a freely rolling wheel, while a slip value of $> 1$ indicates that the point of contact has a higher velocity than the wheel center.

#figure(
  canvas(length: 1cm, {
    import draw: *

    let arrow = (end: "stealth", fill: black)
    let accent = rgb("#c0392b")

    // ===================== (a) Side view: longitudinal slip =====================
    group({
      let R = 1.6
      let C = (0, R)

      // Ground with hatching
      line((-2.6, 0), (2.8, 0), stroke: 0.8pt)
      for i in range(0, 11) {
        let x = -2.4 + i * 0.5
        line((x, 0), (x - 0.25, -0.25), stroke: 0.4pt + gray)
      }

      // Wheel
      circle(C, radius: R, stroke: 1.2pt, fill: luma(240))
      circle(C, radius: 0.06, fill: black)
      line(C, (0, 0), stroke: (paint: gray, dash: "dashed"))
      content((-0.08, R / 2), $r$, anchor: "east")

      // Rotation (clockwise for forward rolling)
      arc(C, start: 130deg, stop: 40deg, radius: 1.0, anchor: "origin", mark: arrow, stroke: 0.8pt)
      content((0.25, R + 1.25), $omega$)

      // Wheel-centre velocity
      line(C, (2.3, R), mark: arrow, stroke: 1pt)
      content((2.3, R + 0.3), $v_(c x)$)

      // Slip velocity at the contact point
      line((0, 0.18), (0.9, 0.18), mark: arrow, stroke: 1.2pt + accent, fill: accent)
      content((0.45, -0.55), text(fill: accent, $v_(s x) = v_(c x) - omega r$))

      // Definition
      content((0.1, -1.5), $display(kappa = - v_(s x) / abs(v_(c x)))$)
      content((0.1, -2.25), [*(a)* Side view: longitudinal slip])
    })

    // ======================= (b) Top view: lateral slip =======================
    group({
      set-origin((7.2, 0))
      let C = (0, 1.6)
      let a = 22deg
      let V = 2.5
      let tip = (V * calc.cos(a), 1.6 - V * calc.sin(a))

      // Tyre footprint (seen from above)
      rect((-1.0, 1.22), (1.0, 1.98), stroke: 1.2pt, fill: luma(240), radius: 0.12)
      circle(C, radius: 0.06, fill: black)

      // Wheel axes
      line((-1.6, 1.6), (3.2, 1.6), stroke: (paint: gray, dash: "dashed"))
      content((3.35, 1.6), text(fill: gray, $x$), anchor: "west")
      line((0, 0.2), (0, 3.0), stroke: (paint: gray, dash: "dashed"))
      content((0, 3.2), text(fill: gray, $y$))

      // Velocity components
      line(C, (tip.at(0), 1.6), mark: arrow, stroke: 1pt)
      content((tip.at(0) / 2 + 0.6, 1.88), $v_(c x)$)
      line((tip.at(0), 1.6), tip, mark: arrow, stroke: 1.2pt + accent, fill: accent)
      content((tip.at(0) + 0.15, (1.6 + tip.at(1)) / 2), text(fill: accent, $v_(s y)$), anchor: "west")

      // Resultant wheel-centre velocity
      line(C, tip, mark: arrow, stroke: 1.2pt)
      content((tip.at(0) - 0.1, tip.at(1) - 0.35), $v_c$)

      // Slip angle
      arc(C, start: 0deg, stop: -a, radius: 1.55, anchor: "origin", stroke: 0.7pt)
      content((1.85 * calc.cos(a / 2), 1.6 - 1.85 * calc.sin(a / 2)), $alpha$)

      // Definition
      content((0.9, -1.35), $display(tan alpha = - v_(s y) / abs(v_(c x)))$)
      content((0.9, -2.25), [*(b)* Top view: lateral slip])
    })
  }),
  caption: [Slip quantities. Longitudinal slip compares the slip velocity at the
    contact point with the wheel-centre velocity; lateral slip compares the
    sideways slip velocity with the forward velocity.],
)


A tyre needs some slip to produce force. The `WheelCollider` computes the
force from the slip using a friction curve (@wheel_friction_curve). Force
rises with slip until it reaches a peak, the _extremum_, which is the
tyre's maximum grip. Beyond the peak, the tyre begins to slide and the force
falls to a lower, constant value, the _asymptote_. Pushing the car harder
therefore gives less force, not more, which is a regime a racing agent must
learn to avoid. The curve is defined separately for the forward direction
(accelerating and braking) and the sideways direction (cornering). Note that in real life, at low slip values, the rubber stretches instead of actually sliding on the road. This is modelled by the rising part of the curve at low slip values.

@wheel_friction_curve shows the difference between a Unity-style piecewise friction curve and a Pacejka "magic formula" curve that was fit using least-squares to approximate Unity's friction curve.

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

  #let pacejka-curve(B, C, D, E, k: 1) = x => {
    if x < 0 { 0 } else {
      let bx = B * x
      k * D * calc.sin(C * calc.atan(bx - E * (bx - calc.atan(bx).rad())).rad())
    }
  }

  #let xs = lq.linspace(0, 0.4, num: 1000)
  #let dashed = (dash: "dashed", thickness: 0.8pt)
  #let label-size = 8pt

  #show lq.selector(lq.diagram): set text(0.8em)

  #figure(
    lq.diagram(
      width: 300pt,
      height: 150pt,
      xlim: (0, 0.4),
      ylim: (0, 1),
      xlabel: [Slip ratio],
      ylabel: [Friction coefficient],
      grid: none,
      xaxis: (ticks: (0, 0.1, 0.2, 0.3, 0.4)),
      yaxis: (ticks: (0.0, 0.2, 0.4, 0.6, 0.8, 1.0)),
      legend: (position: top + right),

      // Guide lines (drawn first so the curves sit on top)
      lq.plot((asymptote-slip, asymptote-slip), (0, 1), stroke: dashed, mark: none, color: luma(50%)),
      lq.plot((extremum-slip, extremum-slip), (0, 1), stroke: dashed, mark: none, color: luma(50%)),
      lq.plot((0, 0.4), (asymptote-value, asymptote-value), stroke: dashed, mark: none, color: luma(50%)),
      lq.plot((0, 0.4), (extremum-value, extremum-value), stroke: dashed, mark: none, color: luma(50%)),

      // Guide labels
      lq.place(
        asymptote-slip - 0.02,
        0.2,
        rotate(90deg, text(size: label-size)[Asymptote slip]),
        align: left + horizon,
      ),
      lq.place(
        extremum-slip - 0.02,
        0.2,
        rotate(90deg, text(size: label-size)[Extremum slip]),
        align: left + horizon,
      ),
      lq.place(
        0.01,
        asymptote-value - 0.04,
        text(size: label-size)[Asymptote value],
        align: left + horizon,
      ),
      lq.place(
        0.01,
        extremum-value - 0.04,
        text(size: label-size)[Extremum value],
        align: left + horizon,
      ),

      // Unity-style piecewise curve
      lq.plot(
        xs,
        xs.map(wheel-curve(extremum-slip, extremum-value, asymptote-slip, asymptote-value, k: stiffness)),
        stroke: blue + 1.5pt,
        mark: none,
        label: "Unity friction curve",
      ),

      // Pacejka magic formula fit
      lq.plot(
        xs,
        xs.map(pacejka-curve(6.14, 1.71, 0.872, -5.09, k: stiffness)),
        stroke: red.transparentize(60%) + 1.5pt,
        label: "Pacejka curve",
        mark: none,
      ),
    ),
    caption: [Approximated WheelCollider friction curves for the RoboRacer @unitydocsWheelFrictionCurve #footnote([The parameter values rendered in this chart are the default values configured in the AutoDrive simulator for the forward direction. See @wheel_collider_properties for the values.])],
  )<wheel_friction_curve>
]

==== LiDAR

The vehicle is equipped with a simulated 2D LiDAR sensor, which is implemented using a `RayPerceptionSensor` from the ML-Agents toolkit. The sensor emits 101 rays in a fan pattern, covering a field of view of $270 degree$. Each ray measures the distance to the nearest obstacle, such as walls or other vehicles, and returns a normalized value between 0 and 1, where 1 indicates no obstacle within the maximum range of the sensor (20m). The sensor also exposes a hit/miss flag for each ray, as well as flags for which object type was hit (opponent, wall, floor etc.).

=== Track generation

During training, a variety of tracks is used to prevent the policy from overfitting to any single layout. Training on diverse environments has been shown to improve generalisation to unseen environments @cobbe2019quantifying, and is closely related to domain randomisation, where simulator parameters are randomised to produce more robust policies @tobin2017domain @peng2018sim

==== Centerline generation

To this end, we implemented a procedural track generator in C\# in Unity. The idea
is a _mean-reverting random walk_: a polyline of $N$ equal-length segments whose
heading wanders randomly but is continually pulled back towards the heading of a
_reference circle_ of radius $R$. The result wanders freely but still forms a single
closed loop of roughly predictable size.

The walk keeps track of two angles: the _reference heading_ $phi_i$, the tangent
direction of the reference circle, and a _heading offset_ $delta_i$ relative to it.
The segment direction is $theta_i = phi_i + delta_i$. Only the offset is random;
the reference heading advances deterministically by $2 pi \/ N$ per step.

The walk starts at $p_0 = (R, 0)$ with $delta_0 = 0$, i.e. tangent to the circle.
Each segment has length $ell = 2 pi R \/ N$, the circumference divided by the number
of segments. For $i = 0, 1, ..., N-1$, with progress $t_i = (i+1) \/ N$:

+ We calculate the reference heading, $phi_i = 2 pi t_i + pi \/ 2$, the tangent of the reference
  circle at $hat(p)_i = R dot (cos 2 pi t_i, sin 2 pi t_i)$.
+ We take a random turn (@fig:walk-step a), drawing $epsilon_i ~ cal(U)(-Delta_max, Delta_max)$
  and adding it to the offset.
+ As depicted in @fig:walk-step b, we shrink the offset the offset towards zero by a factor
  $1 - kappa_i$, where
  $ kappa_i = kappa_0 + (1 - kappa_0) t_i^s. $
  The restoring strength $kappa_i$ starts at $kappa_0$ and ramps up to exactly 1 on
  the final step. The exponent $s$ controls how late the ramp kicks in.
+ In @fig:walk-step c, we limit the offset from the reference heading to prevent accumulation of large offsets, and advance by length $l$:
  $
    delta_(i+1) & = "clip"((1 - kappa_i)(delta_i + epsilon_i), -delta_max, delta_max), \
        p_(i+1) & = p_i + ell (cos(phi_i + delta_(i+1)), sin(phi_i + delta_(i+1))).
  $


// Three-frame illustration of one step of the mean-reverting random walk.
// stage 1: random turn, stage 2: mean reversion, stage 3: clip and step.
#let walk-step(stage) = canvas(length: 0.62cm, {
  import draw: *

  // ---- schematic parameters (degrees; chosen so every effect is visible) ----
  let a-ref = 0 // reference heading φ_i (circle tangent at p_i)
  let d-prev = 20 // offset carried over from the previous step, δ_i
  let eps = 50 // random turn ε_i
  let k-rest = 0.2 // restoring strength κ_i
  let turn-max = 55 // Δ_max
  let d-max = 40 // δ_max
  let R = 6 // reference circle radius
  let L = 3 // length of drawn heading rays
  let step-len = 2.6 // step length ℓ

  let d-turn = d-prev + eps // after random turn
  let d-rest = (1 - k-rest) * d-turn // after mean reversion
  let d-new = calc.clamp(d-rest, -d-max, d-max) // after clipping = δ_{i+1}

  // ---- styling ----
  let c-ref = gray.darken(20%)
  let c-turn = rgb("#c4472d")
  let c-rest = rgb("#1f5fa8")
  let c-clip = rgb("#2e7d32")
  let faded(c) = c.transparentize(65%)

  // ---- helpers ----
  let dir(a, r) = (r * calc.cos(a * 1deg), r * calc.sin(a * 1deg))
  let ray(a, len: L, ..style) = line((0, 0), dir(a, len), ..style)
  let ang(a, b, r, ..style) = arc((0, 0), start: a * 1deg, stop: b * 1deg, radius: r, anchor: "origin", ..style)
  let wedge(a, b, r, fill) = arc(
    (0, 0),
    start: a * 1deg,
    stop: b * 1deg,
    radius: r,
    anchor: "origin",
    mode: "PIE",
    fill: fill,
    stroke: none,
  )
  let lbl(pos, body, c: black, anchor: "center") = content(pos, text(fill: c, size: 8pt, body), anchor: anchor)

  // fixed bounding box so all three frames line up
  rect((-2.9, -1.0), (5.0, 3.4), stroke: none)

  // parallel indicator "//" centred on pt, for a line with direction angle a
  let par-mark(pt, a) = {
    for o in (-0.09, 0.09) {
      let c = (pt.at(0) + o * calc.cos(a * 1deg), pt.at(1) + o * calc.sin(a * 1deg))
      let t = dir(a + 60, 0.16)
      line((c.at(0) - t.at(0), c.at(1) - t.at(1)), (c.at(0) + t.at(0), c.at(1) + t.at(1)), stroke: (
        paint: c-ref,
        thickness: 0.8pt,
      ))
    }
  }

  // ---- context: reference circle, previous step, p_i ----
  // The walk has drifted off the circle. The reference heading φ_i is the
  // tangent at the ideal position p̂_i (where p_i would be on an unperturbed
  // lap); the same direction is then applied at the actual p_i.
  let p-ideal = (-1.3, 1.55)
  let centre = (p-ideal.at(0), p-ideal.at(1) + R)
  arc(centre, start: -118deg, stop: -60deg, radius: R, anchor: "origin", stroke: (
    paint: c-ref.lighten(70%),
    thickness: 0.6pt,
  ))
  lbl((-2.35, 2.3), [reference circle], c: c-ref, anchor: "south")
  // tangent at the ideal position (parallel to φ_i)
  line(
    (rel: (-1.3, 0), to: p-ideal),
    (rel: (1.3, 0), to: p-ideal),
    stroke: (paint: c-ref, dash: "dotted", thickness: 0.9pt),
  )
  par-mark((p-ideal.at(0) + 0.85, p-ideal.at(1)), a-ref)
  circle(p-ideal, radius: 0.13, stroke: (paint: c-ref, thickness: 0.7pt), fill: white)
  lbl((rel: (0, -0.2), to: p-ideal), $hat(bold(p))_i$, c: c-ref, anchor: "north")

  // previous step of the walk
  let p-prev = dir(180 + 8, step-len)
  line(p-prev, (0, 0), stroke: 1.6pt)
  circle(p-prev, radius: 0.08, fill: black, stroke: none)
  lbl(p-prev, $bold(p)_(i-1)$, anchor: "north-west")

  // reference heading φ_i, parallel to the tangent at p̂_i
  ray(a-ref, stroke: (paint: c-ref, dash: "dashed", thickness: 0.9pt), mark: (end: ">", fill: c-ref, scale: 0.6))
  lbl(dir(a-ref, L + 0.1), [reference $phi_i$], c: c-ref, anchor: "west")
  par-mark(dir(a-ref, 2.4), a-ref)

  // ---- stage-specific content ----
  if stage == 1 {
    wedge(d-prev - turn-max, d-prev + turn-max, 2.2, faded(c-turn).transparentize(55%))
    ray(d-prev, stroke: (paint: black, dash: "dashed", thickness: 0.7pt))
    ang(a-ref, d-prev, 1.25, stroke: 0.7pt)
    lbl(dir((a-ref + d-prev) / 2, 1.6), $delta_i$)
    ang(d-prev, d-turn, 1.6, stroke: (paint: c-turn, thickness: 0.9pt), mark: (end: ">", fill: c-turn, scale: 0.6))
    lbl(dir((d-prev + d-turn) / 2, 1.95), $epsilon_i$, c: c-turn)
    ray(d-turn, stroke: (paint: c-turn, thickness: 1.4pt))
    lbl(dir(d-prev - turn-max, 2.25), $plus.minus Delta_max$, c: c-turn, anchor: "north-west")
  }

  if stage == 2 {
    ray(d-prev, stroke: (paint: faded(black), dash: "dashed", thickness: 0.7pt))
    ray(d-turn, stroke: (paint: faded(c-turn), thickness: 1.2pt))
    ang(d-turn, d-rest, 2.0, stroke: (paint: c-rest, thickness: 0.9pt), mark: (end: ">", fill: c-rest, scale: 0.6))
    lbl(dir((d-turn + d-rest) / 2 - 5, 3), $times (1 - kappa_i)$, c: c-rest, anchor: "south-west")
    ray(d-rest, stroke: (paint: c-rest, thickness: 1.4pt))
  }

  if stage == 3 {
    wedge(a-ref - d-max, a-ref + d-max, 2.0, c-clip.transparentize(85%))
    ray(d-rest, stroke: (paint: faded(c-rest), thickness: 1.2pt))
    ang(d-rest, d-new, 1.55, stroke: (paint: c-clip, thickness: 0.9pt), mark: (end: ">", fill: c-clip, scale: 0.45))
    ray(d-new, len: step-len, stroke: (paint: c-clip, thickness: 1.2pt))
    ang(a-ref, d-new, 1.1, stroke: (paint: c-clip, thickness: 0.8pt))
    lbl(dir((a-ref + d-new) / 2, 1.45), $delta_(i+1)$, c: c-clip)
    lbl(dir(a-ref - d-max, 2.05), $plus.minus delta_max$, c: c-clip, anchor: "north-west")
    // the actual step
    let q = dir(d-new, step-len)
    line((0, 0), q, stroke: 1.6pt)
    circle(q, radius: 0.08, fill: black, stroke: none)
    lbl((rel: (0.15, -0.05), to: q), $bold(p)_(i+1)$, anchor: "north-west")
    lbl(dir(d-new + 2, 2.3), $ell$, anchor: "south-east")
  }

  // p_i on top of everything
  circle((0, 0), radius: 0.08, fill: black, stroke: none)
  lbl((0.05, -0.12), $bold(p)_i$, anchor: "north")
})

#figure(
  grid(
    columns: 3,
    column-gutter: 6pt,
    row-gutter: 6pt,
    walk-step(1), walk-step(2), walk-step(3),
    [(a) Random turn], [(b) Mean reversion], [(c) Clip and step],
  ),
  caption: [One step of the track-generation walk.
    *(a)* A random turn $epsilon_i ~ cal(U)(-Delta_max, Delta_max)$ is added to the carried offset $delta_i$, measured from the reference heading $phi_i$.
    *(b)* A fraction $kappa_i$ of the accumulated offset is removed, pulling the heading towards the reference $phi_i$.
    *(c)* The offset is clipped to $plus.minus delta_max$, giving $delta_(i+1)$, and a step of length $ell$ is taken to $bold(p)_(i+1)$.],
) <fig:walk-step>

Early on, $kappa_i approx kappa_0$ is small, so the offset behaves like a weakly
damped random walk (an AR(1) process) and the track
meanders. Near the end, $kappa_i -> 1$ forces the heading back onto the reference
tangent, so the walk heads towards the start point. Because the integrated heading still deviates
slightly from the circle, $p_N$ generally misses $p_0$ by a small gap. We close it by
distributing the gap linearly along the track:
$ p_i <- p_i + i / N (p_0 - p_N), quad i = 0, ..., N. $
The gap is (usually) small, so this correction barely distorts the track.

#figure(
  image("../results/figures/trackgen_walk.pdf", width: 120%),
  caption: [*(a)* Open end of the track before distributing the gap between $p_0$ (green) and $p_N$ (red) *(b)* Closed track after distributing the gap *(c)* Catmull-Rom spline interpolation of the polyline *(d)* A degenerate track],
)


This method is not immune to generating self-intersecting (degenerate) tracks, but the probability is low enough, that we simply discard any degenerate tracks and generate a new one. Empirically we find 50 tracks of 100 000 to be degenerate with our chosen parameters, so a 95%-confidence interval (C.I.) for  $P("degenerate track" | N = 30, Delta_max = 80 degree, kappa_0 = 0.1, s = 3, delta_max = 90 degree)$ is $(0.14%, 0.19%)$ assuming a binomial distribution.

==== Track walls

Adding track walls to the generated centerline spline is a non-trivial problem. A naive approach is to scale the centerline's vertices outwards by a fixed multiple, or provide a fixed offset from the center, but this can create undrivably narrow sections, as visualised in @trackgen_inset_outset (a) and (b) respectively. We therefore generate the walls using the Clipper2 library @clipper2, which implements a polygon offsetting algorithm inspired by Vatti in @vatti1992. The Clipper2 algorithm is robust to self-intersections, but may producce inset "islands" for large inset distances, or for tracks which are close to self-intersecting, as visualised in @trackgen_inset_outset (c).

Empirically, we find that at 135 of the 100 000 tracks produce these islands (C.I. $(1.28%, 1.42%)$), so we simply discard any tracks with islands and re-generate them.



#figure(
  image("../results/figures/trackgen_inset_outset.pdf", width: 120%),
  caption: "Track insets and outsets using different methods",
) <trackgen_inset_outset>


== Environment interface
At every control step (25 Hz, i.e. 40 ms, or four 100 Hz physics steps), each of the `num_areas` agents in an instance sends the following over gRPC:

- a 101-ray LiDAR scan, reduced to its normalised distance channel (the hit/miss and object-type flags are discarded by the environment wrapper, because the policy only uses distance), and
- its current steering angle and throttle.
- privledged quantities including
  - the agent's forward and lateral velocity ($v_f$ and $v_l$) in m/s
  - the agent's yaw rate $omega_y$ in rad/s
  - the track curvature #footnote("The reciprocal of the radius of curvature is also known as the curvature. It is used to prevent large values on straight sections of the track") at 17 equally spaced points between 0.5m and 8m ahead of the agent along the centerline, in 1/m
  - the forward and lateral per-wheel slip values for each wheel, $kappa_x$ and $tan(alpha_x)$ with $x in {"FR", "FL", "BR", "BL"}$, which are unitless

The trainer stacks the 50 most recent scans for each agent (2 s of history at 25 Hz) and passes the stack, together with the steering and throttle, to the policy. The policy returns a steering and throttle command for each agent, which the simulator applies for the next control step. Privileged quantities (velocities, per-wheel slip, upcoming curvature) are sent alongside the observation, and are used only as auxiliary targets.

Because there are `num_inst` Unity instances, the trainer waits for all of them to report before running a single batched inference pass.


== The Agent

The agent is a feedforward actor-critic network implemented in PyTorch, with the TorchRL library handling the action distribution and the PPO loss. It has no recurrent state, so the stack of past scans is its only source of temporal information. It consists of a shared _trunk_ (@trunk_network_architecture) followed by three independent heads (@head_network_architecture), each of which takes as input the same 64-dimensional feature vector output from the trunk:

- the _policy head_ outputs the parameters of the action distribution,
- the _value head_ outputs the state-value estimate $hat(V)^pi (s)$, and
- the _auxiliary head_ outputs predictions of the privileged targets

The trunk (@trunk_network_architecture) has a convolutional part followed by a dense part. The input is a tensor of shape $50 times 101$ (time steps by rays). Four 1D convolutions with ReLU activations slide along the ray axis and treat the time steps as input channels, so the first layer mixes the whole history at each angular position. They have 32, 16, and 16 output channels respectively; all have the same kernel size of 8 (roughly $21 degree$ of FOV). The output is flattened and concatenated with the current steering angle and throttle, and passed through fully connected layers of 128, 72 and 64 units with ReLU activations, followed by layer normalisation of the 64-dimensional output to prevent gradient explosion when the car is under heavy acceleration, pointing the LiDAR above the track walls and resulting in large ray lengths as input.

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
        type: "custom",
        image: rotate(90deg)[
          #image("figures/lidar_input.png", width: 4cm, height: 4cm)
          #place(bottom + center, dy: 10pt)[#text(size: 0.6em, "101")]
        ],
        channels: ("", 50),
        width: 0,
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
      (
        type: "custom",
        channels: (64,),
        depth: 0.5,
        height: 3,
        offset: 0.5,
        name: "fc3",
        label: "LayerNorm",
        legend: "LayerNorm",
        fill: red,
      ),
    ),
    connections: (),
    show-legend: true,
    legend-title: "Layers",
    scale: 100%,
    stroke-thickness: 1,
    depth-multiplier: 0.3,
  )

  #figure(
    caption: [Trunk trunk network. A 50-frame LiDAR stack passes through four 1D convolutions; the flattened output is concatenated with the current steering and throttle and passed through three dense layers and a layer norm to give a 64-dimensional feature vector.],
    scale(80%, reflow: true, cetz.canvas(length: 1cm, {
      import cetz.draw: *
      content((0, 0), main-net, anchor: "north-west", name: "main")
      let x_pos = 7.9
      // Second input: the previous action, concatenated with the flattened
      // conv features. Coordinates are in cm, measured from the top-left of
      // the network image; (8.95, -1.28) is the top face of the "Concat" block.
      content((x_pos, 0), text(size: 8.5pt, weight: "bold")[Current steering, throttle], anchor: "south", name: "act")
      line(
        (x_pos, -0.1),
        (x_pos, -1.0),
        mark: (end: "stealth", fill: rgb("#0f4d52")),
        stroke: (paint: rgb("#0f4d52"), thickness: 1pt),
      )
    })),
  ) <trunk_network_architecture>
]

#figure(
  scale(70%, reflow: true, [
    #let get-fc-height = size => {
      return size / 5
    }

    #let create-head = (name, label, color, n-outputs, show-legend: false) => {
      return [
        #draw-network(
          (
            (
              type: "custom",
              image: rotate(90deg)[
                #image("figures/lidar_input.png", width: 4cm, height: 4cm)
                #place(bottom + center, dy: 10pt)[#text(size: 0.6em, "101")]
              ],
              channels: ("", 50),
              width: 0,
            ),
            (
              type: "custom",
              widths: (2,),
              height: 3,
              depth: 4,
              legend: "Trunk network",
              name: "conv1d",
            ),
            (
              type: "fc",
              width: 2,
              height: get-fc-height(n-outputs),
              depth: 0.5,
              fill: green,
              show-relu: true,
              legend: "Head",
              name: "conv1d",
              channels: (n-outputs,),
            ),
          ),
          connections: (),
          show-legend: show-legend,
          legend-title: "Layers",
          scale: 100%,
          stroke-thickness: 1,
          depth-multiplier: 0.3,
        )
        *(#label)* #name
      ]
    }
    #grid(
      columns: (1fr, 1fr, 1fr),
      [
        #create-head("Policy head", "a", blue, 4)
      ],
      [
        #create-head("Value head", "b", blue, 1)
      ],
      [
        #create-head("Auxiliary head", "c", blue, 26, show-legend: true)
      ],
    )
  ]),
  caption: [Heads attached to the shared 64-dimensional trunk output. Each head is a single linear layer (no activation): the policy head outputs 4 values (location and scale for throttle and steering), the value head 1, and the auxiliary head 27 (one per privileged target).],
)<head_network_architecture>

=== Action Distributions
The policy head outputs a location $mu$ and a raw scale value $x$ for each of
throttle and steering. Each action is sampled independently from a
tanh-squashed Gaussian,
$ a = tanh(u), quad u tilde cal(N)(mu, sigma^2), $
so that $a in (-1, 1)$. To keep the location from drifting arbitrarily far, it is
additionally soft-clamped to roughly $[-5, 5]$ (`tanh_loc=True` in TorchRL's
`TanhNormal`).

The standard deviation is made positive with a softplus, with a small floor:
$sigma = op("softplus")(x) + 10^(-3).$

*Initialisation.* The policy head's linear layer uses a weight initialisation with
gain $0.01$ and zero bias, so every output is close to $0$ at the start. Hence
$mu approx 0$, and both actions are centred near the middle of their range
($tanh(0) = 0$).

This is important because the derivative of the squashing function is
$ (dif a) / (dif u) = 1 - tanh^2(u), $
which goes to $0$ as $|u|$ grows. If the head's outputs start large, samples
land in the saturated region, the gradient of the policy loss with respect to
$mu$ is almost zero, and the policy cannot recover. In early experiments this
is exactly what happened: the car locked at full throttle and full steering in either the positive or negative direction.

== Auxiliary Targets

A set of auxiliary targets described in @auxiliary_targets

#figure(
  stb-table(

  ),
  caption: [The auxiliary targets to be predicted by the agent]
) <auxiliary_targets>

In order to prevent large gradients that could destabilise traning, the targets are normalised to $sigma = 1, mu = 0$

== Training
The agent is trained using the PPO algorhtm (@sec_ppo) using Generalised Advantage Estimation. The total loss minimised is
$ cal(L) = cal(L)_"PPO" + c_v cal(L)_V - c_e H[pi_theta] + sum_(k=1)^K w^((k)) cal(L)_"aux"^((k)), $
where $cal(L)_V$ is the value loss, $H$ the policy entropy and $cal(L)_"aux"^((k))$ the loss of the $k$-th auxiliary target (Huber loss on normalised targets). The baseline model uses the same loss with all $w^((k)) = 0$, so the two differ only in the auxiliary term. Each iteration collects a 256-step rollout from all agents, then runs <epochs> epochs of minibatch updates.

= Experiments & results

To different agent policy architectures were implemented: a feedforward neural network, and a recurrent GRU network. The feedforward

== Metrics
=== Reward function
The agent receives a dense reward at each timestep that encourages fast,
collision-free progress along the track:

$ r_t = w_p dot "wrap"(xi_t - xi_(t-1)) - w_c dot c_t $

Here, $xi_t in [0, L)$ is the agent's *progress* at time $t$: the arc length
along the track centerline, in meters, of the centerline point closest to the
agent's position. $L$ is the total length of the centerline.

The first term rewards forward progress. Because the track is a loop, $xi$
resets from $L$ to $0$ at the finish line, which would make the raw difference
$xi_t - xi_(t-1)$ jump to $-L$. The wrap function maps the difference
to the equivalent displacement in $[-L/2, L/2)$:

$ "wrap"(Delta) = ((Delta + L/2) mod L) - L/2 $

so crossing the finish line gives a small positive reward rather than a large
negative spike. Moving backward along the track gives a negative reward.

The second term penalizes collisions. The indicator $c_t$ equals 1 if the
agent collides with an obstacle at time $t$ and 0 otherwise.

The weights $w_p$ (reward per meter of progress) and $w_c$ (penalty per collision)
balance speed against safety, so must be chosen based on the risk tolerance of the application. We use $w_p = 1.0$ and $w_c = 1.0$. It is important to note that, since the agent is terminated on collision, there already exists a strong implicit penalty for collisions, so $w_c$ can be set relatively low.

=== Crash rates
The _crash rate per episode_ is the fraction of episodes that end in a collision, instead of reaching the maximum episode length.


== Trainer Performance Tuning
Training was performed on a single machine with an AMD Ryzen Threadripper PRO 3995WX CPU (64 cores, 128 hardware threads) and 128 GB of RAM. To ensure experiments finish in a practical time, we first measured how best to use this hardware, aiming to maximise _aggregate_ throughput: environment timesteps collected and learned from per second, summed across all models training simultaneously.

We ran a grid search over the parameters in @training_performance_variables: concurrent trainers (2, 4, 8, 12), Python threads per trainer (8, 16) and parallel environments per trainer (4, 8, 10, 16). For each configuration, `concurrent_trainers` identical processes were launched at once, each running five PPO iterations (a 256-frame rollout plus four epochs of minibatch updates each iteration) with checkpointing and TensorBoard logging disabled. Configurations with more than 8 trainers and 16 environments (>128 concurrent Unity instances) exhausted memory and were excluded, leaving 28 single-run configurations. Throughput per trainer was computed from the mean wall-clock time per iteration:

$ "throughput" = ("rollout length" times "parallel envs" times "areas per env") / "seconds per iteration" $

We report the throughput per trainer, showing how much each model slows as the machine gets busier, and summed across trainers, showing where adding trainers stops paying off.

As shown in @training_performance_results, total throughput peaks at 8 trainers (4172 timesteps/s with 8 environments and 16 threads) and falls at 12 (at most 3853 timesteps/s), while per-trainer throughput roughly halves from 2 to 8 trainers. The best settings use $8 times 16 = 128$ python threads in total, matching the hardware thread count; at 12 trainers the 16-thread configurations are oversubscribed and fall behind the 8-thread ones. We therefore chose (`concurrent_trainers`, `parallel_envs`, `python_threads`) = (8, 8, 16), though its margin over the next-best configurations (4020 and 3962 timesteps/s) is within likely run-to-run variation. Using `num_areas` $in {8, 12}$ per environment in this configuration did not help (3844 and 3999 timesteps/s).

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

= Experiments & results

== Probing intermediate layers for auxiliary information
The intuition rests on the geometry of the feature space. Each input is mapped
to a point $bold(z)_i$ in the space of `fc3` activations, and a linear probe
predicts $hat(bold(y))_i = bold(W) bold(z)_i + bold(b)$. Each output of the
probe is therefore a weighted sum of the features, which is equivalent to
projecting $bold(z)_i$ onto a single direction in the feature space. If the
model has learnt to encode a quantity along some direction, so that moving
along that direction corresponds to a change in the quantity, the probe can
learn that direction and read the quantity off directly. In this case the
information is _linearly decodable_, and the probe will predict $bold(y)_i$
well. If instead the information is absent from the features, no direction
exists that correlates with $bold(y)_i$, and the probe can do no better than a
trivial baseline such as predicting the mean of $bold(y)$ (an $R^2$ near zero).

Because the probe is restricted to linear projections, it cannot construct new
features of its own. Any predictive performance must therefore come from
structure already present in the representation, rather than from the probe
doing the learning. This makes probe accuracy a measure of how explicitly, not
merely whether, the information is represented at that layer.

To construct the probing dataset, we perform a rollout using baseline model for 2048 steps (82 s of simulated time) in each of 32 parallel agents. At every step we record each agent's LIDAR observation $bold(o)_(i,t) in RR^101$ together with the corresponding labelled information $bold(y)_(i,t)$, giving an observation tensor $bold(O) in RR^(32 times 2048 times 101)$. Then, for each checkpoint of each training run of the baseline model, each observation is passed through the trunk to obtain the `fc3` activations $bold(z)_(i,t)$, which serve as inputs to the linear probe. We fit the probe on the rollouts of 25 agents (≈78% train split) and evaluate it on the remaining 7, so that the train and test sets share no trajectories or track layouts.

Interestingly, we observe that even before the first epoch of gradient descent (i.e. with LeCun-randomly initialised weights), some features are already encoded by the model, as shown in @baseline_lr_model_dumbell. This is especially true for the car's lateral velocity $v_l$ and angular velocity $omega_y$, which is predicted with a mean out-of-sample $R^2$ of $overline(R)^2 = 92%$ and $overline(R)^2 = 85%$ respectively. #todo([
  We hypothesise that this is because the car's lateral and angular velocities are strongly correlated with the LIDAR observations, and any LeCun-random projection of these observations will maintain some of this correlation. Then, with many such observations (101 rays x 50 time steps), this correlation is strongly preserved.
]). A similar effect has been observed in @alain2018understandingintermediatelayersusing, where the authors show that, on a small MNIST convolutional neural network, the the probe error decreases with the number of layers, even on randomly initialised weights.

#figure(
  scale(80%, reflow: true, image("../results/figures/probe_dumbbell.pdf")),
  caption: [Out-of-sample $R^2$ scores of linear regression probing of the final layer of the trunk (`fc3`) on the baseline model],
) <baseline_lr_model_dumbell>

#figure(
  image("../results/figures/probe_heatmap.pdf"),
)

== Meeting questions
First, explain the findings I have.
Then:

+ Should I be reporting p-values/statistical significance for the probe deltas?
+ Should I be doing a False Discovery Rate (FDR) correction for testing multiple probes?
+ How should I present this information - we have 4 axes: (target, aux heads active, aux heads weight, iteration) with a scalar in each point? Maybe, a grid (targest x aux heads active) of line plots (iteration on x axis, R^2 with variance on Y axis)?
+ Going forward, should I test H2H or rather add uncertainty weighting?


- Clarify naming of "auxiliary features" => "auxiliary targets"

== Learned features after auxiliary learning


#figure(
  image("../results/figures/probe_heatmap_delta_vs_baseline.pdf", height: 600pt),
  caption: [Mean out-of-sample $R^2$ deltas compared to the baseline model, showing how much more (or less) linearly decodable each quantity is after auxiliary learning],
) <probe_heatmap_delta_vs_baseline>

== Primary Task Performance

#figure(
  image("../results/figures/primary_task_auc_dumbbells.pdf", height: 600pt),
  caption: [AUC for the primary task reward $r_t$ by auxiliary head],
)

=== Variation in Primary Task Performancee


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

#todo("Show you have met the objectives")
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
