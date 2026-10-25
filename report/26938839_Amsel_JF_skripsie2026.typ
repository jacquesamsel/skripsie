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

#set ref(supplement: it => {
  if it.func() == heading {
    if it.level == 1 { "Chapter" } else { "Section" }
  } else if it.func() == figure {
    if it.kind == image { "Figure" } else if it.kind == table { "Table" } else { "Figure" }
  } else if it.func() == table {
    "Table"
  } else if it.func() == math.equation {
    "Equation"
  } else if it.func() == algorithm-figure {
    "Algorithm"
  } else {
    assert(false, "Unknown reference type: " + it.func())
  }
})


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
#set par(leading: 1.0em, spacing: 1.05em)

// --- Page: \usepackage[left=3cm,right=2cm,top=2.5cm,bottom=2.5cm]{geometry}
// with the fancyhdr header (centred running mark + rule) and the
// page number in the bottom-right corner.
#set page(
  paper: "a4",
  margin: (left: 2.5cm, right: 2.5cm, top: 2.5cm, bottom: 2.5cm),
  number-align: right + bottom,
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



  #block(title("Backseat driving: Using privileged-information auxiliary loss in autonomous racing"), width: 400pt)

  by

  #text("Jacques Friedrich Amsel", size: 18pt)

  #v(1cm)

  #block(width: 400pt)[
    Report submitted in partial fulfillment of the requirements of the module
    Project (E) 448 for the degree Baccalaureus in Engineering in the Department of Electrical
    and Electronic Engineering at the University of Stellenbosch
  ]

  #v(1cm)

  *Study leader:* Dr. JC Schoeman

  #v(1cm)

  #datetime.today().display("[month repr:long] [year]")
]

#pagebreak()
#set page(numbering: "i")
#counter(page).update(1)
#set par(justify: true, first-line-indent: (amount: 1.5em, all: false))

= Acknowledgements

I would like to thank my supervisor Dr. JC Schoeman for his guidance and support throughout this project. #todo("Finish")

#pagebreak()
#v(1fr)
#align(center)[
  "Now, this is podracing!"

  \- _Anakin Skywalker in Star Wars: The Phantom Menace_
]
#v(1fr)

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

End-to-end reinforcement learning (RL) agents can drive a car directly from raw sensor inputs, but a LiDAR-only agent must implicitly learning quantities it cannot observe, such as its own velocity, tyre slip, and the curvature of the track ahead to perform well. In simulation, these quantities are available as privileged information, yet standard RL provides no direct signal to learn them: the progress-based reward is dense, but it is an indirect and high-variance teaching signal for these quantities, so the agent learns them slowly. This project investigates whether auxiliary losses that predict privileged information improve the performance and training speed of a LiDAR-only end-to-end racing agent, and whether they change what the agent's internal representations encode.


#pagebreak()

#outline(title: "Table of contents", indent: 32pt)

#pagebreak()

#set page(
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

= Notation

== Conventions

The symbols in this thesis follow a small set of conventions, so a new expression can usually be read without looking it up.

- *Capital vs. lowercase.* A capital letter is a random variable ($S_t$, $A_t$, $O_t$), and the matching lowercase letter is a particular realized value of it ($s_t$, $a_t$, $o_t$).
- *Calligraphic letters* denote sets or spaces: $cal(S)$, $cal(O)$, $cal(A)$ are the state, observation, and action spaces. Lowercase elements live in the corresponding space, e.g. $s in cal(S)$.
- *Subscript $t$* indexes time, so $x_t$ is the quantity $x$ at time step $t$.
- *Subscript $theta$* marks dependence on learnable parameters, e.g. $pi_theta$.
- *Superscript $pi$* means "under policy $pi$", e.g. $V^pi$, $Q^pi$, $A^pi$.
- *Hat* marks an estimate: $hat(X)$ estimates the random variable $X$, and $hat(x)$ is a sample estimate of it.
- *Tilde* means "distributed as": $X ~ Y$ is exact, and $X dot(~) Y$ is approximate.
- *Conditioning bar.* In $f(a | b)$, quantities after the bar are given. This holds for both probabilities and expectations.
- *Expectation subscripts* say what the expectation is over: $EE_pi$ is over trajectories generated by policy $pi$, and $EE_(x ~ p)$ is over $x$ drawn from distribution $p$.

== Reference

#table(
  columns: (1.5fr, 2fr),
  gutter: 8pt,
  stroke: none,

  table.cell(colspan: 2)[*Reinforcement learning setup*],
  [$cal(S)$], [Set of all states],
  [$cal(O)$], [Observation space],
  [$cal(A)$], [Action space],
  [$S_t$, $s_t$], [State at time $t$ (random variable, realization)],
  [$O_t$, $o_t$], [Agent's observation at time $t$ (random variable, realization)],
  [$A_t$, $a_t$], [Action taken at time $t$ (random variable, realization)],
  [$r_t$], [Reward received at time $t$],
  [$rho_0 (s)$], [Initial state distribution],
  [$gamma$], [Discount rate],
  [$lambda$], [GAE discount rate],

  table.cell(colspan: 2)[*Policies and value functions*],
  [$pi_theta$], [Policy with parameters $theta$],
  [$pi_theta (a_t | o_t)$],
  [Probability density of action $a_t$ given observation $o_t$ under policy parameters $theta$],
  [$G_t = sum_(i=t)^T gamma^(i-t) dot r_i$], [Discounted return at time $t$],
  [$V^pi (s) = EE_pi [G_t | S_t = s]$], [Value function for policy $pi$ at state $s$],
  [$Q^pi (s, a) = EE_pi [G_t | S_t = s, A_t = a]$],
  [Action-value function for policy $pi$ at state $s$ and action $a$],
  [$A^pi (s, a) = Q^pi (s, a) - V^pi (s)$],
  [Advantage function for policy $pi$ at state $s$ and action $a$],

  table.cell(colspan: 2)[*Probability and statistics*],
  [$Delta_cal(Y) (X)$], [Set of all probability distributions over variable $X$ with support $cal(Y)$],
  [$X ~ Y$], [$X$ is distributed according to $Y$],
  [$X dot(~) Y$], [$X$ is approximately distributed according to $Y$],
  [$EE[X]$], [Expected value of $X$],
  [$EE_(x ~ p)[f(x)]$], [Expected value of $f(x)$ when $x$ is distributed according to $p$],
  [$"Var"(X)$], [Variance of $X$],
  [$N(mu, sigma^2)$], [Gaussian distribution with mean $mu$ and variance $sigma^2$],
  [$"Uniform"(a, b)$], [Uniform distribution with support $[a, b]$, evaluated at $x$],
  [$hat(X)$], [Estimator for $X$],
  [$hat(x)$], [Sample estimate of $X$],
)

= Acronyms and abbreviations

#let acronyms = (
  ("LiDAR", "Light detection and ranging"),
  ("RL", "Reinforcement learning"),
  ("MDP", "Markov decision process"),
  ("POMDP", "Partially observable Markov decision process"),
  ("PPO", "Proximal policy optimisation"),
  ("MSE", "Mean squared error"),
  ("RMSE", "Root mean squared error"),
  ("MAE", "Mean absolute error"),
  ("H2H", "Head-to-head"),
  ("GAE", "Generalised advantage estimation"),
  ("AUC", "Area under the curve"),
  ("IMU", "Inertial measurement unit"),
  ("FOV", "Field of view"),
  ("C.I", "Confidence interval"),
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

Road traffic crashes remain a leading cause of death and serious injury worldwide @who2018roadsafety, and the overwhelming majority are attributed to human error @hankey1999identification, as cited by Medina et al. @medina2004relationshipinfrastructuredrivererror. Autonomous driving promises to reduce severe and fatal accidents (e.g. severe lane-departure accidents @olofsson2021crashdatabases), improve traffic flow @VanDriel2010congestion, and reduce emissions @ignlinski2017autonomous-vehicles-ghg. Before such systems can be trusted on public roads, however, they must handle difficult situations, where small mistakes compound quickly.

Autonomous racing is a demanding testbed for exactly these situations. The high speeds, tight control margins, and short time available to recover from bad decisions make it a proxy for developing and evaluating autonomous driving algorithms.

Broadly, autonomous driving control architectures fall into two paradigms: modular pipelines and end-to-end learning. Modular pipelines decompose the driving task into distinct sub-problems, such as perception, planning, and control. While this separation provides interpretability and simplifies debugging, it often demands extensive domain expertise and manual tuning. Conversely, end-to-end learning directly maps raw sensor inputs (e.g., LiDAR or camera frames) to control outputs (e.g., speed and steering angle). Although this approach bypasses the need for hand-engineered intermediate representations, it typically requires vast amounts of data and suffers from poor interpretability, making failures difficult to diagnose @chen2020interpretableendtoendurbanautonomous.

Auxiliary learning presents a compelling method to address these shortcomings. By training a model to perform secondary tasks alongside its primary control objective, the network is encouraged to learn richer, more structured intermediate representations @rafiee2022makesusefulauxiliarytasks while improving interpretability @chen2020interpretableendtoendurbanautonomous. This paradigm is particularly useful for end-to-end racing in simulation. Because the simulator has access to privileged, ground-truth state information - such as the vehicle's true velocity, tire slip, and upcoming track geometry - these metrics can be used as auxiliary supervisory signals during training, even though they remain inaccessible to the deployed policy during inference.

== Problem statement
An end-to-end reinforcement learning (RL) agent that drives from LiDAR alone has to learn representations of privileged information that it cannot directly observe in the real world: its own velocity and slip, the curvature of the track ahead, and, in Head-to-Head (H2H) racing, the opponent's location. Early in training, the agent has not yet learned to drive well enough to explore the track effectively, so the reward signal that would teach it these representations is sparse and noisy. This can lead to slow convergence.

Privileged information is, however, available in simulation. This report investigates whether _auxiliary losses_ that predict this privileged information from the policy's shared representation can improve the learning of a LiDAR-only end-to-end racing agent. The research question is:

#align(center)[
  _Does training with privileged-information auxiliary losses improve the performance or training speed of an end-to-end RL racing agent that drives from LiDAR alone, and does it change what the agent's representation encodes?_
]

== Objectives
The objectives of this project are to:

#set enum(numbering: "(a)")
+ select an appropriate simulation environment for autonomous racing;
+ implement a baseline end-to-end RL agent that drives from LiDAR alone;
+ gain an understanding of what representations the baseline agent natively encodes;
+ implement auxiliary learning to provide additional supervisory signals to the agent during training; and
+ evaluate the performance of the auxiliary learning agent against the baseline agent.
#set enum(numbering: "1.")

Meeting these objectives answers the research question: (a) and (b) provide the experimental platform and the baseline, (c) establishes what auxiliary learning must improve on, and (d) and (e) test the proposed method directly.

== Summary of work

To answer the research question, the project was executed in three phases: simulation development, baseline evaluation, and auxiliary learning experimentation.

First, a custom 3D racing simulator was built in Unity. It uses PhysX-based vehicle dynamics from the RoboRacer platform and features a procedural track generator. It was benchmarked against the 2D F1Tenth gym and, despite offering high-fidelity physics (including weight transfer and non-linear tyre slip), it ran only 19% slower, justifying its use for training.

Second, a baseline end-to-end RL agent was trained using Proximal Policy Optimisation (PPO) and a dense progress-based reward. The agent's memoryless feedforward policy drove using only a stack of 50 LiDAR scans (the previous 2s) and the current throttle and steering angle. To understand what representations this baseline naturally encoded, linear regression probes were fitted to the activations of its final shared layer. Even at random initialisation, the network natively captured certain targets: lateral and angular velocities were linearly decodable with mean out-of-sample $R^2$ scores of 92% and 85% respectively.

Finally, auxiliary heads were added to the network to predict privileged state information (forward, lateral, and angular velocity; per-wheel slip; and upcoming track curvature) during training. The models were trained with a weighted auxiliary loss, yielding these primary findings:
- Predicting close track curvature ($<= 3m$ ahead) forced the network to encode measurably more spatial information (an absolute increase of between +51 to +58 percentage points in $R^2$ scores for the close track curvature probes, and +28 and +10 for the 3.5m- and 4.0m-ahead probes which are outside of the auxiliary supervision range). The agent also drove measurably faster (+12.5%) and had fewer collisions per metre of progress (-37.67%) than the baseline.
- Predicting far-ahead track curvature (6m to 8m ahead) was not learned well by the model, and resulted in degraded performance (-24.6% average velocity) and an elevated crash rate per metre progress (up to +265%).
- Predicting the forward slip of either the front or rear wheels decreased the agent's crash rate per metre of progress for both back and front wheels (-42.6% and - 48.5% respectively), but only forward wheel slip prediction improved the agent's velocity (+7.0%), though both only when the auxiliary loss had a low weight (0.1)


== Scope
This report is limited to simulation; no sim-to-real transfer to a physical RoboRacer was attempted. The agent drives from LiDAR and its current steering and throttle only, and uses a memoryless feedforward policy with a stacked observation history rather than a recurrent architecture. Learning is done with PPO alone, and other RL algorithms were not compared. Only auxiliary _losses_ are studied; auxiliary rewards and reward shaping are discussed as background but not evaluated. Representations are analysed with linear probes only, so non-linearly encoded information is not measured. Only single-agent racing is studied, so opponent information is not considered.

== Roadmap

*Chapter 2* reviews the background and related literature: Partially Observable Markov Decision Processes (POMDPs), value functions, policy gradient methods, auxiliary losses and rewards, loss weighting, and linear probing of representations.

*Chapter 3* describes the system: the Unity simulator and its comparison with the F1Tenth gym, the vehicle and tyre model, procedural track generation, performance tuning of the trainer, and the reward function and evaluation metrics, as well as the auxiliary targets and the network architecture.

*Chapter 4* presents the experiments and results: linear probing of the baseline, the change in probed representations after auxiliary learning, and the effect on primary task performance.

*Chapter 5* concludes by showing how the objectives were met and makes recommendations for future work.

= Background and Related Literature <sec:related_literature>

== Previous Approaches
Evans et al. @evans2024unifyingf1tenthautonomousracing present a survey breaking down the autonomous racing literature in RoboRacer into two categories: _classical approaches_ and _learning approaches_. We shall provide a brief overview of classical approaches, and then focus on learning approaches, which are more relevant to this project.

=== Classical approaches

Classical approaches generally decompose the driving task into three stages: perception, planning, and control @evans2024unifyingf1tenthautonomousracing. Perception is the process of converting raw sensor inputs into a representation of the environment, such as a map of the track and the location of other vehicles. Planning uses this representation to generate a trajectory for the vehicle to follow, and control executes this trajectory by sending commands to the vehicle's actuators. These approaches tend to be more interpretable and easier to debug @tampuu2022surveyofendtoenddriving, as each component can be analysed separately @yurtsever2020surveyofautonomousdriving.

=== Learning approaches

Learning approaches, which have recently shown promise in the field of autonomous driving in simulation @wurman2022outracing @lee2025outracing as well as in deployment on a physical vehicle @czechmanowski2025learningracingpoliciesreinforcement, are often end-to-end, mapping raw sensor inputs directly to control outputs @yurtsever2020surveyofautonomousdriving. This can be done using supervised learning (such as behaviour cloning @pomerleau1988alvinn), where the model is trained on a dataset of expert demonstrations, or using reinforcement learning @sutton2018, where the model learns by interacting with the environment and receiving feedback in the form of rewards.

Learning approaches have the potential to learn complex behaviours that are difficult to hand-engineer, and can adapt to changing environments @bosello2022traininaustria. However, they often require large amounts of data and computational resources @srinivasan2023reinforcementlearningadvancementslimitations, and can be less interpretable than classical approaches: deep end-to-end learning approaches are often regarded as "black boxes" @samek2017explainableartificialintelligenceunderstanding, which may be undesirable in safety-critical applications @chi2017deepsteeringlearningendtoend. In RoboRacer, learning approaches have shown promise, but were unable to outperform classical approaches in benchmarks @evans2024unifyingf1tenthautonomousracing, and recently the majority of 27th RoboRacer Autonomous Racing Competition entries were classical approaches @mallon2026roboracer, despite learning approaches generalising better to unseen tracks @bosello2022traininaustria.

== Learning Methods Using Privileged Information <sec:learning_methods_privileged_information>

During training in simulation, information that is not available to the agent at inference time, is available. This information is referred to as _privileged information_, and is usually unused. There are, however, several methods that use privileged information to improve the performance of an agent.

Common ways to use privileged information include as inputs to training-only components (e.g., an asymmetric critic), as inputs to a teacher for distillation, and as auxiliary rewards or losses. We provide these examples to illustrate how other methods use privileged information, and to motivate the use of auxiliary losses as an alternative method in this project.

=== Asymetric Actor-critic Methods
Asymetric actor-critic methods @pinto2017asymmetricactorcriticimagebased are a variant of actor-critic methods that train two distinct models: one for the policy, which chooses the agent's actions and only receives the agent's observations as input, and one for the critic, which receives additional privileged informaton as input. The critic is used to estimate the value of each state, which is then used to update the agent to choose actions that lead it into more valuable states. Vasco et al. @vasco2024superhumanvisionbasedreinforcementlearning show that an asymmetric critic can achieve better-than-human performance of a vision-based RL agent in a simulated autonomous racing environment, and perform better than a baseline symmetric actor-critic agent.

=== Teacher-student distillation

Teacher-student distillation @hinton2015distillingknowledgeneuralnetwork involves training a teacher model with access to privileged information, and then using the teacher's outputs to train a student model that does not have access to this information. The student model is trained to mimic the teacher's behaviour, effectively learning from the teacher's understanding of its privileged knowledge. Xu et al. @xu2026visionbasedpolicylearninghighspeedautonomousracing applied this method to LiDAR-based autonomous racing on the RoboRacer platform, and found that the student model was able to achieve better performance than a baseline model trained without a teacher.


=== Auxiliary learning

Auxiliary learning is a method that falls under the umbrella of multi-task learning, where a model is trained to perform multiple tasks simultaneously. Specifically, in auxiliary learning, the model's performance on the auxiliary task is not an objective in itself, but the model's performance on the auxiliary task is used to improve its performance on the primary task. This occurs because the auxiliary task provides additional information that can be used to improve the model's understanding of the primary task, which can lead to better generalisation and faster learning @ruder2017overviewmultitasklearningdeep.

==== Auxiliary Rewards

When privileged information is available, it can be used to construct auxiliary rewards that guide the agent toward desirable behaviors by evaluating performance against sub-goals. For example, in autonomous racing, privileged knowledge of track layout or opponent positions can generate bonuses for staying centered or avoiding near-misses.

While auxiliary rewards act as a form of reward shaping - supplying denser feedback to accelerate learning - there is a crucial distinction between auxiliary rewards and reward shaping. Traditional potential-based shaping, where the agent is, for example, rewarded for moving towards a target and penalised for moving away from it, guarantees that the underlying task and optimal policy remain unchanged @ng1999policy. Auxiliary rewards, however, act as heuristic bonuses that are rarely potential-based. Consequently, they risk altering the task being solved, which can cause the agent to converge on suboptimal policies for the original objective @ng1999policy.

==== Auxiliary losses

Incorporation of auxiliary losses alongside the primary loss has emerged as a promising technique for improving the performance, interpretability, and training time of end-to-end learning approaches. It does so in three ways: it reduces the variance of the learning signal, it allows privileged information to be used even when it is unavailable at inference time, and it improves representation quality @jaderberg2017unreal @navon2021auxiliarylearningimplicitdifferentiation.

Examples of auxiliary learning with privliged information prediction include Lample et al. @lample2017fps who demonstrated outstanding performance in first-person shooter games by training an agent to predict the presence of enemies in the agent's field of view (FOV), and Mirowski et al. @mirowski2017learningnavigatecomplexenvironments who found auxiliary tasks for depth prediction and loop closure detection improved navigation in 3D mazes, even compared to agents trained with depth information directly as input.

In the field of autonomous driving, Chitta et al. @chitta2022transfuserimitationtransformerbasedsensor applied auxiliary losses for depth prediction, semantic segmentation, and vehicle detection, achieving state-of-the-art performance on the CARLA benchmark, and significantly decreasing the crash rate. Chen et al. @chen2020interpretableendtoendurbanautonomous use auxiliary losses for birds-eye-view prediction in urban environments, improving both interpretability and

== Evaluation of existing approaches

End-to-end RL agents on the RoboRacer platform generalise well to unseen tracks but have yet to match classical pipelines, and their opaque representations make failures hard to diagnose. In simulation, privileged state such as velocity, tyre slip and upcoming track geometry is available but unused at deployment. Existing ways of exploiting it each leave a limitation: An asymmetric critic improves value estimation but doesn't directly shape the policy’s own representation; teacher-student distillation is complex since it requires a separate teacher and a two-stage pipeline; and auxiliary rewards alter the optimisation objective and must still pass through the high-variance policy gradient. Auxiliary losses avoid all three: they leave the RL objective unchanged, supply a lower-variance supervised gradient directly to the shared representation, and are simple to implement. They have improved performance in first-person games, 3D navigation and urban driving. However, to our knowledge, they have not been studied for LiDAR-only racing, nor has it been examined which privileged targets help, or how they change what the policy’s representation encodes. This project addresses that gap.

=== Value functions
Value functions measure how good it is for the agent to be in a state, or to take an action in that state, and are the basis for the critic in PPO.
The state-value function,
$
  V^pi (s) = EE_pi [G_t | S_t = s]
$ <state_value_function>
is the expected discounted return starting in state $s$ and then following policy $pi$ thereafter. The action-value function,
$
  Q^pi (s, a) = EE_pi [G_t | S_t = s, A_t = a]
$ <action_value_function>
measures the expected discounted return starting in state $s$, taking action $a$, and then following policy $pi$ thereafter. Their difference is the advantage function,
$
  A^pi (s, a) = Q^pi (s, a) - V^pi (s),
$ <advantage_function>
which measures how much better action $a$ is than the policy's average action in state $s$.

== Auxiliary Learning in Policy-Based Methods <sec:auxiliary_learning>

Auxiliary learning is a complementary method to standard RL. By modifying the objective, models are able to achieve better performance and training speed, therefore requiring less compute and data. For example, @lample2017fps found improved performance in VizDoom after adding auxiliary tasks, and @mirowski2017learningnavigatecomplexenvironments observed improvements in training time after implementing depth prediction in maze solving tasks. In fact, @mirowski2017learningnavigatecomplexenvironments observed better performance using this privileged information for auxiliary training compared to as a direct input.

In RL, the _primary task_ is to update a policy $pi_theta$ to maximise the expected discounted return $EE_(tau ~ pi_theta) [G_0]$. This primary task is typically formulated as minimising a loss (e.g. $cal(L)_"PPO"$ in the policy-based approach). _Auxiliary learning_ augments this task with _auxiliary tasks_ whose learning signals are used to improve the agent's representations. Unlike general multi-task learning, performance on the auxiliary tasks is not itself the goal, and the auxiliary head outputs are typically discarded at inference time. Because auxiliary tasks can supply training signal when the reward is sparse or delayed @jaderberg2017unreal, they can improve sample efficiency, and, by acting as an inductive bias#footnote([Inductive bias is the set of assumptions a learning algorithm makes to predict outputs given inputs that it has not encountered before. @hullermeier2013inductive]), generalisation @caruana1997multitask. We consider two
formulations: auxiliary losses, which leave the RL objective unchanged and
shape only the shared representation, and auxiliary rewards (or shaped rewards), which modify the
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
they shape the representation it is built on.

The primary loss, such as $cal(L)_"PPO"$, is still a policy-gradient surrogate
with a high-variance gradient estimate. Auxiliary losses, by contrast, are
usually ordinary supervised or self-supervised objectives (for example
predicting the next observation, or the immediate reward), so their gradients
are lower-variance. This is what makes them useful when rewards are sparse or
delayed. Their cost is that the auxiliary and primary gradients can conflict
on the shared parameters, $theta_"s"$, so the weights $w^((k))$ must be chosen
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

//Even with these savings, each trial still involves training a model, and the number of trials needed grows with the number of loss terms $N$. For multi-task models that are expensive to train, this motivates methods that learn the weights during training instead.



// === Uncertainty weighting
// Two kinds of uncertainty can be modelled in a model's predictions @kendall2017uncertainties:
// - _Epistemic_ uncertainty: the model is unsure because it hasn't been trained on enough data. More data reduces epistemic uncertainty.
// - _Aleatoric_ uncertainty: the data itself is noisy or incomplete, so even a perfect model can't predict exactly. In this case, more training data doesn't help.

// Aleatoric uncertainty has two forms:
// - _Data-dependent_ or _Heteroscedastic_: the noise changes from input to input (e.g. a blurry image is harder to make inference from than a clear one).
// - _Task-dependent_ or _Homoscedastic_: the noise is the same for every input and depends only on the task

// Kendall et al. propose a solution to determining the weights ${w_1, ..., w_N}$ problem by modelling the homoscedastic (task-dependent) uncertainty only @kendall2018multitask-cvpr.

// Instead of formulating the prediction for task i, $hat(y_i) = f_i (bold(x))$, as a point estimate, it is modelled as a Gaussian with mean $f_i (x)$ and variance $sigma_i^2$:
// $
//   hat(Y)_i tilde.dot p(y_i | f_i (x)) = N(y_i; f_i (x); sigma_i^2)
// $

// The negative log-likelihood of this Gaussian probability density function evaluated at the true value $y_i$ is then the loss value for task i:

// $
//   L_i = -log p(y_i | f_i (x)) = 1/(2 sigma_i^2) ||y_i - f_i (x)||_2^2 + log sigma_i
// $


// A similar derivation can be made for L1 loss functions by assuming the predictions are $Y_i dot(~) "Laplace"(f_i (x), b_i)$:

// $
//   L_i = -log p(y_i | f_i (x)) = 1/(b_i) ||y_i - f_i (x)||_1 + log b_i
// $

// Then, assuming the tasks are independent, the total loss is the sum of the individual losses. The log-variance $log sigma_i$ or log-scale parameter $log b_i$ is a learnable parameter that is updated during training, allowing the model to learn the optimal weights for each loss term.

// Of course, in reality, the tasks are not independent, but this method has empirically been shown to work well in practice @kendall2018multitask-cvpr. With some caveats like the fact that it produces a bias towards easy tasks, since they result in smaller $sigma_i$ values. This has led to the development of other methods not explored in this project, such as so-called Optimal Uncertainty Weighting @kirchdorfer2026investigatingoptimaluw.

= System overview

The system trains an end-to-end RL agent to drive a simulated RoboRacer vehicle from as input LiDAR. It runs entirely in simulation and has two subsystems, shown in @system_diagram: a simulator, which models the vehicle, track and physics interactions, and a Python training script, which computes rewards given the state communicated by the simulator, and updates the policy. The two communicate over gRPC through the ML-Agents toolkit @ml-agents @juliani2018unity.

At each timestep $t$, the simulator sends a subset of the complete state, $b_t in s_t$, to the training script. Only the essential information is sent to keep the communication overhead low. The training script then computes the observation $o_t$ using the partial state information $b_t$ and performs a forward pass through the policy using $o_t$ as input, computing the next action $a_t$. This action is sent to the simulator, and is applied to the vehicle, stepping the environment forward to the next timestep $t+1$.

To speed up training, multiple instances of the simulator are run in parallel, each with its own set of agent running in separate sandboxed simulation environments.

// Add a subsystem diagram
#figure(
  scale(50%, reflow: true)[

    #let enclose-color = luma(230)
    #let offset-rect(dx, dy) = (node, extrude) => {
      let (w, h) = node.size.map(i => i / 2 + extrude)
      fletcher.cetz.draw.rect((-w + dx, -h + dy), (w + dx, h + dy))
    }
    #let stack-shadow(enclose, inset: 24pt, layer: -2, lighten) = node(
      enclose: enclose,
      inset: inset,
      snap: false,
      layer: layer,
      shape: offset-rect(-6pt, 6pt),
      fill: enclose-color.lighten(lighten),
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
      node((5, 0), [ML Agents], name: <mla>),
      node((6, 0), [TorchRL], name: <torch>),
      node((6, 1), [Environment Transforms], name: <env>),
      node((6, 1.75), [Reward Calculator], name: <reward>),
      node((6, 2.75), [PPO], name: <ppo>),
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

      stack-shadow((<track>, <spline>, <cm>, <lidar>, <aux>, <vc>, <wheels>), layer: -2, 80%),
      node(
        align(top + center, move([*Training area* ($times$ `num_areas`)], dy: -18pt)),
        enclose: (<track>, <spline>, <cm>, <lidar>, <aux>, <vc>, <wheels>),
        fill: enclose-color.lighten(80%),
        stroke: (dash: "dashed", thickness: 1pt),
        inset: 24pt,
        snap: false,
        layer: -1,
        name: <training_area>,
      ),

      stack-shadow((<training_area>, <mla>), layer: -4, 30%),
      node(
        align(top + center, move([*Unity simulator*  ($times$ `num_inst`)], dy: -18pt)),
        enclose: (<training_area>, <mla>),
        fill: enclose-color.lighten(30%),
        stroke: (dash: "dashed", thickness: 1pt),
        inset: 24pt,
        snap: false,
        layer: -3,
        name: <unity>,
      ),
      node(
        align(top + center, move([*Agent training script*], dy: -18pt)),
        enclose: (<torch>, <env>, <ppo>),
        fill: enclose-color.lighten(30%),
        stroke: (dash: "dashed", thickness: 1pt),
        inset: 24pt,
        snap: false,
        name: <python>,
      ),

      stack-shadow((<unity>, <python>), layer: -6, -10%),
      node(
        align(top + center, move([*Training run* ($times$ `num_concurrent_runs`)], dy: -18pt)),
        enclose: (<unity>, <python>),
        fill: enclose-color.darken(10%),
        layer: -5,
        stroke: (dash: "dashed", thickness: 1pt),
        inset: 24pt,
        snap: false,
        name: <shared>,
      ),
    )
  ],
  caption: [System diagram. There are `num_concurrent_runs` concurrent training runs running simultaneously, each with `num_inst` parallel simulator instances. Each simulator instance simulates `num_areas` vehicles, each with its own track. The simulator communicates with the Python training script over gRPC, and the training script updates the policy using PPO.],
) <system_diagram>

The following chapters shall outline the design and implementation of the two subsystems: the simulator (@sec:simulator) and the training script & agent (@sec:training).

= Simulator <sec:simulator>

Previous work on end-to-end driving has largely made use of the F1Tenth gym, with the F1Tenth gym being the most common simulator among methods surveyed in the survey by Evans et al. @evans2024unifyingf1tenthautonomousracing. The F1Tenth gym is a Python-based 2D simulator for the F1Tenth (now RoboRacer) vehicle. This simulator is easy to use, and runs in Numba-compiled Python, but features a simplified bicycle model of the vehicle, which approximates slip dynamics using a linear function  @okelly2020f1tenthgym.

The AutoDrive simulator @AutoDRIVESimulator2021, which uses the Unity game engine @unity2023, is a 3D simulator that models the vehicle and its environment using PhysX @nvidia_physx, a physics engine developed by NVIDIA. PhysX simulates rigid-body dynamics, including collisions, friction and gravity, and allows for higher-fidelity simulations, including weight transfer dynamics, and suspension deformation in Unity.

#figure(
  stb-table(
    columns: (1fr, 2fr, 2fr),
    line-between-rows: true,
    header: ([], [*Unity (PhysX)*], [*F1Tenth gym*]),
    align: (left, left, left),
    [Integrator],
    [Euler],
    [Runge-Kutta 4th order],
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

== Simulator performance comparison

In simulation-based training, throughput is critical because agents typically require a very large number of timesteps to learn. Two timescales are distinguished: the control timestep, at which the agent receives an observation and outputs an action, and the simulation timestep, at which the physics engine advances the numerical physics integration. The simulation timestep is usually shorter than the control timestep, since the dynamics must be integrated at a finer resolution to remain accurate. Following the settings used by Evans et al. @evans2023comparing, we use a control frequency of 25 Hz and a simulation frequency of 100 Hz.

In order to ensure the custom Unity simulator is suitable for training and not just evaluation, its performance was compared to the F1Tenth gym. A rollout of 10 000 control timesteps (7 minutes and 20 seconds in simulation time) was performed in each environment on an M4 MacBook Air, and the average time per control step was measured. Both environments were run in headless mode to remove any potential overhead from the graphical user interface.

Despite the Unity simulator being significantly more complex than the F1Tenth gym, it runs at a comparable speed, using a comparable amount of CPU resources in this environment, as shown in @sim_benchmarks, with the Unity simulator being only 19% slower compared to the F1Tenth Gym in terms of steps per second.

Due to the relatively minor performance difference, and Unity's more realistic 3D physics, the Unity simulator was chosen for training the RL agent.

#figure(
  image("../results/sim_benchmarks.pdf"),
  caption: "Benchmark of Unity simulator vs F1Tenth gym. In the CPU chart, a value greater than 100 indicates that the simulator used more than one CPU core. Includes child processes spawned by the simulator (e.g. in Unity's case)",
) <sim_benchmarks>

== Unity Vehicle Model
The vehicle is modelled as a `Rigidbody` with four wheels, each simulated by a
`WheelCollider`. The two components divide the work: the `Rigidbody` represents the
car as a single moving mass, and the `WheelCollider`s generate the forces that move it. Near the front of the car, a `RayPerceptionSensor` from the ML-Agents toolkit simulates a 2D LiDAR sensor with 101 rays, which is used as the agent's observation.

=== The RigidBody
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
    the four `WheelCollider`s handle suspension and tyre forces. The red lines show the raycasts by the `RayPerceptionSensor` that simulates the LiDAR.],
) <unity_colliders>

=== The WheelCollider <sec_wheelcollider>
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

@wheel_friction_curve shows the difference between a Unity-style piecewise friction curve and a Pacejka "magic formula" curve that was fit using least-squares to approximate Unity's friction curve. The values used for our simulations are detailed in @wheel_collider_properties and are the values calibrated by Samak and Samak @samak2024autonomyorienteddigitaltwins for the RoboRacer platform, ported to our custom Unity simulator.

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
    caption: [Approximated WheelCollider friction curves @unitydocsWheelFrictionCurve for the RoboRacer compared to the Pacejka "magic formula" @pacejka1992magicformula],
  )<wheel_friction_curve>
]

=== Steering
On the real RoboRacer, steering actuation cannot occur instantaneously, but is limited by the steering servo's maximum angular velocity. The `WheelCollider` component does not model this limitation, so we use the `VehicleController` from AutoDrive to implement a cap on steering speed of $omega_max = 315 degree \/ sec$. This value was chosen based on the calibration of the RoboRacer platform by Samak and Samak @samak2024autonomyorienteddigitaltwins.

=== LiDAR

The vehicle is equipped with a simulated 2D LiDAR sensor, which is implemented using a `RayPerceptionSensor` from the ML-Agents toolkit. The sensor emits 101 rays in a fan pattern, covering a field of view of $270 degree$. Each ray measures the distance to the nearest obstacle in its cast direction, and returns a normalized value between 0 and 1, where 1 indicates no obstacle within the maximum range of the sensor (20m).

== The track

During training, a variety of tracks are used to prevent the policy from overfitting to any single layout. Training on diverse environments has been shown to improve generalisation to unseen environments @cobbe2019quantifying, and is closely related to domain randomisation, where simulator parameters are randomised to produce more robust policies @tobin2017domain @peng2018sim.

=== Centerline generation

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
+ As depicted in @fig:walk-step b, we shrink the offset towards zero by a factor
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


This method is not immune to generating self-intersecting (degenerate) tracks, but the probability is low enough that we simply discard any degenerate tracks and generate a new one. Empirically we find 50 tracks of 100 000 to be degenerate with our chosen parameters, so a 95%-confidence interval (C.I.) for  $P("degenerate track" | N = 30, Delta_max = 80 degree, kappa_0 = 0.1, s = 3, delta_max = 90 degree)$ is $(0.037%, 0.065%)$ assuming a binomial distribution.

=== Track walls

Adding track walls to the generated centerline spline is a non-trivial problem. A naive approach is to scale the centerline's vertices outwards by a fixed multiple, or provide a fixed offset from the center, but this can create undrivably narrow sections, as visualised in @trackgen_inset_outset (a) and (b) respectively. We therefore generate the walls using the Clipper2 library @clipper2, which implements a polygon offsetting algorithm inspired by Vatti in @vatti1992. The Clipper2 algorithm is robust to self-intersections, but may produce inset "islands" for large inset distances, or for tracks which are close to self-intersecting, as visualised in @trackgen_inset_outset (c).

Empirically, we find that 1350 of the 100 000 tracks produce these islands (C.I. $(1.28%, 1.42%)$), so we simply discard any tracks with islands and re-generate them.



#figure(
  image("../results/figures/trackgen_inset_outset.pdf", width: 120%),
  caption: "Track insets and outsets using different methods",
) <trackgen_inset_outset>

=== Track Curvature
During trainin, we wish to observe the effect of using track curvature as an auxiliary loss. To this end, we compute the curvature of the track at 16 equally-spaced points along the track ($d in {0.5, ..., 8} "m"$) ahead of the car's current position. The curvature is computed using the formula $c_d = 1 / r$, where $r$ is the radius of the osculating circle at that point on the track. The osculating circle was introduced by Leibniz @leibniz1686 as cited by @struik1969[p. 419, n. 6]; it is the circle that best approximates a curve at a given point, and its radius can be computed from the first and second derivatives of the track’s parametric equations @stewart2020calculus[p. 910-911]:

$
  1/kappa = r = (x'(t) + y'(t))^(3/2) / abs(x'(t) y''(t) - y'(t) x''(t)) = abs(bold(r)'(t))^3 / abs(bold(r)'(t) times bold(r)''(t))
$

= The Agent <sec:training>

In this chapter, we describe the architecture of the agent and the auxiliary losses used to improve its performance. Because we are comparing the effect of auxiliary losses, we train multiple agents with the same architecture, but with different auxiliary losses enabled each time.

We shall first formalise the problem of autonomous racing as a partially observable Markov decision process (POMDP) in @sec:pomdp, then describe the process of reinforcement learning in @sec:rl, describe the architecture of the agent in @sec:agent, #todo("FINISH")


== Partially Observable Markov Decision Processes (POMDPs) <sec:pomdp>

In order to formally describe the problem of autonomous racing, we first introduce the framework of partially observable Markov decision processes (POMDPs). POMDPs are a generalisation of Markov decision processes (MDPs) that account for the fact that an agent may not have access to the full state of the environment. In a POMDP, the agent receives observations that provide partial information about the underlying state, and must make decisions based on this incomplete information.

A POMDPs is defined by the tuple $(cal(S), cal(O), cal(A), cal(P), rho_0, cal(R), gamma, cal(Z))$, based on the work by Kaelbling et al.
@kaelbling1998:

At each time step $t$, the environment is in state $s_t in cal(S)$, where
$cal(S)$ is the state space. This state is a _complete_ description of the
environment at that time. The first state $s_0$ is sampled from an initial state distribution $rho_0$. The agent does not see $s_t$ directly. Instead, it receives an observation $o_t in cal(O)$, typically its sensor inputs (e.g. LiDAR, camera frames), drawn from the observation function,
$o_t ~ cal(Z)(dot | s_t)$. The information in $s_t$ that is missing from
$o_t$ is called _privileged information_. For example, the car may observe its lidar measurements, but not the road surface conditions directly.

Based on its observation, the agent uses its policy $pi$ to choose an action $a_t in cal(A)$, where
$cal(A)$ is the action space. The policy therefore maps an
observation to a probability distribution over actions; we write
$a_t ~ pi(dot | o_t)$ #footnote([Some formulations may define the policy as a mapping from the true state estimate to actions instead, but this is not an end-to-end approach, since there must exist a state estimator in that case.]). The policy is what we want to find: it describes the
agent's behaviour. For simplicity, we let the policy depend only on the current observation;
should the policy depend on a history of observations, we would write $pi(dot | o_t, o_(t-1), dots.h)$. After the agent has taken action $a_t$, the environment moves
to a new state, $s_(t+1) ~ cal(P)(dot | s_t, a_t)$, where $cal(P)$ is the transition
function. By the _Markov property_, the next state $s_(t+1)$ depends only on the current
state $s_t$ and action $a_t$, not on earlier history @sutton2018. Then, the agent receives a scalar reward
$r_t = cal(R)(s_t, a_t, s_(t+1))$, where $cal(R)$ is the reward function, together with
the next observation $o_(t+1)$. This interaction loop is illustrated in @mdp_iteration_diagram.


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
    spacing: (26em, 1.5em),
    node-inset: 6pt,

    // Participants and lifelines
    party((0, 0), [Agent]),
    party((1, 0), [Environment]),
    lifeline(0, 6),
    lifeline(1, 6),

    edge((-0.15, 1), (-0.15, 5), layer: -1, "-|>", $t$),

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

The agent's goal is to maximise the _expected discounted return_. The
_discounted return_ (or simply _return_) from time step $t$ is the discounted sum of all rewards the agent
receives from $t$ onward,
$ G_t = sum_(k=0)^(T-t) gamma^k r_(t+k), $
where $T$ is the final time step and $gamma in [0, 1]$ is the discount
factor. A reward received $k$ steps ahead is scaled by $gamma^k$, so later
rewards are worth less than immediate ones: when $gamma$ is close to 1 the
agent is far-sighted, and when $gamma$ is close to 0 it is short-sighted.
Since $G_t$ depends on random states, observations and actions, it is a
random variable, and the agent maximises its expectation, $EE[G_0]$, from the
start of the episode. The policy that achieves this maximum is the _optimal policy_ $pi^*$.

== Reinforcement Learning (RL) <sec:rl>

In order to find the optimal policy, $pi^*$ that maximises the expected discounted return, $J(theta) = EE_pi [G_0]$, we use reinforcement learning (RL) as introduced by Sutton and Barto @sutton2018. In RL, the agent learns to maximise its expected discounted return by interacting with the environment and receiving feedback in the form of rewards. The agent updates its policy based on the observed rewards and transitions, gradually improving its performance over time. We use RL instead of supervised learning due to lack of labelled data for the optimal policy.

So-called model-free RL algorithms fall into three broad classes: _Value-based_ methods learn the
optimal action-value function
$Q^*(s, a) = max_pi Q^pi (s, a)$
and act greedily with respect to it, choosing the action with the highest value in the current state: $pi(s) = argmax_(a in cal(A)) Q^pi (s, a)$.
_Policy-based_ methods, on the other hand,
learn a parameterised policy $pi_theta$ directly by ascending the estimated gradient of
$J(theta)$ with respect to $theta$, and do not need the Markov property of the observations or an
$arg max$ over actions. They can also represent stochastic policies, which may be
necessary for optimal behaviour in some POMDPs @singh1994learningwithoutstateestimation (although there always exists a deterministic optimal policy in fully-observed MDPs). _Actor-critic_ methods
combine both: a learned value function (the critic) is used to reduce the variance
of the policy gradient, and since the critic is only used in training, it may take privileged information as input as in . We focus on policy-based and actor-critic
methods in this report.

=== Policy gradient theorem <sec:policy_gradient>

Policy gradient methods are a class of RL training algorithms that learn a policy $pi_theta$ with parameters $theta$ directly by maximising the expected return $EE[G_0]$ with respect to the policy parameters $theta$. Given a trajectory $tau = (s_0, o_0, a_0, r_0, s_1, o_1, a_1, r_1, dots, s_(T-1), o_(T-1), a_(T-1), r_(T-1)) ~ p_theta$, where $p_theta$ is the probability of the trajectory when following the policy $pi_theta$, we intend to maximise the expected return with respect to the policy parameters $theta$:
$
  J(theta) = EE_(tau tilde p_theta) [G_0]
  = EE_(tau tilde p_theta) [sum_(t=0)^T gamma^t r_t]
  = integral p_theta (tau) G(tau) dif tau
$

Taking the gradient of $J(theta)$ with respect to $theta$ and applying the log-derivative trick @williams1992, we obtain the policy gradient theorem @sutton2018:
$
  nabla_theta J(theta) = EE_(tau tilde p_theta) [sum_(t=0)^(T-1) gamma^t nabla_theta log pi_theta (a_t | o_t) G_t].
$ <eq:policy_gradient_theorem>

@eq:policy_gradient_theorem shows in what direction to update the policy parameters in order to increase the expected return. Of course, we cannot compute the expectation exactly without simulating all possible trajectories, and instead have to rely on estimates such as those detailed in @sec:reinforce and @sec:ppo.


=== REINFORCE <sec:reinforce>

The REINFORCE algorithm for policy learning was introduced by Williams in 1992 in the journal _Machine Learning_ @williams1992. It is one of the simplest policy gradient methods: by sampling $N$ trajectories $tau^((i)) ~ pi_theta$ of length $T_i$ timesteps each, the policy gradient can be estimated in a Monte-Carlo fashion:

$
  hat(nabla_theta J)(theta) = 1/(sum_(i=0)^N T_i) sum_(i=1)^N sum_(t=0)^(T_i-1) log(pi_theta (a^((i))_t | o^((i))_t)) dot G^((i))_t
$
Although REINFORCE is simple to implement, it has several drawbacks, including having high variance in its gradient estimates, which can lead to slow convergence and instability during training @santana2026introductiondeepreinforcementimitation, and, being an on-policy algorithm, it can only learn from trajectories generated by the current policy, which can limit exploration and learning efficiency (since it cannot train multiple epochs on the same rollout).

=== Proximal Policy Optimisation (PPO) <sec:ppo>
PPO is a modern actor-critic algorithm for policy learning introduced in 2017 by researchers at OpenAI @schulman2017ppo. It improves on REINFORCE in two ways. First, being an actor-critic method, it learns a value function $V^pi (s)$, which is used to compute an advantage estimate $hat(A)_t$ and so reduces the variance of the policy gradient estimate, $hat(nabla_theta J)(theta)$. Second, it optimises a _clipped surrogate objective_, $cal(L)_"PPO"$, that limits how far each update can move the policy. This prevents large, destructive steps and makes several epochs of updates on the same rollout possible.

Recall that the advantage function in @advantage_function is the difference between the action-value and state-value functions. It therefore measures how much better (positive) or worse (negative) an action is than the policy's average action in that state. In training, $hat(A)_t = hat(A)^pi (s_t, a_t)$ is estimated from observed rewards and the learned value function, $hat(V)^pi (s)$, for example with Generalised Advantage Estimation @schulman2018highdimensionalcontinuouscontrolusing.
In PPO, the clipped surrogate objective is given by
$
  cal(L)_"actor" = -1/(sum_(i=0)^N T_i) sum_(i=1)^N sum_(t=0)^(T_i-1) min(rho_t (theta) dot hat(A)_t, "clip"(rho_t (theta), 1 - epsilon, 1 + epsilon) dot hat(A)_t)
$

where $rho_t (theta) = (pi_theta (a_t | o_t)) / (pi_theta_"old" (a_t | o_t))$ is the ratio of the new policy's probability of taking action $a_t$ given observation $o_t$ to the old policy's, and $epsilon$ is a hyperparameter that controls how much the policy is allowed to change in a single update. The $"clip"$ function ensures that a policy update that would make $r_t (theta)$ fall outside of the interval $[1 - epsilon, 1 + epsilon]$ is clipped to the nearest endpoint of that interval. This prevents large policy updates that could destabilise training. The $min$ function on the other hand ensures that, while the policy's update is capped when an update makes a good action ($A_t > 0$) more likely, it is not protected from penalties if an update makes a bad action ($A_t < 0$) more likely. These two mechanisms together ensure that the policy is updated in a way that improves performance while avoiding large, destabilising changes that are common in other policy gradient methods @schulman2017ppo.

Since PPO is an actor-critic method, it also learns a value function $V^pi (s)$, which is used to compute an advantage estimate $hat(A)_t$ and so reduces the variance of the policy gradient estimate, $hat(nabla_theta J)(theta)$. The value function is learned by minimising the mean squared error between the predicted value and the observed return. The full PPO loss function is therefore a combination of the clipped surrogate objective and the value function loss, along with an entropy bonus to encourage exploration. The final loss function is given by

$
  cal(L)_"PPO" = cal(L)_"actor" + w_"value" dot cal(L)_"value" - w_"entropy" dot cal(H)[pi_theta]
$

== Neural Network Architecture <sec:agent>

The agent is a feedforward actor-critic network implemented in PyTorch @paszke2019pytorch, with the TorchRL library @bou2023torchrldatadrivendecisionmakinglibrary.

It has no recurrent state, so the stack of past scans is its only source of temporal information, since during testing, a Recurrent Neural Network (RNN) performed poorly in comparison. It consists of a shared _trunk_ followed by three independent heads, each of which takes as input the same 64-dimensional feature vector output from the trunk, as visualised in @network_architecture:

- the _policy head_ outputs the parameters of the action distribution,
- the _value head_ outputs the state-value estimate $hat(V)^pi (s)$, and
- the _auxiliary head_ outputs predictions of the privileged targets

The trunk (@network_architecture) has a convolutional part followed by a dense part. The input is a tensor of shape $50 times 101$ (time steps by rays). Three 1D convolutions with ReLU activations slide along the ray axis and treat the time steps as input channels, so the first layer mixes the whole history at each angular position. They have 32, 16, and 16 output channels respectively; all have the same kernel size of 8 (roughly $21 degree$ of FOV). The output is flattened and concatenated with the current steering angle and throttle, and passed through fully connected layers of 128, 72 and 64 units with ReLU activations, followed by layer normalisation of the 64-dimensional output to prevent gradient explosion when the car is under heavy acceleration, pointing the LiDAR above the track walls and resulting in large normalised ray lengths as input ($approx 1$).

#{
  // Box heights grow with layer size, with a minimum so the rotated labels fit.
  let conv-height = ch => 1.2cm + ch * 0.05cm
  let fc-height = size => 1.2cm + size * 0.02cm

  // Generic layer box: tall, narrow, tinted fill, rotated label.
  // The label is laid out in a block as wide as the box is tall *before*
  // rotating, so it doesn't wrap to the box's narrow width.
  let layer = (pos, name, label, color, height, width: 0.9cm) => node(
    pos,
    rotate(
      -90deg,
      reflow: true,
      block(width: height, align(center, text(size: 0.7em, weight: "bold", fill: color.darken(30%), label))),
    ),
    name: name,
    fill: color.transparentize(80%),
    stroke: (paint: color, thickness: 1.5pt),
    width: width,
    height: height,
    inset: 2pt,
    corner-radius: 0.15cm,
  )

  let conv = (pos, name, ch) => layer(
    pos,
    name,
    [Conv1d · #ch \ #text(weight: "regular")[\+ ReLU]],
    orange,
    conv-height(ch),
  )

  let fc = (pos, name, size) => layer(
    pos,
    name,
    [Dense · #size \ #text(weight: "regular")[\+ ReLU]],
    blue,
    fc-height(size),
  )

  // Horizontal (unrotated) box for the output heads.
  // The node itself is ~zero-width so it doesn't widen the grid columns shared
  // with the trunk; the visible box is drawn with `place` and overhangs.
  let head = (pos, name, label, size) => node(
    pos,
    place(center + horizon, box(
      width: 2.6cm + 24pt,
      height: 0.9cm + 24pt,
      fill: black.transparentize(90%),
      stroke: (paint: black, thickness: 1pt),
      radius: 0.2cm,
      inset: 12pt,
      {
        place(left + top, dy: -25pt, box(width: 4cm, text(size: 1em, weight: "bold")[#label]))
        box(
          width: 2.6cm,
          height: 0.9cm,
          fill: blue.transparentize(80%),
          stroke: (paint: blue, thickness: 1.5pt),
          radius: 0.15cm,
          align(center + horizon, text(
            size: 0.7em,
            weight: "bold",
            fill: blue.darken(30%),
          )[Dense #if size != none { [· #size] }]),
        )
      },
    )),
    name: name,
    stroke: none,
    width: 1pt,
    height: 0.9cm,
    inset: 2pt,
  )

  // Main chain, left to right; each consecutive pair gets an arrow.
  let chain = (
    <lidar>,
    <c1>,
    <c2>,
    <c3>,
    <c4>,
    <flat>,
    <cat>,
    <fc1>,
    <fc2>,
    <fc3>,
    <ln>,
    <out>,
  )

  let other_networks = (
    (name: "Policy head", size: 4, output: "Action distribution parameters"),
    (name: "Value head", size: 1, output: "State-value estimate"),
    (name: "Auxiliary head", size: none, output: "Estimates of privileged targets"),
  )

  figure(
    // Draw at full size with comfortable gaps, then shrink to fit the page.
    scale(70%, reflow: true, diagram(
      spacing: (0.8cm, 0.6cm),
      edge-stroke: 1pt,

      // Input: 50-frame LiDAR stack
      node(
        (0, 0),
        [
          #place(bottom + center, dy: 10pt)[#text(size: 0.6em, "101 rays")]
          #place(horizon + left, dx: -10pt)[#rotate(-90deg, text(size: 0.6em, "50 frames"), reflow: true)]
          #image("figures/lidar_input.png", width: 2cm, height: 2cm)
        ],
        name: <lidar>,
      ),

      // Four 1D convolutions
      conv((1, 0), <c1>, 50),
      conv((2, 0), <c2>, 32),
      conv((3, 0), <c3>, 16),
      conv((4, 0), <c4>, 16),

      // Flatten + concat with the current action
      layer((5, 0), <flat>, [Flatten], green, 3cm),
      layer((6, 0), <cat>, [Concat], teal, 3cm),
      node(
        (6, -1),
        // `place` takes the text out of layout, so the node stays small and
        // the text overhangs instead of being squeezed into the column width.
        place(center + horizon, box(width: 4cm, align(center, text(
          size: 0.7em,
          weight: "bold",
        )[Current steering \ & throttle]))),
        name: <steer>,
        width: 0.9cm,
        height: 0.8cm,
        stroke: none,
      ),

      // Dense head
      fc((7, 0), <fc1>, 128),
      fc((8, 0), <fc2>, 72),
      fc((9, 0), <fc3>, 64),
      layer((10, 0), <ln>, [LayerNorm], red, 2.5cm),

      node(
        enclose: (<lidar>, <c1>, <c2>, <c3>, <c4>, <flat>, <cat>, <fc1>, <fc2>, <fc3>, <ln>, <out>),
        fill: black.transparentize(90%),
        stroke: (paint: black, thickness: 1pt),
        corner-radius: 0.2cm,
        [
          #place(left + top, dy: -25pt)[#text(size: 1.25em, weight: "bold")[Trunk network]]
        ],
      ),

      // Output
      node((11, 0), align(center, text(size: 0.7em)[64-d \ feature]), name: <out>, stroke: none),

      // Arrows along the main chain
      ..chain.zip(chain.slice(1)).map(((a, b)) => edge(a, b, "-|>")),
      edge(<steer>, <cat>, "-|>", stroke: rgb("#0f4d52")),

      // Output heads: horizontal boxes placed side by side below <out>,
      // each with its own arrow from <out>.
      ..other_networks
        .enumerate()
        .map(((i, net)) => {
          let x = 5 + (i - 1) * 3.5 // centred under <out> (x = 11)
          let n = label("head-" + str(i))
          let out_n = label("out-" + str(i))
          (
            head((x, 4), n, net.name, net.size),

            // down from <out>, across at y = 1, then down into the head
            // (the middle head sits at x = 11, so skip the duplicate vertex there)
            edge(..(<out>, (11, 1), (x, 1), n).dedup(), "-|>"),

            edge(n, out_n, "-|>"),

            node(
              (x, 6),
              place(center + horizon, box(width: 6cm, align(center, par(
                text(size: 1em)[#net.output],
                justify: false,
              )))),
              name: out_n,
              stroke: none,
              inset: 8pt,
              width: 1pt,
              height: 0.9cm,
            ),
          )
        })
        .flatten(),
    )),
    caption: [
      The agent's neural network. A 50-frame LiDAR stack passes through four 1D convolutions; the flattened output is concatenated with the current steering and throttle and passed through three dense layers and a layer norm to give a 64-dimensional feature vector. This shared feature vector is then passed to three independent heads: the policy head outputs the parameters of the action distribution, the value head outputs the state-value estimate, and the auxiliary head outputs predictions of privileged targets. The network is drawn at 70% scale to fit on the page.
    ],
  )
} <network_architecture>


=== Action Distributions
The policy head outputs a location $mu$ and a raw scale value $x$ for each of
throttle and steering. Each action is sampled independently from a
tanh-squashed Gaussian,
$ a = tanh(u), quad u tilde cal(N)(5 * tanh(mu / 5), sigma^2), $
so that $a in (-1, 1)$.

The mean is transformed with a tanh to soft-clamp it to the range $(-5, 5)$ using `tanh_loc=True` in the TorchRL `TanhNormal` distribution. This prevents the mean from growing too large, which would push samples into the saturated region of the squashing function and make it difficult for the policy to recover since gradients vanish there. The constant factor of 5 is the heuristically chosen default factor configured in TorchRL @bou2023torchrldatadrivendecisionmakinglibrary.

The standard deviation is made positive with a softplus, with a small floor to ensure that the distribution is never degenerate:
$sigma = op("softplus")(x) + 10^(-3).$

The policy head's linear layer uses a weight initialisation with
gain $0.01$ and zero bias, so every output is close to $0$ at the start. Hence
$mu approx 0$, and both actions are centred near the middle of their range.

This is important because the derivative of the squashing $tanh$ function is
$ (dif a) / (dif u) = 1 - tanh^2(u), $
which goes to $0$ as $|u|$ grows. If the head's outputs start large, samples
land in the saturated region, the gradient of the policy loss with respect to
$mu$ is almost zero, and the policy cannot recover. In early experiments this
is exactly what happened: the car locked at full throttle and full steering in either the positive or negative direction.

=== Auxiliary heads

Using privileged information during training has the potential to improve the agent's performance, as discussed in @sec:learning_methods_privileged_information. We opt to use privileged information in the form of auxiliary losses, which are additional loss terms that encourage the agent to learn useful representations of the environment. These auxiliary losses are computed using privileged information that is not available to the agent during testing, but can be used during training to improve the agent's performance.

Each frame, the environment emits a set of privileged quantities to the trainer, which are used as _auxiliary targets_. The _auxiliary head(s)_ predict these targets during the training process. The auxiliary targets we consider are listed in @auxiliary_targets. During training, the auxiliary losses are added to the PPO loss so that their gradients are combined and backpropagated through the network graph:

$
  cal(L)_"total" = underbrace(cal(L)_"actor" + w_"value" cal(L)_V - w_"entropy" H[pi_theta], cal(L)_"PPO") + sum_(k=1)^K w^((k)) cal(L)_"aux"^((k)),
$

so that
$
  nabla_theta cal(L)_"total" = nabla_theta cal(L)_"PPO" + sum_(k=1)^K w^((k)) nabla_theta cal(L)_"aux"^((k))
$

#figure(
  stb-table(
    columns: 3,
    align: (left, center, left),
    line-between-rows: true,
    header: ([*Target*], [*Units*], [*Description*]),
    [Forward velocity $v_f$],
    [m/s],
    [The component of the agent's velocity in the direction of its forward axis],
    [Lateral velocity $v_l$],
    [m/s],
    [The component of the agent's velocity in the direction of its lateral axis],
    [Yaw rate $omega_y$],
    [rad/s],
    [The rate of change of the agent's heading about its vertical axis],
    [Track curvature ahead $c_d$],
    [1/m],
    [The curvature of the track centerline at $d$ meters ahead of the agent, measured as the reciprocal of the radius of curvature],
    [Per-wheel longitudinal slip $kappa_x$],
    [unitless],
    [The longitudinal slip of wheel $x in {"FR", "FL", "BR", "BL"}$],
    [Per-wheel lateral slip $tan(alpha_x)$],
    [unitless],
    [The lateral slip of wheel $x in {"FR", "FL", "BR", "BL"}$],
  ),
  caption: [The auxiliary targets to be predicted by the agent #footnote([In order to ensure the targets are on a similar scale, the targets are normalised to $sigma = 1, mu = 0$ using a rollout generated from a pure PPO policy (i.e. without auxiliary losses/heads) as data to estimate $sigma$ and $mu$.])],
) <auxiliary_targets>
=== Choice of Auxiliary Loss Function

The choice of auxiliary loss functions $cal(L)_"aux"^((k))$ has the potential to significantly impact the agent's performance. Since we are predicting continuous quantities, it is natural to use a regression loss function such as Squared Error (SE), Absolute Error (AE), or Huber loss @huber1964robust, defined respectively as

$
  cal(L)_"SE" = (hat(y) - y)^2, quad
  cal(L)_"AE" = |hat(y) - y|, quad
  cal(L)_"Huber"^beta (y, hat(y)) = cases(
    1/2 (y - hat(y))^2 "if" |y - hat(y)| <= beta,
    beta |y - hat(y)| - 1/2 beta^2 "otherwise".
  )
$

Throughout, we use PyTorch's rescaled implementation of the Huber loss (`smooth_l1_loss`), $(cal(L)^beta_"Huber" (y, hat(y))) / beta$. Dividing by $beta$ decouples the threshold from the gradient: the rescaled loss is quadratic with gradient $delta = y - hat(y)$ for $|delta| <= beta$, and linear with a constant gradient of magnitude $1$ for $|delta| > beta$, so that the parameter $beta$ sets only the transition point and not the slope of the linear region.

The Huber loss is a robust alternative to the SE loss that is far less sensitive to outliers. It behaves quadratically for small errors and linearly for large ones, with the transition point set by a threshold parameter $beta$. As visualised in @huber_vs_mse_diagram, this means the gradient magnitude is bounded no matter how large the prediction error grows, whereas the L2 gradient grows without limit. Unlike the L1 loss, whose gradient changes sign abruptly at zero, the Huber loss is smooth there, so the gradient shrinks gradually as the error approaches zero.

#{
  let xs = lq.linspace(-3, 3, num: 100)
  let beta_val = 1
  let huber-loss = x => {
    if calc.abs(x) <= beta_val {
      return 0.5 * calc.pow(x, 2)
    } else {
      return calc.abs(x) - 0.5 * beta_val
    }
  }
  let squared-error = x => 0.5 * calc.pow(x, 2)
  let absolute-error = x => calc.abs(x)
  figure(
    lq.diagram(
      xlabel: [Prediction error ($delta = y - hat(y)$)],
      ylabel: [Loss value ($cal(L)$)],
      width: 300pt,
      xlim: (-3, 3),
      lq.plot(xs, xs.map(absolute-error), mark: none, stroke: 2pt + red),
      lq.plot(xs, xs.map(squared-error), mark: none, stroke: 2pt + orange),
      lq.plot(xs, xs.map(huber-loss), mark: none, stroke: 2pt + blue),
      lq.vlines(beta_val, -beta_val, stroke: 1pt + green.transparentize(20%)),
    ),
    caption: [Rescaled Huber loss (blue) with the transition point at $beta = 1$ (green) vs squared error loss (orange) vs absolute error loss (red) for prediction errors $delta$.],
  )
} <huber_vs_mse_diagram>

The Huber loss's bounded gradient is particularly useful when the target values have a heavy-tailed, non-normal distribution, since the loss is then far less sensitive to extreme values than the SE loss. This is the case for our auxiliary targets, as visualised in @auxiliary_targets_boxplot.

#figure(
  image("../results/figures/baseline_rollout_train_boxplot.pdf"),
  caption: [Boxplot of the normalised true auxiliary target values collected during a rollout of the baseline policy. It is clear that the targets have so-called "heavy tails".],
) <auxiliary_targets_boxplot>

For this reason, we use the Huber loss for all auxiliary targets, with $beta = 1$. Since the targets are normalised to zero mean and unit variance (@auxiliary_targets), this makes the loss quadratic for errors within one standard deviation - where most#footnote([Proportions of the data within 1 standard deviation of the mean are listed in @sec:prop_data_within_1_sd]) of the fitting takes place - and linear, with a gradient of magnitude $1$, beyond it, so that the few extreme targets cannot dominate the gradient.

== Finding the Optimal Weights

The question naturally arises: how should the weights $w^((k))$ of the auxiliary losses be set? If they are too small, the auxiliary losses will have little effect on the agent's learning. If they are too large, the agent may use all its capacity to optimise the auxiliary tasks and fail to learn a good policy, or the auxiliary task gradients may conflict with the main task gradients, slowing learning. This is an optimisation problem, where the weights are tuned to achieve the best overall performance. Two options exist: choosing the weights before training (hyperparameter tuning), or adapting the weights during training (adaptive weighting).

=== Hyperparameter Tuning

Hyperparameter tuning is a common approach to finding the optimal weights for auxiliary losses. It involves running multiple training experiments with different weight configurations and then evaluating the agent's performance, choosing the configuration that yields the best results. This approach is simple to implement, but it can be computationally expensive and time-consuming. It also lacks a guarantee of finding the optimal weights, as the search space can be large and complex.

The simplest tuning method is a grid search, where a discrete set of weight values is defined for each auxiliary loss and all possible combinations are evaluated. However, this approach can be inefficient, especially when the number of auxiliary losses is large, as the number of combinations grows exponentially with the number of weights considered.

Random search @bergstra2012random is another hyperparameter tuning method, where weight configurations are sampled randomly from a predefined distribution. This approach can be more efficient than grid search, as it allows for exploration of a larger search space without evaluating every possible combination. However, it still requires a significant number of training runs to find the optimal weights.


#{
  let opt = (3.14, 3.14)

  // Shared plot builder: draws the sampled points plus the optimum
  let search-plot(pts, title) = lq.diagram(
    title: title,
    xlabel: [Weight of auxiliary loss 1],
    ylabel: [Weight of auxiliary loss 2],
    xlim: (0.0, 6.0),
    ylim: (0.0, 6.0),
    width: 140pt,
    height: 140pt,
    lq.scatter(
      pts.map(p => p.at(0)),
      pts.map(p => p.at(1)),
      color: blue,
      size: 4pt,
    ),
    lq.scatter(
      (opt.at(0),),
      (opt.at(1),),
      color: red,
      mark: lq.marks.star,
      size: 9pt,
    ),
  )

  // Left: 4x4 grid search, no grid point lands exactly on the optimum
  let grid-vals = (0.5, 2.0, 3.5, 5.0)
  let grid-pts = ()
  for x in grid-vals {
    for y in grid-vals {
      grid-pts.push((x, y))
    }
  }

  // Middle: random search with one point close to the optimum
  let random-near = (
    (0.6, 4.8),
    (1.4, 1.1),
    (2.1, 5.2),
    (4.7, 0.9),
    (5.3, 3.9),
    (0.9, 2.7),
    (4.2, 5.5),
    (5.6, 1.9),
    (1.8, 3.6),
    (3.4, 2.9),
    (2.2, 2.0),
    (3.9, 1.6),
    (3.0, 5.0),
    (5.0, 2.6),
    (1.2, 0.4),
    (4.6, 4.4),
  )

  // Right: same samples, but the nearby point is moved away
  let random-far = random-near.map(p => if p == (3.4, 2.9) { (4.7, 3.6) } else { p })

  figure(
    grid(
      columns: 3,
      column-gutter: 12pt,
      search-plot(grid-pts, [(a) Grid search]),
      search-plot(random-near, [(b) Random search (hit)]),
      search-plot(random-far, [(c) Random search (miss)]),
    ),
    caption: [Grid and random search over two auxiliary loss weights. The red star indicates the optimal weight configuration. (a) shows that a grid search may miss the optimum, but is guaranteed to find a point within $"grid resolution"/2$ of the optimum. (b) shows that random search can find a point very close to the optimum, but (c) shows that it can also miss it entirely.],
  )
}

So-called "smart" hyperparameter tuning methods, such as Bayesian optimisation @snoek2012practical and the tree-structured Parzen estimator (TPE) @bergstra2011algorithms, build a model of the relationship between the weights and the agent's performance. This model is then used to guide the search for optimal weights, allowing for more efficient exploration of the search space. These methods can be more effective than grid or random search, but they can also be more complex to implement and still require multiple training runs. Methods such as Hyperband @li2018hyperband and its asynchronous variant ASHA @li2020asha mitigate this cost by giving each trial a small budget and only continuing the best-performing ones. However, such early-stopping methods may prematurely terminate RL trials that perform more exploration early on, despite performing better in the long run, so they are not ideal for our scenario.

=== Adaptive Weighting
Adaptive weighting is an alternative approach that dynamically adjusts the weights of the auxiliary losses during training based on factors like the magnitude of the gradients or the error of the auxiliary predictions. Various methods have been introduced in the literature, such as GradNorm @chen2017gradnorm, weights tasks that are learning slower more heavily, and Uncertainty Weighting @kendall2018multitask-cvpr, which uses the model's uncertainty in each task to determine the weights. These methods are useful in multi-task learning scenarios, where the performance of all tasks is important, but they are not ideal for our scenario, where the main task (driving) is the only one that matters. In this case, we want to combine auxiliary losses in such a way that improves the main task's performance, not to balance the performance of all tasks.

==== PCGrad

PCGrad @yu2020gradientsurgerymultitasklearning is a method that modifies the gradients of auxiliary tasks to prevent them from conflicting with the main task's gradients. It does so by projecting the auxiliary task gradients onto the normal plane of the main task's gradient if they conflict. Let $bold(g)_"aux"^((k))$ be the gradient of the model parameters for the $k$-th auxiliary loss and $bold(g)_"PPO"$ be the gradient of the main task loss. If the dot product $bold(g)_"aux"^((k)) dot bold(g)_"main" < 0$, then the auxiliary gradient is projected onto the normal plane of the main task gradient:

$
  bold(g) = bold(g)_"PPO" + sum_(k=1)^K cases(
    bold(g)_"aux"^((k)) - frac(bold(g)_"aux"^((k)) dot bold(g)_"PPO", ||bold(g)_"PPO"||^2) bold(g)_"PPO" "if" bold(g)_"aux"^((k)) dot bold(g)_"PPO" < 0,
    bold(g)_"aux"^((k)) "otherwise"
  )
$

== Metrics
=== Progress
Let $L$ be the total length of the track centreline. At any time $t$, let $d_t in [0, L)$ be the agent's current arc length from the start of the centerline to the point closest to the agent, and let $N_t$ be the total number of completed laps. We define the agent's _absolute progress_ along the track as the total continuous distance travelled from the start:

$ xi_t = d_t + N_t L $

The _progress per step_ is then simply the change in this absolute position between consecutive timesteps, defined as $xi_t - xi_(t-1)$. Because $xi_t$ tracks the cumulative distance across multiple laps, this raw difference naturally handles crossing the finish line without requiring any wrapping operations or modulo arithmetic.

Using this step-wise progress as a reward signal is approximately equivalent to a potential-based reward shaping function @ng1999policy. In this context, the absolute progress $xi_t$ serves as the potential function $Phi(s_t)$ of the current state. Because the reward is defined as the difference in potential, $Phi(s_t) - Phi(s_(t-1))$, it heavily incentivises continuous forward movement along the track while theoretically preserving the optimal policy and preventing the agent from exploiting positive-reward cycles.

=== Crash rates
The _crash rate per episode_ is the fraction of total episodes that terminate in a collision rather than reaching the maximum length.

The _crash rate per timestep_ is the total number of collisions divided by the total number of timesteps executed. These metrics diverge because episodes terminate early upon a crash; surviving longer before a collision increases the timestep denominator, inherently lowering the per-timestep crash rate.

The _collisions per metre of progress along the centerline_ is the total number of crashes divided by the total distance the agent successfully advances along the track centerline. This metric normalizes failures against spatial progression rather than time, isolating driving competence from the agent's velocity.

=== Reward function <sec:reward_function>
The agent receives a dense reward at each timestep that encourages fast, collision-free progress along the track:

$ r_t = w_p dot (xi_t - xi_(t-1)) - w_c dot c_t $

The first term rewards forward progress, using the progress per step defined above. The second term penalizes collisions: the indicator variable $c_t$ equals 1 if a collision occurs with an obstacle at time $t$, and 0 otherwise.

The weights $w_p$ (reward per metre of progress) and $w_c$ (penalty per collision) balance speed against safety based on the risk tolerance of the application. We set $w_p = 1.0$ and $w_c = 1.0$. Because an episode terminates immediately upon collision, there is already a strong implicit penalty for crashing, allowing $w_c$ to remain relatively low.

=== Area Under the Curve (AUC)
The _Area Under the Curve_ (AUC) evaluates sample efficiency and learning stability by calculating the definite integral of a performance metric $y(t)$ (e.g., return or progress per step) over the total training time or timesteps $T$:

$ "AUC" = integral_0^T y(t) dif t $

In practice, evaluation metrics are recorded at discrete interval checkpoints $t_0, t_1, ..., t_N$, and the AUC is computed using the trapezoidal rule:

$ "AUC" approx sum_(i=1)^N frac(y(t_(i-1)) + y(t_i), 2) (t_i - t_(i-1)) $

A higher AUC indicates faster learning and superior performance throughout the entire training process rather than merely achieving high final performance.

== Trainer Performance Tuning
Training was performed on a single machine with an AMD Ryzen Threadripper PRO 3995WX CPU (64 cores, 128 hardware threads) and 128 GB of RAM. To ensure experiments finish in a practical time, we first measured how best to use this hardware, aiming to maximise _aggregate_ throughput: environment timesteps collected and learned from per second, summed across all models training simultaneously.

We ran a grid search over the parameters in @training_performance_variables: concurrent trainers (2, 4, 8, 12), Python threads per trainer (8, 16) and parallel environments per trainer (4, 8, 10, 16). For each configuration, `concurrent_trainers` identical processes were launched at once, each running five PPO iterations (a 256-frame rollout plus four epochs of minibatch updates each iteration) with checkpointing and TensorBoard logging disabled. Configurations with more than 8 trainers and 16 environments (128 or more concurrent Unity instances) exhausted memory and were excluded, leaving 28 single-run configurations. Throughput per trainer was computed from the mean wall-clock time per iteration:

$ "throughput" = ("rollout length" times "parallel envs" times "areas per env") / "seconds per iteration" $

We report the throughput per trainer, showing how much each model slows as the machine gets busier, and summed across trainers, showing where adding trainers stops paying off.

As shown in @training_performance_results, total throughput peaks at 8 trainers (4172 timesteps/s with 8 environments and 16 threads) and falls at 12 (at most 3853 timesteps/s), while per-trainer throughput roughly halves from 2 to 8 trainers. The best settings use $8 times 16 = 128$ python threads in total, matching the hardware thread count; at 12 trainers the 16-thread configurations are oversubscribed and fall behind the 8-thread ones. We therefore chose (`concurrent_trainers`, `num_inst`, `python_threads`) = (8, 8, 16), though its margin over the next-best configurations (4020 and 3962 timesteps/s) is within likely run-to-run variation. Using `num_areas` $in {8, 12}$ per environment in this configuration did not help (3844 and 3999 timesteps/s).

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
    [`num_inst`],
    [${4, 8, 10, 16}$],
    [Number of Unity environment instances per trainer. Each contains 6 training areas, so each instance steps 6 agents in parallel.],
  ),
  caption: "Parameters varied in the training performance grid search.",
) <training_performance_variables>

= Experiments & results

== Baseline Model Performance

The baseline model trained with the PPO loss and no auxiliary targets performed well in its primary task. It achieved a crash rate per meter of progress of #todo("Amount") and a reward AUC of #todo("Amount").

To establish what the baseline represents without auxiliary supervision, linear probes were fit to the output of the final trunk layer (fc3) to predict each auxiliary target. Each probe is an OLS regression model trained on activations from a \~35-minute rollout  (52429 timesteps) and evaluated on a separate \~9-minute rollout (13107 timesteps). @baseline_lr_model_dumbell reports out-of-sample R² at initialisation and after 600 PPO iterations, with error bars showing the standard deviation between each different trained agent model.

Two distinct patterns emerge. Quantities describing the vehicle’s instantaneous dynamics (yaw rate, lateral velocity and lateral wheel slip) are already linearly decodable at initialisation (R² ≈ 0.8–0.9). Since the network is untrained, this reflects information that is close to linear in the observation and survives a series of random LeCun-initialised projections, rather than a learned representation. A similar effect was observed in @alain2018understandingintermediatelayersusing when investigating the same phenomenon in toy MNIST models. Training does not improve the $R^2$ for these quantities, and decodability declines modestly (e.g. rear lateral slip falls from $R^2 = \~0.67$ to \~0.50), suggesting that PPO discards some of this information.

@probe_baseline_heatmap visualises the trend over time: as the model trains, the decodability of the instantaneous dynamics quantities declines, while the decodability of the close-ahead ($<= 3m$) track curvature improves almost monotonically (highlighted in white boxes). This suggests that these quantities may prove to be useful auxiliary targets, as the auxiliary losses will encourage the model to learn their representations earlier. The model does not significantly learn to represent the further-ahead curvature (4.0m - 8.0m), which presents itself as another candidate for an auxiliary target.

#figure(
  image("../results/figures/probe_dumbbell.pdf", height: 150pt),
  caption: [Out-of-sample $R^2$ scores of linear regression probing of the final layer of the trunk on the baseline model.],
) <baseline_lr_model_dumbell>

#figure(
  image("../results/figures/probe_heatmap.pdf", height: 200pt),
  caption: [Mean out-of-sample $R^2$ scores of linear regression probing of the final layer of the trunk on the baseline model, showing how much each quantity is linearly decodable at each iteration of training. Note that the y-axis is not evenly spaced.],
) <probe_baseline_heatmap>

== Learned Features After Auxiliary Learning <sec:learned_features_after_auxiliary_learning>


Consider the arbitrary network in @example_network_diagram. Once trained, each layer $l$
maps an input $bold(x)$ to an intermediate representation
$bold(h)^((l)) = f_l (bold(x); theta)$, which becomes the input to the following layer. We would like to know what
information these representations encode, and in particular whether they encode
privileged state variables (e.g. velocity, slip, upcoming curvature).


#figure(
  caption: "Example network architecture. The first two layers are convolutional layers, taking stacked LiDAR frames as input. The following 4 layers are fully connected layers with ReLU activations.",
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
        connection-label: $bold(h)^((0))$,
      ),
      (
        type: "conv",
        label: "Conv1D",
        channels: (1, 50),
        connection-label: $bold(h)^((1))$,
      ),
      (
        type: "fc",
        label: "fc1",
        connection-label: $bold(h)^((2))$,
      ),
      (
        type: "fc",
        label: "fc2",
        connection-label: $bold(h)^((3))$,
      ),
      (
        type: "fc",
        label: "fc3",
        connection-label: $bold(h)^((4))$,
      ),
      (
        type: "output",
        label: "output",
        connection-label: $bold(h)^((5))$,
      ),
    ),
    show-relu: true,
  )),
) <example_network_diagram>

Alain and Bengio @alain2018understandingintermediatelayersusing introduced
_linear probes_ for this purpose. The main network's weights are frozen, and a
separate linear classifier (the probe) is trained in a supervised manner on the representations
$bold(h)^((l))$ of each layer to predict the desired target. Since the
probe cannot change the representation, its test accuracy measures how much
class information is _linearly_ available at that layer. Anand et al.
@anand2020unsupervisedstaterepresentationlearning extended this idea to
reinforcement learning, probing an encoder's representations for ground-truth
state variables of Atari games (read from the console's RAM).

The choice of a _linear_ probe is deliberate. A sufficiently expressive probe
(e.g. a deep MLP) may compute the target from almost any input, including the
raw network input, so high probe accuracy would say more about the probe than
about the representation @belinkov2021probingclassifierspromisesshortcomings.
Restricting the probe to a linear map means that it can only succeed if the
network has already done the work of encoding the target along some direction in the representation space.

Many of the privileged variables of interest are continuous rather than
categorical, so we use a linear _regression_ probe instead of a classifier, as
done by McGrath et al. @mcgrath2022alphazero to probe AlphaZero for chess
concepts and by Gurnee and Tegmark @gurnee2024languagemodelsrepresentspace to probe language
models for spatial and temporal encodings.

The model is now trained with the same reward function (@sec:reward_function) as the baseline model, but with the addition of one or more auxiliary heads (and their associated auxiliary losses).

=== Forward velocity, lateral velocity, and yaw rate

=== Track curvature

The close-ahead ($<= 3m$) track curvature auxiliary loss was extremely effective in improving the decodability of the trunk's final layer. It improved the out-of-sample $R^2$ scores in close-ahead curvature quantities by between +35 to +49 percentage points, and even improved the decodability of unsupervised quantities such as the 3.5m-ahead curvature and 4.0m-ahead curvature by between +5 to +10 percentage points on average.

To a lesser extent, the medium-ahead (between 3m- and 6m-ahead) curvature auxiliary loss improved the decodability of its supervised quantities, resulting in a +7 to +26 percentage point improvement in out-of-sample $R^2$ scores.

However, far ahead curvature failed to improve the decodability significantly, with small gains of up to +4 percentage points, and all groups of auxiliary losses decreased performance on the forward slips of wheels. #todo("WHY?")


=== Wheel slips


#figure(
  image("../results/figures/probe_heatmap_aux_summary.pdf"),
  caption: [Mean out-of-sample $R^2$ scores of linear regression probing of the final layer of the trunk on models trained with different auxiliary heads enabled. Bold = C.I. excludes 0, corrected for false discovery rate using the Benjamini-Hochberg procedure @benjamini1995controlling],
)




== Agent Performance After Auxiliary Learning
In line with the findings from @sec:learned_features_after_auxiliary_learning, the auxiliary head that was most effective in improving the agent's performance was the close-ahead curvature head. It resulted in a measurably higher reward AUC compared to the baseline model, as visualised in @fig:auc_comparison. Note that because the model restarts after a crash, the reward AUC is only slightly influenced by the crash penalty (an average of 2.71 reward is generated per second vs -1 per crash). It is therefore important to monitor the performance of the agent in terms of each metric individually, as visualised in @fig:last_50_means_heatmap, where the metrics (y-axis) are averaged over the last 50 training iterations and compared to the baseline model's mean. We find that the curvature close model achieves both higher racing performance, as well as safety: it achieves a +12.5% higher mean progress per timestep along with a -38% collision rate per metre of progress at an auxiliary loss weight of $omega_"aux" = 1.0$. Similar, though less pronouncd results are achieved by the front wheel forward slip head, which is, in fact, safer (-)


#figure(
  image("../results/figures/auc_comparison.pdf"),
  caption: [Reward AUC of the models trained with different auxiliary losses and loss weights over their 600 training iterations, compared to the baseline model],
) <fig:auc_comparison>

#figure(
  image("../results/figures/last_50_means_heatmap.pdf"),
  caption: [Mean of the last 50 training iterations of each model's metrics (mean reward, mean progress per timestep, mean forward velocity, mean number of collisions per metre of progress, mean number of collisions per episode, and mean number of collisions per timestep) vs the baseline model. Bold = statistically significant ($alpha = 5%$). No false discovery rate correction. @benjamini1995controlling],
) <fig:last_50_means_heatmap>


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

== AI Declaration

- #link("http://claude.ai")[Claude] was used for searching literature, checking the report for errors, advice on clarity of writing, and changing the format of references from BibTex to Hayagriva. Furthermore, Claude was used to explain various tensor shape bugs in PyTorch code, but the final implementation was always done manually, as well as to explain how TorchRL works. Initially, Claude was used to generate diagrams, but I did not like how little control I had over the diagrams, so re-implemented them manually from scratch. Claude was used to generate parts of @fig:walk-step based on a handmade diagram. Claude was used to explain why certain training setups may perform badly on the hardware available. Claude was used to provide code to perform the FDR analysis on @aux_head_regression_results

- #link("https://gemini.google.com")[Google Gemini] was used to a lesser extent for searching literature, and, before starting the project, for assistance in understanding RL in conjunction with the #link("https://www.youtube.com/watch?v=2pWv7GOvuf0")[David Silver Videos]. Gemini was instrumental in explaining potential-based reward shaping in an easy-to-understand way.

- #link("https://scholar.google.co.za/scholar_labs/search")[Google Scholar Labs] was used extensively in searching for literature.
- #link("http://chat.deepseek.com")[DeepSeek] was used to search for literature, and to provide input on the structure and content of the report. For example, it advised which sections could be reduced in length without sacrificing report quality.

AI was not used to generate the training code or the model definition code - that was completely hand-written.

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
== Proportion of Data Within 1 Standard Deviation <sec:prop_data_within_1_sd>

#{
  let data = csv("../results/prop_data_within_1_sd.csv").slice(1)
  figure(
    stb-table(
      columns: 2,
      align: (left, center),
      header: ("Auxiliary target", "Prop. of data within 1 SD of mean"),
      ..data
        .map(row => (
          row.at(0),
          [#calc.round(float(row.at(1)) * 100, digits: 2)%],
        ))
        .flatten(),
    ),
    caption: [Proportion of the normalised auxiliary target data that lies within 1 standard deviation of the mean in the baseline rollout.],
  )
}


#pagebreak()
== Auxiliary Head Regression Results <aux_head_regression_results>
#figure(
  image("../results/figures/probe_heatmap_aux.pdf", height: 84%),
  caption: [Difference in mean out-of-sample $R^2$ vs the baseline PPO model. The X-axis shows the auxiliary target, and the Y-axis shows the auxiliary training configuration. Red boxes indicate the features that are supervised by the auxiliary loss. Bold where the C.I. excludes 0, corrected for false discovery rate using the Benjamini-Hochberg procedure @benjamini1995controlling],
)

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
