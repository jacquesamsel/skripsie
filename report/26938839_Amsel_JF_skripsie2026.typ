#import "@preview/cetz:0.5.2" as cetz: canvas, draw
#import "@preview/lilaq:0.6.0" as lq
#import "@preview/fletcher:0.5.8" as fletcher: diagram, edge, node, rect-at
#import "@preview/algorithmic:1.0.7" as algorithmic: algorithm-figure, style-algorithm
#import "@preview/latex-lookalike:0.1.4"
#import "@preview/neural-netz:0.3.0" as neural-netz: draw-network
#import "@preview/simple-plot:1.1.0": hline, note, plot, vline
#import "@preview/lilaq:0.5.0" as lq
#import "@preview/neural-viz:0.1.0": *
#import "@preview/gantty:0.5.1"

#show: style-algorithm
#show: latex-lookalike.style-outline


#let in-appendix = state("in-appendix", false)

#set ref(supplement: it => {
  if it.func() == heading {
    if it.supplement == none { none } else if in-appendix.at(it.location()) { none } // <- new
    else if it.level == 1 { "Chapter" } else { "Section" }
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
#set par(leading: 0.65em, spacing: 1.05em, justify: true)

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
    #v(40pt)
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
#show heading.where(level: 2): it => {
  if in-appendix.at(it.location()) {
    counter(figure.where(kind: table)).update(0)
    counter(figure.where(kind: image)).update(0)
    counter(figure.where(kind: raw)).update(0)
  }
  stb-heading(17pt, 1em, 1em)(it)
}
#show heading.where(level: 3): stb-heading(14pt, 1.6em, 1em)
#show heading.where(level: 4): stb-heading(12pt, 1.4em, 1em)

// --- Title page: \LARGE, no bold (stb-titlepage.sty) ---------
#show title: set text(size: 20pt, weight: "regular")

// --- Figures and tables: numbered per chapter, captions at
// \small with a bold label (caption package: small, bf, rm).
#set figure(
  numbering: n => {
    let h = counter(heading).get()
    if in-appendix.at(here()) {
      numbering("A.1", h.at(1, default: 0), n)
    } else {
      numbering("1.1", h.first(), n)
    }
  },
  gap: 8pt,
)
#show figure: set block(above: 1.8em, below: 1.8em)
#show figure.caption: it => context {
  set text(size: 11pt)
  set par(justify: false, leading: 0.65em, first-line-indent: 0pt)
  pad(x: 1.5em)[
    #align(left)[
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



  #block(title("Backseat driving: Using privileged-information auxiliary losses in autonomous racing"), width: 400pt)

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
#set par(justify: true, first-line-indent: (amount: 1.5em, all: true))

= Acknowledgements

This work would not have been possible without the mentorship of my supervisor, Dr. JC Schoeman, who provided valuable guidance and feedback throughout the project, for which I am deeply grateful. I would also like to thank my friends and peers for their encouragement and support, as well as my family for their support throughout my studies. Finally, I would like to thank the developers of the open-source software and libraries that were used in this project, including, but not limited to, PyTorch, NumPy, Matplotlib, Seaborn, Pandas, Python, and Ubuntu. Without their contributions, this work would have been immensely more difficult.

#pagebreak()
#v(1fr)
#align(center)[
  "Now, this is podracing!"

  \- _Anakin Skywalker in Star Wars: The Phantom Menace_
]
#v(1fr)

#pagebreak()

= Plagiarism declaration

1. Plagiaat is die oorneem en gebruik van die idees, materiaal en ander intellektuele eiendom van ander persone asof dit jou eie werk is. _Plagiarism is the use of ideas, material and other intellectual property of another’s work and to present it as my own._
2. Ek erken dat die pleeg van plagiaat 'n strafbare oortreding is aangesien dit ‘n vorm van diefstal is. _I agree that plagiarism is a punishable offence because it constitutes theft._
3. Dienooreenkomstig is alle aanhalings en bydraes vanuit enige bron (ingesluit die internet) volledig verwys (erken). Ek erken dat die woordelikse aanhaal van teks sonder aanhalingstekens (selfs al word die bron volledig erken) plagiaat is. _Accordingly all quotations and contributions from any source whatsoever (including the internet) have been cited fully. I understand that the reproduction of text without quotation marks (even when the source is cited) is plagiarism._
4. Ek verklaar dat die werk in hierdie skryfstuk vervat, behalwe waar anders aangedui, my eie oorspronklike werk is en dat ek dit nie vantevore in die geheel of gedeeltelik ingehandig het vir bepunting in hierdie module/werkstuk of ‘n ander module/werkstuk nie. _I declare that the work contained in this assignment, except where otherwise stated, is my original work and that I have not previously (in its entirety or in part) submitted it for grading in this module/assignment or another module/assignment._

#v(1fr)
#table(
  columns: (1fr, 1fr),
  align: bottom + left,
  rows: (2.5cm, 2.5cm),
  [Student number #place(horizon + center)[#text("26938839", size: 24pt)]],
  [#place(horizon + center)[#image("./signature.png")]
    Signature
  ],

  [Initials and surname #place(horizon + center)[#text("JF Amsel", size: 24pt)]],
  [Date #place(horizon + center)[#text(datetime.today().display("[day] [month repr:long] [year]"), size: 24pt)]],
)

#pagebreak()

= Abstract

End-to-end reinforcement learning (RL) agents can drive a car directly from raw sensor data. However, an agent that drives from LiDAR alone must learn quantities it cannot observe, such as its own velocity, its tyre slip, and the curvature of the track ahead. In simulation, these quantities are available as privileged information, but the reward gives only an indirect, high-variance signal for learning them. This project investigates whether auxiliary losses for predicting privileged information from the policy's shared representation can improve the training speed, racing performance, and internal representations of a LiDAR-only racing agent.

A custom racing simulator was built in Unity, with dynamics calibrated to the RoboRacer platform, and a procedural track generator. Both feedforward and recurrent agents were trained with Proximal Policy Optimisation (PPO), and linear probes were used to measure which privileged quantities their learned representations encode. Ten categories of auxiliary targets were each evaluated at three loss weights across 6 seeds: velocities, yaw rate, track curvature at three lookahead distances, and per-wheel slip.

Probing shows that the baseline agents already encode the vehicle's instantaneous dynamics at initialisation, and that training trades this information away in favour of upcoming track curvature. Close-ahead track curvature (up to 3m ahead) is the only auxiliary target that meaningfully benefits both architectures. Most other targets degrade the feedforward agent, while the recurrent agent benefits from many of them, which suggests that auxiliary losses chiefly ease the training of the harder-to-train architecture. Finally, making a quantity more decodable does not always improve driving, and the effect of each target depends strongly on its loss weight.



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

- *Capital vs. lowercase:* A capital letter is a random variable ($S_t$, $A_t$, $O_t$), and the matching lowercase letter is a particular realized value of it ($s_t$, $a_t$, $o_t$).
- *Calligraphic letters* denote sets or spaces: $cal(S)$, $cal(O)$, $cal(A)$ are the state, observation, and action spaces. Exceptions are the reward function $cal(R): cal(S) times cal(A) times cal(S) -> RR$, the observation function, $cal(Z): cal(S) -> Delta_cal(O)$, and the transition function $cal(P): cal(S) times cal(A) -> Delta_cal(S)$, which are not sets or spaces. Lowercase symbols denote quantities that live in the corresponding space, e.g. $s in cal(S)$.
- *Subscript $t$* indexes time, so $x_t$ is the quantity $x$ at time step $t$.
- *Subscript $theta$* marks dependence on learnable parameters, e.g. $pi_theta$.
- *Superscript $pi$* means "under policy $pi$", e.g. $V^pi$, $Q^pi$, $A^pi$.
- *Hat* marks an estimate: $hat(X)$ estimates the random variable $X$, and $hat(x)$ is a sample estimate of it. $hat(P)(X = x)$ is a sample estimate of the probability that $X = x$.
- *Tilde* means "distributed as": $X ~ Y$ is exact, and $X dot(~) Y$ is approximate.
- *Conditioning bar:* In $f(a | b)$, quantities after the bar are given. This holds for both probabilities and expectations.
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

  table.cell(colspan: 2)[*Calculus*],
  [$nabla_theta f(theta)$], [Gradient of the function $f(theta)$ with respect to parameters $theta$],

  table.cell(colspan: 2)[*Probability and statistics*],
  [$x plus.minus y$], [The mean $x$ with sample standard deviation $y$],
  [$Delta_cal(Y)$], [Set of all probability distributions with support $cal(Y)$],
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
  ("SE", "Standard error"),
  ("CNN", "Convolutional neural network"),
  ("RNN", "Recurrent neural network"),
  ("PPS", "Progress per second"),
  ("CPMP", "Collisions per metre of progress"),
  ("GRU", "Gated recurrent unit"),
  ("LSTM", "Long short-term memory"),
  ("OLS", "Ordinary least squares"),
  ("FF", "Feedforward"),
  ("SEM", "Standard error of the mean"),
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

Road traffic crashes remain a leading cause of death and serious injury worldwide @who2018roadsafety, and the overwhelming majority are attributed to human error @hankey1999identification, as cited by Medina et al. @medina2004relationshipinfrastructuredrivererror. Autonomous driving promises to reduce severe and fatal accidents @olofsson2021crashdatabases, improve traffic flow @VanDriel2010congestion, and reduce emissions @ignlinski2017autonomous-vehicles-ghg. Before such systems can be trusted on public roads, however, they must handle difficult situations, where small mistakes compound quickly. Autonomous racing is a demanding proxy for these situations because high speeds, tight control margins, and short recovery times stress the driving policy.

Broadly, autonomous driving control architectures fall into two paradigms: modular pipelines and end-to-end learning. Modular pipelines decompose the driving task into distinct sub-problems, such as perception, planning, and control; this provides interpretability and simplifies debugging, but often demands extensive domain expertise and manual tuning. End-to-end learning instead maps raw sensor inputs (e.g., LiDAR or camera frames) directly to control outputs (e.g., speed and steering angle). It avoids hand-engineered intermediate representations, but typically requires vast amounts of data and suffers from poor interpretability, making failures difficult to diagnose @chen2020interpretableendtoendurbanautonomous.

Auxiliary learning, as popularised by Jaderberg et al. @jaderberg2017unreal, presents a compelling method to address these shortcomings. By training a model to perform secondary tasks alongside its primary control objective, the network is encouraged to learn richer, more structured intermediate representations @rafiee2022makesusefulauxiliarytasks while improving interpretability @chen2020interpretableendtoendurbanautonomous. In simulation, privileged ground-truth state is available during training even when it is unavailable to the deployed policy. This motivates the question of whether such auxiliary signals can improve an end-to-end racing agent that must drive from limited onboard sensing.

== Problem Statement and Objectives <sec:problem_statement_and_objectives>
An end-to-end reinforcement learning (RL) agent that drives from LiDAR alone has to learn representations of privileged information that it cannot directly observe in the real world: its own velocity and slip, upcoming track curvature, and, in Head-to-Head (H2H) racing, the opponent's location. Early in training, the agent has not yet learned to drive well enough to explore the track effectively, so the reward signal that would teach it these representations is sparse and noisy. This can slow convergence and lead to sub-optimal policies. Privileged information is, however, available in simulation.

The objective of this report is to investigate whether _auxiliary heads_ that predict privileged information from the policy's shared representation can improve a LiDAR-only end-to-end racing agent. The objectives are to:

#set enum(numbering: "(a)")
+ select an appropriate simulation environment for autonomous racing;
+ implement a baseline end-to-end RL agent that drives from LiDAR alone;
+ quantify what representations the baseline agent natively encodes;
+ implement auxiliary learning to provide additional supervisory signals to the agent during training; and
+ compare the auxiliary-learning agent against the baseline on driving performance and representation quality.
#set enum(numbering: "1.")

== Solution Overview and Scope

The project was executed in three phases: simulation development, baseline evaluation, and auxiliary learning experimentation. First, a custom 3D racing simulator was built in Unity using PhysX-based vehicle dynamics and a procedural track generator. This custom simulator was benchmarked against the standard F1Tenth Gym @okelly2020f1tenthgym. Second, a baseline end-to-end reinforcement learning (RL) agent was trained with Proximal Policy Optimisation (PPO) and a dense progress-based reward. Third, auxiliary heads were added to the network to predict privileged state information during training. The motivation for this approach is developed in the following chapters.

The scope is limited to simulation; no sim-to-real transfer to a physical RoboRacer was attempted. The agent drives from LiDAR and its current steering and throttle only, using either a memoryless feedforward policy, or a recurrent policy. Learning is done using PPO, and auxiliary losses are studied; auxiliary rewards and reward shaping are discussed as background but not evaluated. Only single-agent racing is studied, so opponent information is not considered.


== Report Outline

@sec:related_literature reviews the background and related literature. It contrasts classical modular pipelines with end-to-end learning approaches to autonomous racing, and surveys how privileged information has previously been exploited through other methods. The chapter closes by identifying the gap in the literature that this report addresses: auxiliary losses have not been studied for LiDAR-only end-to-end racing agents, and it is unknown which privileged targets help or how they reshape the policy's representation.

@sec:system_overview provides a brief system overview, describing how the simulator and Python training script communicate, and how observations, actions, and rewards flow between them.

@sec:simulator presents the custom Unity simulator. It justifies the choice of simulator, benchmarking it against the F1Tenth gym, and describes the vehicle dynamics implemented, as well as the procedural track generation and privileged information available during training.

@sec:training describes the agent and auxiliary learning method. It formalises racing as a POMDP, introduces PPO and the network architecture, and defines the auxiliary targets, loss functions, and weighting strategy, together with the metrics used for evaluation.

@sec:results reports the experiments performed and their results. It first characterises the baseline agent's performance, and, using linear probes, what its internal representation natively encodes; it then evaluates each auxiliary configuration against the baseline on driving performance and representation quality. This chapter tests the central claim that auxiliary losses improve both representation learning and racing behaviour.

@sec:conclusion concludes the report. It summarises the findings against the objectives, discusses limitations, and outlines future work, thereby placing our contributions in the context of the broader autonomous racing literature.

= Background and Related Literature <sec:related_literature>

Before we can motivate the use of auxiliary losses to exploit privileged information to improve a LiDAR-only end-to-end racing agent, we first review the literature on autonomous racing. We contrast classical modular pipelines with end-to-end learning approaches, and survey how privileged information has previously been exploited through other methods. This chapter closes by identifying the gap in the literature that this report addresses: auxiliary losses have not been studied for LiDAR-only end-to-end racing agents, and it is unknown which privileged targets help or how they reshape the policy's representation.

== Previous Approaches
Evans et al. @evans2024unifyingf1tenthautonomousracing present a survey breaking down the autonomous racing literature in RoboRacer into two categories: _classical approaches_ and _learning approaches_. We shall provide a brief overview of classical approaches, and then focus on learning approaches, which are more relevant to this project.

=== Classical approaches

Classical approaches generally decompose the driving task into three stages: perception, planning, and control @evans2024unifyingf1tenthautonomousracing. Perception is the process of converting raw sensor inputs into a representation of the environment, such as a map of the track and the location of other vehicles. Planning uses this representation to generate a trajectory for the vehicle to follow, and control executes this trajectory by sending commands to the vehicle's actuators. These approaches tend to be more interpretable and easier to debug @tampuu2022surveyofendtoenddriving, as each component can be analysed separately @yurtsever2020surveyofautonomousdriving.

=== Learning approaches

Learning approaches, which have recently shown promise in the field of autonomous driving in simulation @wurman2022outracing @lee2025outracing as well as in deployment on a physical vehicle @czechmanowski2025learningracingpoliciesreinforcement, are often end-to-end, mapping raw sensor inputs directly to control outputs @yurtsever2020surveyofautonomousdriving. This can be done using supervised learning (such as behaviour cloning @pomerleau1988alvinn), where the model is trained on a dataset of expert demonstrations, or using reinforcement learning @sutton2018, where the model learns by interacting with the environment and receiving feedback in the form of rewards.

Learning approaches have the potential to learn complex behaviours that are difficult to hand-engineer, and can adapt to changing environments @bosello2022traininaustria. However, they often require large amounts of data and computational resources @srinivasan2023reinforcementlearningadvancementslimitations, and can be less interpretable than classical approaches; deep end-to-end learning approaches are often regarded as "black boxes" @samek2017explainableartificialintelligenceunderstanding, which may be undesirable in safety-critical applications @chi2017deepsteeringlearningendtoend like driving. In RoboRacer, learning approaches have shown promise, but were unable to outperform classical approaches in benchmarks @evans2024unifyingf1tenthautonomousracing, and recently the majority of 27th RoboRacer Autonomous Racing Competition entries were classical approaches @mallon2026roboracer, despite learning approaches generalising better to unseen tracks @bosello2022traininaustria.

== Learning Methods Using Privileged Information <sec:learning_methods_privileged_information>

During training in simulation, information that is not available to the agent at inference time is available. This information is referred to as _privileged information_, and is usually unused. There are, however, several methods that use privileged information to improve the performance of an agent.

Common ways to use privileged information include as inputs to training-only components (e.g., an asymmetric critic), as inputs to a teacher for distillation, and as auxiliary rewards or losses. We provide these examples to illustrate how other methods use privileged information, and to motivate the use of auxiliary losses as an alternative method for autonomous racing.


=== Asymmetric Actor-critic Methods
Asymmetric actor-critic methods @pinto2017asymmetricactorcriticimagebased are a variant of actor-critic methods that train two distinct models: one for the policy, which chooses the agent's actions and only receives the agent's observations as input, and one for the critic, which receives additional privileged information as input. The critic is used to estimate the value of each state, which is then used to update the agent to choose actions that lead it into more valuable states. Vasco et al. @vasco2024superhumanvisionbasedreinforcementlearning show that an asymmetric critic can achieve better-than-human performance using a vision-based RL agent in a simulated autonomous racing environment, and perform better than a baseline symmetric actor-critic agent.

=== Teacher-student distillation

Teacher-student distillation @hinton2015distillingknowledgeneuralnetwork involves training a teacher model with access to privileged information, and then using the teacher's outputs to train a student model that does not have access to this information. The student model is trained to mimic the teacher's behaviour, effectively learning from the teacher's understanding of its privileged knowledge. Xu et al. @xu2026visionbasedpolicylearninghighspeedautonomousracing applied this method to LiDAR-based autonomous racing on the RoboRacer platform, and found that the student model was able to achieve better performance than a baseline model trained without a teacher.


=== Auxiliary learning

Auxiliary learning is a method that falls under the umbrella of multi-task learning, where a model is trained to perform multiple tasks simultaneously. Specifically, in auxiliary learning, the model's performance on the auxiliary task is not an objective in itself, but the model's performance on the auxiliary task is used to improve its performance on the primary task. This occurs when the auxiliary task provides additional information that can be used to improve the model's understanding of the primary task, which can lead to better generalisation and faster learning @ruder2017overviewmultitasklearningdeep. We focus on two ways of using privileged information as auxiliary tasks: auxiliary rewards and auxiliary losses.

==== Auxiliary Rewards

When privileged information is available, it can be used to construct auxiliary rewards that guide the agent toward desirable behaviors by evaluating performance against sub-goals. For example, in autonomous racing, privileged knowledge of track layout or opponent positions can generate bonuses for staying centered @evans2024unifyingf1tenthautonomousracing or avoiding near-misses.

While auxiliary rewards act as a form of reward shaping - supplying denser feedback to accelerate learning - there is a crucial distinction between auxiliary rewards and reward shaping. Traditional potential-based shaping, where the agent is, for example, rewarded for moving towards a target and penalised for moving away from it, guarantees that the underlying task and optimal policy remain unchanged @ng1999policy. Auxiliary rewards, however, act as heuristic bonuses that are rarely potential-based. Consequently, they risk altering the task being solved, which can cause the agent to converge on suboptimal policies for the original objective @ng1999policy.

==== Auxiliary losses

The incorporation of _auxiliary heads_ that predict privileged information into a model, and use of supervised _auxiliary losses_ to train them, has emerged as a promising technique for improving the performance, interpretability, and training time of end-to-end learning approaches. It does so in three ways: it reduces the variance of the learning signal, it allows privileged information to be used even when it is unavailable at inference time, and it improves representation quality @jaderberg2017unreal @navon2021auxiliarylearningimplicitdifferentiation.

Examples of auxiliary learning with privileged information prediction include Lample et al. @lample2017fps who demonstrated outstanding performance in first-person shooter games by training an agent to predict the presence of enemies in the agent's field of view (FOV). They further found that auxiliary losses performed badly on feedforward models, where classification accuracy was limited, but that they were effective on a recurrent model. Mirowski et al. @mirowski2017learningnavigatecomplexenvironments found auxiliary tasks for depth prediction and loop closure detection improved navigation in 3D mazes, even compared to agents trained with depth information directly as input.

In the field of autonomous driving, Chitta et al. @chitta2022transfuserimitationtransformerbasedsensor applied auxiliary losses for depth prediction, semantic segmentation, and vehicle detection, achieving state-of-the-art performance on the CARLA benchmark, and decreasing the crash rate. Chen et al. @chen2020interpretableendtoendurbanautonomous use auxiliary losses for birds-eye-view prediction in urban environments, improving both interpretability, and performance.

== Evaluation of existing approaches

End-to-end RL agents on the RoboRacer platform generalise well to unseen tracks but have yet to match classical pipelines, and their opaque representations make failures hard to diagnose. For example, one may not understand whether an agent chose to accelerate into a wall because it misjudged its current velocity, or because it thought the track was straighter than it actually is. In simulation, privileged state such as velocity, tyre slip and upcoming track geometry is available but cannot be used at deployment, when these quantities are unavailable. Existing ways of exploiting privileged information during training each have a limitation: An asymmetric critic improves value estimation but doesn't directly shape the policy’s own representation; teacher-student distillation is complex since it requires a separate teacher and a two-stage pipeline, and auxiliary rewards alter the optimisation objective and must still pass through the high-variance policy gradient.

Auxiliary losses avoid all three: they leave the RL objective unchanged, supply a lower-variance supervised gradient directly to the shared representation, and are simple to implement. They have improved performance in first-person games, 3D navigation and urban driving. However, to our knowledge, they have not been studied for LiDAR-only racing, nor has it been examined which privileged targets help, or how they change what the policy’s representation encodes. This project addresses that gap.

= System overview <sec:system_overview>

To measure the effect of auxiliary losses on a LiDAR-only end-to-end racing agent, we built a custom simulator and training script. The system trains an end-to-end RL agent to drive a simulated RoboRacer from LiDAR alone. It has two subsystems (@system_diagram): a _simulator_, which models the vehicle, the track and their physical interaction; and a _trainer_, which turns the simulator's output into observations, rewards and auxiliary targets, and updates the policy with PPO. The two communicate over gRPC through the ML-Agents toolkit @ml-agents. ML-Agents includes its own simple PPO trainer, but we use only its communication layer, since TorchRL allows more flexibility in attaching auxiliary heads and losses to the network.

Because we will need to run multiple training runs, and have access to parallel hardware, we run multiple instances of the simulator in parallel, each with its own agent. Each agent is trained by a single Python script, which collects experience from all instances and updates the policy. The system is designed to be modular, so that the simulator can be replaced with another simulator, or the trainer can be replaced with another RL algorithm.

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
      edge(<env>, "->", <reward>),
      edge(<reward>, "->", <ppo>),

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
  caption: [System diagram. There are `num_concurrent_runs` concurrent training runs, each with `num_inst` parallel simulator instances, as indicated by the double lines. Each simulator instance simulates `num_areas` vehicles, each with its own track. The simulator communicates with the Python training script over gRPC, and the training script updates the policy using PPO.],
) <system_diagram>

== The control loop

The agent acts at 25 Hz, and the simulator advances its physics four times per action. At each control step $t$:

+ For every car, the simulator sends the 101-ray LiDAR scan together with privileged quantities: velocities, yaw rate, per-wheel slip, track curvature ahead, track progress and a collision flag.
+ The environment transforms split this message. The LiDAR history and the current steering and throttle form the observation $o_t$, which is the policy's only input. The privileged quantities never reach the policy; they are used only for the reward and the auxiliary losses.
+ The reward calculator computes $r_t$ from progress and collisions (@sec:reward_function), and the privileged quantities are normalised and stored as auxiliary targets.
+ The policy samples an action $a_t$, which is sent back to the simulator and held for the next 40 ms.

An episode ends on a collision or after 45 simulated seconds. On reset, a new track is generated and the car is placed at a random position along the centreline with a random heading $in (-10 degree, 10 degree)$ relative to the centreline.

== The training loop

Each PPO iteration collects 256 control steps from every training area in each parallel simulator, then updates the network for four epochs on this rollout. The training loop and simulator advance in lockstep, so the simulator pauses when the trainer is updating the network.

== Parallelism

Training is parallelised at three levels (@system_diagram). Each simulator _instance_ contains `num_areas` = 6 _training areas_: isolated copies of a track and car that do not interact. Each _run_ drives `num_inst` = 8 instances, giving 48 cars per run, and `num_concurrent_runs` = 8 runs share the machine. These values were chosen by the throughput study in @sec:trainer_performance_tuning.

The following chapters shall outline the design and implementation of the two subsystems: the simulator (@sec:simulator) and the training script & agent (@sec:training).

= Simulator <sec:simulator>

Previous work on end-to-end driving has largely made use of the F1Tenth gym, with the F1Tenth gym being the most common simulator among studies surveyed by Evans et al. @evans2024unifyingf1tenthautonomousracing. The F1Tenth gym is a Python-based 2D simulator for the F1Tenth (now RoboRacer) vehicle. This simulator is easy to use, and runs in Numba-compiled Python, but features a simplified bicycle model of the vehicle, which approximates slip dynamics using a linear function  @okelly2020f1tenthgym.

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

Despite its higher-accuracy physics, the AutoDrive simulator by default does not provide various features that are important for end-to-end training in our auxiliary learning setup. For example, it is missing track generation & privileged information reporting. Therefore, a custom simulator was implemented in Unity using components from the AutoDrive simulator. Specifically, the `VehicleController` and `IMU` components were not re-implemented, but instead used directly from the AutoDrive simulator. The rest of this chapter describes the custom simulator, including its performance, vehicle model, track generation, and privileged information reporting.

== Simulator performance comparison

In simulation-based training, throughput is critical because agents typically require a very large number of timesteps to learn. There are two kinds of timesteps: at each _control timestep_, the agent receives an observation and outputs an action, and at each _physics timestep_, the physics engine advances the numerical physics integration. The simulation timestep is usually shorter than the control timestep, since the dynamics must be integrated at a finer resolution to remain accurate. Following the settings used by Evans et al. @evans2024unifyingf1tenthautonomousracing, we use a control frequency of 25 Hz and a simulation frequency of 100 Hz.

In order to ensure the custom Unity simulator is suitable for training and not just evaluation, its performance was compared to the F1Tenth gym. A rollout of 10 000 control timesteps (6 minutes and 40 seconds in simulation time) was performed in each environment on an M4 MacBook Air, and the average time per control step was measured. Both environments were run in headless mode to remove any potential overhead from the graphical user interface.

Despite the Unity simulator being much more complex than the F1Tenth gym, it runs at a comparable speed, using a comparable amount of CPU resources in this environment, as shown in @sim_benchmarks, with the Unity simulator being only 19% slower compared to the F1Tenth Gym in terms of mean steps per second (sps).

Due to the relatively minor performance difference, and Unity's more realistic 3D physics, the Unity simulator was chosen for training the RL agent, despite the F1Tenth gym being more widely used in the literature.

#figure(
  image("../results/sim_benchmarks.pdf"),
  caption: "Benchmark of Unity simulator vs F1Tenth gym. In the CPU chart, a value greater than 100 indicates that the simulator used more than one CPU core. Includes child processes spawned by the simulator (e.g. in Unity's case)",
) <sim_benchmarks>

== Unity Vehicle Model
The vehicle is modelled as a `RigidBody` with four wheels, each simulated by a
`WheelCollider`. The two components divide the work: the `Rigidbody` represents the
car as a single moving mass, and the `WheelCollider`s generate the forces that move it. Near the front of the car, a `RayPerceptionSensor` from the ML-Agents toolkit simulates a 2D LiDAR sensor with 101 rays, which is used as the agent's observation.

=== The RigidBody
A `RigidBody` is the Unity component that gives an object rigid physical behaviour. It
stores the car's mass, centre of mass and moment of inertia. At each fixed timestep
the physics engine (PhysX) integrates the forces and torques acting on it to update
its linear and angular velocity and its pose. The car's body is covered by simple
box colliders (@unity_colliders), which handle collisions with walls and other
objects. They play no part in the tyre-road interaction, which is handled entirely
by the wheels. `BoxColliders` were used to model the car's body and collisions between the wheels and walls, since the `WheelCollider` component doesn't detect these kinds of collisions. The mass of the vehicle is set to 3.47 kg based on the values reported by Samak and Samak @samak2024autonomyorienteddigitaltwins.

#figure(
  image("figures/unity_isometric_colliders.png", width: 300pt),
  caption: [Custom Unity car's colliders: the body colliders handle collisions, and
    the four `WheelCollider`s handle suspension and tyre forces. The red lines show the raycasts by the `RayPerceptionSensor` that simulates the LiDAR. Despite the car looking simpler than the one in the AutoDrive simulator, it has similar physical properties, since we removed the visual meshes and textures.],
) <unity_colliders>

=== The WheelCollider <sec_wheelcollider>
In our custom simulator, each wheel of the RoboRacer is
modelled as a `WheelCollider`, which simulates the wheel's suspension,
rotation and tyre friction @unitydocsWheelFrictionCurve. This kind of collider uses physics similar to that modelled by the semi-empirical "magic formula" wheel dynamics proposed by Pacejka et al. @pacejka1992magicformula @pacejka2002tyre.

The tyre model is built on the idea of _slip_. _Longitudinal slip_, $kappa$, is the ratio between the longitudinal slip velocity and the wheel centre velocity. _Lateral slip_, $tan(alpha)$, is the ratio between the lateral slip velocity and the wheel centre velocity. A wheel slips when it spins faster than
the wheel centre moves (wheelspin), turns slower than the wheel centre moves (braking), or is dragged sideways (cornering or drifting). A slip value of $0$ therefore indicates a freely rolling wheel, while a slip value of $> 1$ indicates that the point of contact has a higher velocity than the wheel centre.

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

 shows the difference between a Unity-style piecewise friction curve and a Pacejka "magic formula" curve that was fit using least-squares to approximate Unity's friction curve. The values used for our simulations are detailed in @wheel_collider_properties and are the values calibrated by Samak and Samak @samak2024autonomyorienteddigitaltwins for the RoboRacer platform, ported to our custom Unity simulator.

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
On the real-life RoboRacer, steering actuation cannot occur instantaneously, but is limited by the steering servo's maximum angular velocity. The `WheelCollider` component does not model this limitation, so we use the `VehicleController` from AutoDrive to implement a cap on steering speed of $omega_max = 315 degree \/ sec$. This value was also chosen based on the calibration of the RoboRacer platform by Samak and Samak @samak2024autonomyorienteddigitaltwins.

=== LiDAR

The vehicle is equipped with a simulated 2D LiDAR sensor, which is implemented using a `RayPerceptionSensor` from the ML-Agents toolkit. The sensor emits 101 rays in a fan pattern, covering a field of view of $270 degree$. Each ray measures the distance to the nearest obstacle in its cast direction, and returns a normalized value between 0 and 1, where 1 indicates no obstacle within the maximum range of the sensor (20m).

== The track <sec:track>

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
+ We take a random turn (@fig:walk-step (a)), drawing $epsilon_i ~ cal(U)(-Delta_max, Delta_max)$
  and adding it to the offset.
+ As depicted in @fig:walk-step (b), we shrink the offset towards zero by a factor
  $1 - kappa_i$, where
  $ kappa_i = kappa_0 + (1 - kappa_0) t_i^s. $
  The restoring strength $kappa_i$ starts at $kappa_0$ and ramps up to exactly 1 on
  the final step. The exponent $s$ controls how late the ramp kicks in.
+ In @fig:walk-step (c), we limit the offset from the reference heading to prevent accumulation of large offsets, and advance by length $l$:
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
slightly from the circle, $p_N$ generally misses $p_0$ as visualised in @fig:trackgen_walk (a). We close it by
distributing the gap linearly along the track:
$ p_i <- p_i + i / N (p_0 - p_N), quad i = 0, ..., N. $
The gap is (usually) small, so this correction barely distorts the track.
Finally, we fit a Catmull-Rom spline to the polyline to smooth out the corners, as visualised in @fig:trackgen_walk (c).

#figure(
  image("../results/figures/trackgen_walk.pdf", width: 120%),
  caption: [*(a)* Open end of the track before distributing the gap between $p_0$ (green) and $p_N$ (red) *(b)* Closed track after distributing the gap *(c)* Catmull-Rom spline interpolation of the polyline *(d)* A degenerate track],
) <fig:trackgen_walk>


This method is not immune to generating self-intersecting (degenerate) tracks, as shown in @fig:trackgen_walk (d), but the probability is low enough that we simply discard any degenerate tracks and generate a new one. Empirically we find 50 tracks of 100 000 to be degenerate with our chosen parameters, so a 95%-confidence interval (C.I.) for  $P("degenerate track" | N = 30, Delta_max = 80 degree, kappa_0 = 0.1, s = 3, delta_max = 90 degree)$ is $(0.037%, 0.065%)$ assuming a binomial distribution.

=== Track walls

Adding track walls to the generated centerline spline is a non-trivial problem. A naive approach is to scale the centerline's vertices outwards by a fixed multiple, or provide a fixed offset from the centre, but this can create undrivably narrow sections, as visualised in @trackgen_inset_outset (a) and (b) respectively. We therefore generate the walls using the Clipper2 library @clipper2, which implements a polygon offsetting algorithm inspired by Vatti @vatti1992. The Clipper2 algorithm is robust to self-intersections, but may produce inset "islands" for large inset distances, or for tracks which are close to self-intersecting, as visualised in @trackgen_inset_outset (c).

Empirically, we find that 1350 of the 100 000 tracks produce these islands (C.I. $(1.28%, 1.42%)$), so we simply discard any tracks with islands and re-generate them.



#figure(
  image("../results/figures/trackgen_inset_outset.pdf", width: 120%),
  caption: [Track insets and outsets using (a) multiplicative scaling from the centre, (b) fixed offsets from the centre, and (c) Clipper2's polygon offsetting algorithm. (d) A degenerate track with two inset islands, generated by Clipper2's polygon offsetting algorithm with a large inset distance.],
) <trackgen_inset_outset>

=== Track Curvature <sec:track_curvature>
During training, we wish to observe the effect of using track curvature as an auxiliary loss. To this end, we compute the curvature of the track at 16 equally-spaced points along the track ($d in {0.5, ..., 8} "m"$) ahead of the car's current position. The curvature is computed using the formula $c_d = 1 / r_d$, where $r_d$ is the radius of the osculating circle at that point on the track. The osculating circle was introduced by Leibniz @leibniz1686 as cited by @struik1969[p. 419, n. 6]; it is the circle that best approximates a curve at a given point, and its radius is computed from the first and second derivatives of the track’s parametric equations @stewart2020calculus[p. 910-911]:

$
  r = (x'(t)^2 + y'(t)^2)^(3/2) / (x'(t) y''(t) - y'(t) x''(t)) = abs(bold(r)'(t))^3 / abs(bold(r)'(t) times bold(r)''(t))
$

The signed curvature about the up-axis is then

$
  c = -((bold(r)'(t) times bold(r)''(t)) dot bold("up")) / abs(bold(r)'(t))^3
$

where $bold("up")$ is the unit vector pointing along the world's $z$-axis.


= The Agent <sec:training>

In this chapter, we describe the agent architecture and the auxiliary losses used to improve its performance. To compare the effect of each auxiliary loss, we train two agent architectures and run a leave-one-in experiment on each. For each architecture, we train a baseline with no auxiliary losses, plus one run per group of auxiliary losses in which only that group is enabled, so each group’s contribution can be measured against the baseline.

We shall first formalise the problem of autonomous racing as a partially observable Markov decision process (POMDP) in @sec:pomdp, then describe the process of reinforcement learning in @sec:rl, describe the architectures of the agent in @sec:agent, and discuss how the weights of the auxiliary losses are chosen in @sec:finding_optimal_weights. Finally, @sec:metrics describes the metrics used to evaluate the performance of the agent.


== Partially Observable Markov Decision Processes (POMDPs) <sec:pomdp>

In order to formally describe the problem of autonomous racing, we first introduce the framework of partially observable Markov decision processes (POMDPs). POMDPs are a generalisation of Markov decision processes (MDPs) that account for the fact that an agent may not have access to the full state of the environment. In a POMDP, the agent receives observations that provide partial information about the underlying environment state, and must make decisions based on this incomplete information.

A POMDP is defined by the tuple $(cal(S), cal(O), cal(A), cal(P), rho_0, cal(R), gamma, cal(Z))$, based on the work by Kaelbling et al.
@kaelbling1998:

At each time step $t$, the environment is in state $s_t in cal(S)$, where
$cal(S)$ is the state space. This state is a _complete_ description of the
environment at that time. The first state $s_0$ is sampled from an initial state distribution $rho_0$. The agent does not see $s_t$ directly. Instead, it receives an observation $o_t in cal(O)$, typically its sensor inputs (e.g. LiDAR, camera frames), drawn from the observation function,
$o_t ~ cal(Z)(dot | s_t)$: the observation function is a stochastic mapping from the true state to the observation, deciding what the agent observes given the true state. The information in $s_t$ that is missing from
$o_t$ is called _privileged information_. For example, the car may observe its lidar measurements, but not the road curvature ahead directly, which is privileged information.

Based on its observations, the agent uses its policy $pi$ to choose an action $a_t in cal(A)$, where
$cal(A)$ is the action space. The policy therefore maps the history of observations#footnote([Should the policy be defined using a single observation as input, it may perform arbitrarily worse than when using a full history of observations @kaelbling1998. The observations are not markov, only the states are.]) to a probability distribution over actions; we write#footnote([Some formulations may define the policy as a mapping from the true state estimate to actions instead, but this is not an end-to-end approach, since there must then exist a state estimator, $e: cal(O)^m -> cal(S)$. In that case: $hat(s)_t = e(o_0, ..., o_t), a_t ~ pi(dot | hat(s)_t)$])
$a_t ~ pi(dot | o_0, ..., o_t)$. The policy is what we want to find: it describes the
agent's behaviour. After the agent has taken action $a_t$, the environment moves
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
    step((1, 3), $s_1 ~ cal(P)(dot | s_0, a_0)$),
    step((0, 4), $a_1 ~ pi(dot | o_0, o_1)$),
    step((1, 5), $s_2 ~ cal(P)(dot | s_1, a_1)$),
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
    Interaction between the agent and the environment over time ($t$), which flows downwards.
  ],
) <mdp_iteration_diagram>

The agent's goal is to maximise the _expected discounted return_. The
_discounted return_ (or simply _return_) from time step $t$ is the discounted sum of all rewards the agent
receives from time $t$ onward,
$ G_t = sum_(k=0)^(T-t) gamma^k r_(t+k), $
where $T$ is the final time step and $gamma in [0, 1]$ is the discount
factor. A reward received $k$ steps ahead is scaled by $gamma^k$, so later
rewards are worth less than immediate ones: when $gamma$ is close to 1 the
agent is far-sighted, and when $gamma$ is close to 0 it is short-sighted.
Since $G_t$ depends on random states, observations and actions, it is a
random variable, and the agent maximises its expectation, $EE[G_0]$, from the
start of the episode. The policy that achieves this maximum is the _optimal policy_ $pi^*$.

In our application, we use $gamma = 0.995$ so that the agent is reasonably far-sighted and values reward received 138 steps into the future at half of those received immediately. At a control frequency of 25Hz, this reflects a horizon of \~5.5 seconds.


=== Value functions
Value functions measure how good it is for the agent to be in a state, or to take an action in that state.
The state-value function,
$
  V^pi (s) = EE_pi [G_t | S_t = s]
$ <state_value_function>
is the expected discounted return starting in state $s$ and then following policy $pi$ thereafter, and is what the critic estimates in the PPO training algorithm (@sec:ppo). The action-value function,
$
  Q^pi (s, a) = EE_pi [G_t | S_t = s, A_t = a]
$ <action_value_function>
measures the expected discounted return starting in state $s$, taking action $a$, and then following policy $pi$ thereafter. Their difference is the advantage function,
$
  A^pi (s, a) = Q^pi (s, a) - V^pi (s),
$ <advantage_function>
which measures how much better action $a$ is than the policy's average action in state $s$, following policy $pi$.

== Reinforcement Learning (RL) <sec:rl>

In order to find the optimal policy, $pi^*$ that maximises the expected discounted return, $J(theta) = EE_pi_theta [G_0]$, we use reinforcement learning (RL) as introduced by Sutton and Barto @sutton2018. In RL, the agent learns to maximise its expected discounted return by interacting with the environment and receiving feedback in the form of rewards. The agent updates its policy based on the observed rewards and transitions, gradually improving its performance over time. We use RL instead of supervised learning due to lack of labelled data from expert demonstrations.

So-called model-free RL algorithms fall into three broad classes: _Value-based_ methods learn the
optimal action-value function
$Q^*(s, a) = max_pi Q^pi (s, a)$
and act greedily with respect to it, choosing the action with the highest value in the current state at each timestep: $pi(s) = argmax_(a in cal(A)) Q^pi (s, a)$.
_Policy-based_ methods, on the other hand,
learn a parameterised policy $pi_theta$ directly by ascending the estimated gradient of
$J(theta)$ with respect to $theta$, and do not need the Markov property of the observations or an
$arg max$ over actions. They can also represent stochastic policies, which may be
necessary for optimal behaviour in some POMDPs @singh1994learningwithoutstateestimation (although there always exists a deterministic optimal policy in fully-observed MDPs). _Actor-critic_ @sutton2018 methods
combine both: a learned value function (the critic) is used to reduce the variance
of the policy gradient, and since the critic is only used in training, it may take privileged information as input. We focus on policy-based and actor-critic
methods in this report.

=== Policy gradient theorem <sec:policy_gradient>

Policy gradient methods are a class of RL training algorithms that learn a policy $pi_theta$ with parameters $theta$ directly by maximising the expected return $EE[G_0]$ with respect to the policy parameters $theta$. Given a trajectory $tau = (s_0, o_0, a_0, r_0, s_1, o_1, a_1, r_1, dots, s_(T-1), o_(T-1), a_(T-1), r_(T-1)) ~ p_theta$, where $p_theta$ is the probability of the trajectory when following the policy $pi_theta$, we intend to maximise the expected return with respect to the policy parameters $theta$, so the objective function is
$
  J(theta) = EE_(tau tilde p_theta) [G_0]
  = EE_(tau tilde p_theta) [sum_(t=0)^T gamma^t r_t]
  = integral p_theta (tau) G(tau) dif tau
$

Taking the gradient of $J(theta)$ with respect to $theta$ and applying the log-derivative trick @williams1992, we obtain the policy gradient theorem#footnote([The derivation of the policy gradient theorem is stated in @sec:policy_gradient_theorem_proof.]) @sutton1999policygradient:
$
  nabla_theta J(theta) = EE_(tau tilde p_theta) [sum_(t=0)^(T-1) gamma^t nabla_theta log pi_theta (a_t | o_t) G_t].
$ <eq:policy_gradient_theorem>

@eq:policy_gradient_theorem shows in what direction to update the policy parameters in order to increase the expected return. Of course, the expectation cannot be computed exactly without formulating the probability distribution over all possible trajectories, which is intractable, so we instead rely on estimates such as those detailed in @sec:reinforce and @sec:ppo.


=== REINFORCE <sec:reinforce>

The REINFORCE algorithm for policy learning was introduced by Williams~@williams1992. It is one of the simplest policy gradient methods: by sampling $N$ trajectories, ${tau^((1)), ..., tau^((N))} ~ p_theta$, of length $T_i$ timesteps each, the policy gradient can be estimated in a Monte-Carlo fashion:

$
  hat(nabla_theta J)(theta) = 1/(sum_(i=1)^N T_i) sum_(i=1)^N sum_(t=0)^(T_i-1) nabla_theta log pi_theta (a^((i))_t | o^((i))_t) dot G^((i))_t
$
Although REINFORCE is simple to implement, it has several drawbacks, including having high variance in its gradient estimates, which can lead to slow convergence and instability during training @santana2026introductiondeepreinforcementimitation.

=== Proximal Policy Optimisation (PPO) <sec:ppo>
PPO is a modern actor-critic algorithm for policy learning introduced in 2017 by researchers at OpenAI @schulman2017ppo. It improves on REINFORCE in two ways. First, being an actor-critic method, it learns a value function $V^pi (s)$, which is used to compute an advantage estimate $hat(A)_t$ and so reduces the variance of the policy gradient estimate, $hat(nabla_theta J)(theta)$. Second, it optimises a _clipped surrogate objective_, $cal(L)_"PPO"$, that limits how far each update can move the policy. This prevents large, destructive steps and makes several epochs of updates on the same rollout possible.

Recall that the advantage function in @advantage_function is the difference between the action-value and state-value functions. It therefore measures how much better (positive) or worse (negative) an action is than the policy's average action in that state. In training, $hat(A)_t = hat(A)^pi (s_t, a_t)$ is estimated from observed rewards and the learned value function, $hat(V)^pi (s)$, for example with Generalised Advantage Estimation @schulman2018highdimensionalcontinuouscontrolusing.
In PPO, the clipped surrogate objective is given by
$
  cal(L)_"actor" = -1/(sum_(i=1)^N T_i) sum_(i=1)^N sum_(t=0)^(T_i-1) min(rho_t (theta) dot hat(A)_t, "clip"(rho_t (theta), 1 - epsilon, 1 + epsilon) dot hat(A)_t)
$

where $rho_t (theta) = (pi_theta (a_t | o_t)) / (pi_theta_"old" (a_t | o_t))$ is the ratio of the new policy's probability of taking action $a_t$ given observation $o_t$ to the old policy's, and $epsilon$ is a hyperparameter that controls how much the policy is allowed to change in a single update. The $"clip"$ function ensures that a policy update that would make $rho_t (theta)$ fall outside of the interval $[1 - epsilon, 1 + epsilon]$ is clipped to the nearest endpoint of that interval. This prevents large policy updates that could destabilise training. The $min$ function, on the other hand, ensures that, while the policy's update is capped when an update makes a good action ($A_t > 0$) more likely, it is not protected from large updates if an update makes a bad action ($A_t < 0$) more likely. These two mechanisms together ensure that the policy is updated in a way that improves performance while avoiding large, destabilising changes that are common in other policy gradient methods @schulman2017ppo.

Since PPO is an actor-critic method, it also learns a value function estimate, $hat(V)^pi (s)$, which is used to compute an advantage estimate $hat(A)_t$ and so reduces the variance of the policy gradient estimate, $hat(nabla_theta J)(theta)$. The value function is learned by minimising the mean squared error between the predicted value and the observed return. The full PPO loss function is therefore a combination of the clipped surrogate objective and the value function loss, along with an entropy bonus to encourage exploration. The final loss function is given by

$
  cal(L)_"PPO" = cal(L)_"actor" + w_"value" dot cal(L)_"value" - w_"entropy" dot cal(H)[pi_theta]
$

where $cal(L)_"value" = (1/2) (hat(V)^pi (s_t) - G_t)^2$ is the value-head loss function. This loss is minimised using the Adam optimiser @kingma2017adammethodstochasticoptimization, with a learning rate of $3 times 10^(-4)$ and a batch size of 64.

== Neural Network Architecture <sec:agent>

As discussed in @sec:related_literature, Lample et al. @lample2017fps found that a RNN performed better in a partially observed environment, compared to a feedforward (FF) network in a first-person shooter game. Since it is not clear that this finding carries over to autonomous racing, we implement both a feedforward and a recurrent agent. Both model architectures are PPO actor-critic networks implemented in PyTorch @paszke2019pytorch, with the TorchRL library @bou2023torchrldatadrivendecisionmakinglibrary.

Each network consists of a shared _trunk_ that produces a 64-dimensional feature vector, followed by three independent heads that all take this vector as input (@network_architecture):

- the _policy head_ outputs the parameters of the action distribution,
- the _value head_ outputs the state-value estimate $hat(V)^pi (s)$, and
- the _auxiliary head_ outputs predictions of the privileged targets

The trunk's input is a $50 times 101$ tensor (or $4 times 101$ in the RNN) containing the 50 (or 2 in the RNN) most recent LiDAR scans of 101 rays each. We use two in the RNN so that temporal information must be primarily captured through the recurrent connections. Four 1D convolutions slide along the ray axis and treat the time steps as input channels, so the first layer combines the full history at every angular position. The convolutions have 16, 32, 32 and 16 output channels, a kernel size of 8 rays (about $21 degree$ of the field of view) and ReLU activations. Their output is flattened, concatenated with the current steering angle and throttle, and passed through dense layers of 128, 72 and 64 units with ReLU activations.

The 64-dimensional output is then layer-normalised. Under heavy acceleration the car's body tilts, pointing the LiDAR above the track walls so that many rays return close to the maximum normalised length of 1. Without normalisation, these inputs can cause gradients to explode, which was observed in early tests.
In the recurrent variant, a gated recurrent unit (GRU) @cho2014learningphraserepresentationsusing with a hidden size of 64 follows the layer norm, and its output is passed to the heads instead. The GRU was used instead of a long short-term memory (LSTM) @hochreiter1997longshorttermmemory because it is simpler, and because previous work @węgrzynowski2024learningdynamicsmodelsvelocity has shown it to be more effective in predicting velocity state in autonomous racing, which is closely related to our task.

#{
  // Box heights grow with layer size, with a minimum so the rotated labels fit.
  let conv-height = ch => 1.2cm + ch * 0.05cm
  let fc-height = size => 1.2cm + size * 0.02cm

  // Generic layer box: tall, narrow, tinted fill, rotated label.
  // The label is laid out in a block as wide as the box is tall *before*
  // rotating, so it doesn't wrap to the box's narrow width.
  let layer = (pos, name, label, color, height, width: 0.9cm, stroke: none) => node(
    pos,
    rotate(
      -90deg,
      reflow: true,
      block(width: height, align(center, text(size: 0.7em, weight: "bold", fill: color.darken(30%), label))),
    ),
    name: name,
    fill: color.transparentize(80%),
    stroke: if stroke == none { (paint: color, thickness: 1.5pt) } else { stroke },
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
    <rnn>,
    <out>,
  )

  let other_networks = (
    (name: "Policy head", size: 4, output: "Action distribution parameters"),
    (name: "Value head", size: 1, output: "State-value estimate"),
    (name: "Auxiliary head", size: none, output: "Estimates of privileged targets"),
  )

  figure(
    // Draw at full size with comfortable gaps, then shrink to fit the page.
    scale(60%, reflow: true, diagram(
      spacing: (0.8cm, 0.6cm),
      edge-stroke: 1pt,

      // Input: 50-frame LiDAR stack
      node(
        (0, 0),
        [
          #place(bottom + center, dy: 10pt)[#text(size: 0.6em, "101 rays")]
          #place(horizon + left, dx: -10pt)[#rotate(
            -90deg,
            text(size: 0.6em, "2 (RNN) or 50 (FF) frames"),
            reflow: true,
          )]
          #image("figures/lidar_input.png", width: 2cm, height: 2cm)
        ],
        name: <lidar>,
      ),

      // Four 1D convolutions
      conv((1, 0), <c1>, 16),
      conv((2, 0), <c2>, 32),
      conv((3, 0), <c3>, 32),
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
      layer((11, 0), <rnn>, [GRU\ (only RNN)], gray, 3cm, stroke: (paint: gray, dash: "dashed", thickness: 1.5pt)),

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
      node((12, 0), align(center, text(size: 0.7em)[64-d \ feature]), name: <out>, stroke: none),

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
            edge(..(<out>, (12, 1), (x, 1), n).dedup(), "-|>"),

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
      The agent's neural network. A LiDAR stack passes through four 1D convolutions, the flattened output is concatenated with the current steering and throttle and passed through three dense layers and a layer norm. After the GRU layer in the RNN, a 64-dimensional feature vector is generated. This feature vector is passed to three independent heads: the policy head outputs the parameters of the action distribution, the value head outputs the state-value estimate, and the auxiliary head outputs predictions of privileged targets.
    ],
  )
} <network_architecture>


=== Policy Head
The policy head outputs a location $mu$ and a raw scale value $x$ for each of
throttle and steering. Each action is sampled independently from a
tanh-squashed Gaussian,
$ a = tanh(u), quad u tilde cal(N)(5 * tanh(mu / 5), sigma^2), $
so that $a in (-1, 1)$, where 1 corresponds to full throttle or full right steering, and -1 corresponds to full reverse or full left steering.

The mean is transformed with a tanh to soft-clamp it to the range $(-5, 5)$. This prevents the mean from growing too large, which would push samples into the saturated region of the squashing function and make it difficult for the policy to recover since gradients vanish there. The constant factor of 5 is chosen heuristically since it allows the model to use most of the action range ($tanh(5) = 0.9999$), while being at the limit of a useful gradient ($tanh'(5) = 1 - tanh^2(5) approx 1.8 times 10^(-4)$).

The standard deviation is made positive with a softplus, with a small floor to ensure that the distribution is never degenerate:
$sigma = op("softplus")(x) + 10^(-3).$ Further, policy head's linear layer uses a weight initialisation with
gain $0.01$ and zero bias, so every output is close to $0$ at the start. Hence
$mu approx 0$, and both actions are centred near the middle of their range.

This is important because the derivative of the squashing $tanh(u)$ function goes to $0$ as $|u|$ grows. If the head's outputs start large, samples
land in the saturated region, the gradient of the policy loss with respect to
$mu$ is almost zero, and the policy cannot recover. In early tests this
is exactly what happened: the car locked at full throttle and full steering in either the positive or negative direction.

=== Auxiliary heads

Using privileged information during training can improve the agent’s performance, as discussed in @sec:learning_methods_privileged_information. We incorporate it through _auxiliary losses_: additional loss terms that encourage the network to learn useful representations of the environment. These losses are computed from quantities that are available during training but withheld from the agent at test time. They therefore shape what the network learns without the agent relying on them at deployment.
At every frame, the environment passes a set of privileged quantities to the trainer, which serve as auxiliary targets. After normalisation#footnote([In order to ensure the targets are on a similar scale, the targets are normalised to $sigma = 1, mu = 0$ using a rollout generated from a pure PPO policy (i.e. without auxiliary losses/heads) as data to estimate $sigma$ and $mu$.]), one or more _auxiliary heads_ learn to predict these targets, supervised by corresponding auxiliary losses. The auxiliary targets we consider are listed in @auxiliary_targets. During training, the auxiliary losses are added to the PPO loss, and the gradients of the combined objective are backpropagated through the shared network:


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
    [The curvature of the track centerline at $d$ metres ahead of the agent, measured as the reciprocal of the radius of curvature],
    [Per-wheel longitudinal slip $kappa_x$],
    [unitless],
    [The longitudinal slip of wheel $x in {"FR", "FL", "BR", "BL"}$],
    [Per-wheel lateral slip $tan(alpha_x)$],
    [unitless],
    [The lateral slip of wheel $x in {"FR", "FL", "BR", "BL"}$],
  ),
  caption: [The auxiliary targets to be predicted by the agent],
) <auxiliary_targets>
=== Choice of Auxiliary Loss Function <sec:loss_function>

The choice of auxiliary loss functions, $cal(L)_"aux"^((k))$, has the potential to impact the agent's performance. Since we are predicting continuous quantities, it is natural to use a regression loss function such as Squared Error (SE), Absolute Error (AE), or Huber loss @huber1964robust, defined respectively as

$
  cal(L)_"SE" = (hat(y) - y)^2, quad
  cal(L)_"AE" = |hat(y) - y|, quad
  cal(L)_"Huber"^beta (y, hat(y)) = cases(
    1/2 (y - hat(y))^2 "if" |y - hat(y)| <= beta,
    beta |y - hat(y)| - 1/2 beta^2 "otherwise".
  )
$

Throughout, we use PyTorch's rescaled implementation of the Huber loss (`smooth_l1_loss`), $(cal(L)^beta_"Huber" (y, hat(y))) / beta$. Dividing by $beta$ decouples the threshold from the gradient: the rescaled loss is quadratic with gradient for small errors, but linear with a constant gradient of magnitude 1 for large errors.

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
    caption: [Rescaled Huber loss (blue) vs squared error loss (orange) vs absolute error loss (red) for prediction errors $delta$. Between the green lines, the Huber loss acts like the squared error loss, and outside, its gradient is equal to the gradient of the absolute error loss, so it is less sensitive to outliers than the squared error loss. The Huber loss is smooth at zero, unlike the absolute error loss, so its gradient shrinks gradually as the error approaches zero.],
  )
} <huber_vs_mse_diagram>

The Huber loss's bounded gradient is particularly useful when the target values have a heavy-tailed, non-normal distribution, since the loss is then far less sensitive to extreme values than the SE loss @terven2025lossfunctionsmetricsdeep. The majority of the auxiliary targets are heavy-tailed, with some having more than 27x the number of extreme values ($|X| > 3 sigma$) compared to a normal distribution. A table with the statistics for each individual target is available in @sec:prop_data_within_sd.

For this reason, we use the Huber loss for all auxiliary targets. With $beta = 1$, since the targets are normalised to zero mean and unit variance, this makes the loss quadratic for errors within one standard deviation of the mean - where most#footnote([Proportions of the data within 1 standard deviation of the mean are listed in @sec:prop_data_within_sd]) of the fitting takes place - and linear, with a gradient of magnitude $1$, beyond it, so that the extreme target values cannot dominate the gradient.

== Finding the Optimal Weights <sec:finding_optimal_weights>

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
    xlabel: [$w_"aux"^((1))$],
    ylabel: [$w_"aux"^((2))$],
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
    scale(80%, reflow: true, grid(
      columns: 3,
      column-gutter: 12pt,
      search-plot(grid-pts, [(a) Grid search]),
      search-plot(random-near, [(b) Random search (hit)]),
      search-plot(random-far, [(c) Random search (miss)]),
    )),
    caption: [Grid and random search over two auxiliary loss weights. The red star indicates the optimal weight configuration. (a) shows that a grid search may miss the optimum, but is guaranteed to find a point within $"grid resolution"/2$ of the optimum. (b) shows that random search can find a point very close to the optimum, but (c) shows that it can also miss it entirely.],
  )
}

So-called "smart" hyperparameter tuning methods, such as Bayesian optimisation @snoek2012practical and the tree-structured Parzen estimator (TPE) @bergstra2011algorithms, build a model of the relationship between the weights and the agent's performance. This model is then used to guide the search for optimal weights, allowing for more efficient exploration of the search space. These methods can be more effective than grid or random search, but they can also be more complex to implement and still require multiple training runs. Methods such as Hyperband @li2018hyperband and its asynchronous variant ASHA @li2020asha mitigate this cost by giving each trial a small budget and only continuing the best-performing ones. However, such early-stopping methods may prematurely terminate RL trials that perform more exploration early on, despite performing better in the long run @hertel2020quantityvsqualityhyperparameter, so they are not ideal for our scenario.

=== Adaptive Weighting
Adaptive weighting is an alternative approach that dynamically adjusts the weights of the auxiliary losses during training based on factors like the magnitude of the gradients or the error of the auxiliary predictions. Various methods have been introduced in the literature, such as GradNorm @chen2017gradnorm, which weights tasks that are learning slower more heavily, and Uncertainty Weighting @kendall2018multitask-cvpr, which uses the model's uncertainty in each task to determine the weights. These methods are useful in multi-task learning scenarios, where the performance of all tasks is important, but they are not ideal for our scenario, where the main task (driving) is the only one that matters. In this case, we want to combine auxiliary losses in such a way that improves the main task's performance, not to balance the performance of all tasks.

=== Weighting Scheme Used in This Project <sec:weighting_scheme>

Our aim is to understand the effect of each kind of privileged information on the agent, not to find the best possible weights. Searching over a separate weight for each of the 16 curvature, 3 velocity and 8 slip targets would be intractable (@sec:finding_optimal_weights), and adaptive methods are designed to balance tasks rather than to help a single primary task. We therefore use fixed weights and a _leave-one-in_ design.

The targets are partitioned into $C = 10$ categories (@aux_categories), each with one scalar weight $w_c$. The auxiliary loss of a category is the sum of the Huber losses of its targets,
$
  cal(L)_c = sum_(k in c) cal(L)_"Huber"^((k)),
  quad
  cal(L)_"total" = cal(L)_"PPO" + sum_(c=1)^C w_c cal(L)_c .
$


#figure(
  stb-table(
    columns: 2,
    align: (left, left),
    header: ([*Category*], [*Auxiliary targets*]),
    [None],
    [No targets (i.e. baseline PPO)],
    [Forward velocity $v_f$],
    [Forward velocity $v_f$],
    [Lateral velocity $v_l$],
    [Lateral velocity $v_l$],
    [Yaw rate $omega_y$],
    [Yaw rate $omega_y$],
    [Close-ahead track curvature],
    [${c_x| x in {0.5, 1.0, 1.5, 2.0, 2.5, 3.0} "m"}$],
    [Medium-ahead track curvature],
    [${c_x| x in {3.5, 4.0, 4.5, 5.0, 5.5, 6.0} "m"}$],
    [Far-ahead track curvature],
    [${c_x| x in {6.5, 7.0, 7.5, 8.0} "m"}$],
    [Front wheel forward slip],
    [${kappa_x| x in {"FR", "FL"}}$],
    [Rear wheel forward slip],
    [${kappa_x| x in {"BR", "BL"}}$],
    [Front wheel lateral slip],
    [${tan(alpha_x)| x in {"FR", "FL"}}$],
    [Rear wheel lateral slip],
    [${tan(alpha_x)| x in {"BR", "BL"}}$],
    [All],
    [All auxiliary targets],
  ),

  caption: [The auxiliary targets are grouped into categories, each of which is weighted by a single hyperparameter.
  ],
) <aux_categories>


In a leave-one-in experiment, a single category $c^*$ is enabled with $w_(c^*) in {0.1, 0.3, 1.0}$ and every other weight is zero, giving 30 configurations, each compared against the baseline ($w_c = 0$ for all $c$). The "All" configuration enables every category at the same $w$. All weights are constant throughout training, and since the targets are normalised to zero mean and unit variance, the per-target losses are of comparable magnitude. The limitation is that this approach does not explore interactions _between_ categories.



== Metrics <sec:metrics>
In order to evaluate the agent's performance, we define a set of metrics that capture different aspects of its driving behaviour. These metrics are designed to provide insight into the agent's ability to navigate the track both (a) quickly and (b) safely.
=== Progress <sec:progress>
Let $L$ be the total length of the track centreline. At any time $t$, let $d_t in [0, L)$ be the agent's current arc length from the start of the centerline to the point closest to the agent, and let $N_t$ be the total number of completed laps. We define the agent's _absolute progress_ along the track as the total continuous distance travelled from the start:

$ xi_t = d_t + N_t L $

The _progress per timestep_ (PPT) is then simply the change in this absolute progress between consecutive timesteps, defined as $xi_t - xi_(t-1)$. Because $xi_t$ tracks the cumulative distance across multiple laps, this raw difference naturally handles crossing the finish line without requiring any wrapping operations or modulo arithmetic.

We also define the _progress per second_ (PPS) as the progress per step divided by the control timestep duration (40 ms), which is a more intuitive measure of speed.

=== Collision Rates
The _collision rate per episode_ is the fraction of total episodes that terminate in a collision rather than reaching the maximum length (45 simulated seconds).

The _collision rate per timestep_ is the total number of collisions divided by the total number of timesteps executed across all episodes. This can be interpreted as an estimate of the  probability of a collision occurring at any given timestep, and is useful for evaluating the agent's safety in a time-normalised manner.

The _collisions per metre of progress_ (CPMP) is the total number of collisions divided by the total distance the agent successfully advances along the track centerline. This metric normalizes failures against progress rather than time, providing a balanced measure of the agent's driving competence.

=== Reward function <sec:reward_function>
The agent receives a dense reward at each timestep that encourages fast, collision-free progress along the centerline:

$ r_t = w_p dot (xi_t - xi_(t-1)) - w_c dot c_t $

The first term encourages forward motion, using the per-step progress measure defined in @sec:progress. The second term discourages collisions through the indicator $c_t$, which is 1 if the agent collides with an obstacle at time $t$ and 0 otherwise. The weights $w_p$ (reward per metre of progress) and $w_c$ (penalty per collision) set the trade-off between speed and safety, and can be tuned to suit the application's risk tolerance. We use $w_p = 1.0$ and $w_c = 1.0$. A relatively small collision penalty is sufficient here because episodes end immediately on collision: the agent loses all future reward, which already acts as a strong implicit penalty for crashing.

=== Area Under the Curve (AUC)
The _area under the curve_ (AUC) evaluates sample efficiency and learning stability by calculating the definite integral of a performance metric $y(t)$ (e.g., return or progress per step) over the total training time or timesteps $T$:

$ "AUC" = integral_0^T y(t) dif t $

In practice, evaluation metrics are recorded at discrete time intervals $t_0, t_1, ..., t_N$, so the AUC is computed using the trapezoidal rule:

$ "AUC" approx sum_(i=1)^N frac(y(t_(i-1)) + y(t_i), 2) (t_i - t_(i-1)) $

A higher AUC for a measure like reward or progress indicates faster learning and superior performance throughout the entire training process rather than merely achieving high final performance.

=== $R^2$ score <sec:r2_score>

The _coefficient of determination_, $R^2$, measures how much of the variation in a quantity a model can explain, compared to simply guessing the average value every time. It is used in @sec:baseline_model_features to judge how well privileged quantities such as velocity or curvature can be predicted from the network's internal representations.

A score of 1 means the predictions are perfect, a score of 0 means the model does no better than predicting the average, and a negative score means it does worse. We report the _out-of-sample_ $R^2$, computed on data the model was not fitted to, so it reflects how well the model generalises rather than how well it memorised its training data.

$R^2$ is used instead of error measures such as RMSE because it is unit-free. The quantities we predict have different units and scales (m/s, rad/s, 1/m and unitless slip), so their raw errors cannot be compared, whereas $R^2$ puts all of them on one scale.

== Trainer Performance Tuning <sec:trainer_performance_tuning>
Training was performed on a single machine with 64 cores (128 threads) and 128 GB of RAM. To ensure experiments finish in a practical time, we first measured how best to use this hardware, aiming to maximise _aggregate_ throughput: environment timesteps collected and learned from per second, summed across all models training simultaneously.

We ran a grid search over the parameters in @training_performance_variables: concurrent trainers (2, 4, 8, 12), PyTorch threads per trainer (8, 16) and parallel environments per trainer (4, 8, 10, 16). For each configuration, `concurrent_trainers` identical processes were launched at once, each running five PPO iterations (a 256-frame rollout plus four epochs of minibatch updates each iteration) with checkpointing and TensorBoard logging disabled. Configurations with more than 8 trainers and 16 environments (128 or more concurrent Unity instances) exhausted memory and were excluded, leaving 28 single-run configurations. Throughput per trainer was computed from the mean wall-clock time per iteration:

$ "throughput" = ("rollout length" times "parallel envs" times "areas per env") / "seconds per iteration" $

We report the throughput per trainer, showing how much each model slows as the machine gets busier, and summed across trainers, showing where adding trainers stops paying off.

Total throughput peaks at 8 trainers (4172 timesteps/s with 8 environments and 16 threads) and falls at 12 (at most 3853 timesteps/s), while per-trainer throughput roughly halves from 2 to 8 trainers. The best settings use $8 times 16 = 128$ PyTorch threads in total, matching the hardware thread count; at 12 trainers the 16-thread configurations are oversubscribed and fall behind the 8-thread ones. We therefore chose (`concurrent_trainers`, `num_inst`, `pytorch_threads`) = (8, 8, 16), though its margin over the next-best configurations (4020 and 3962 timesteps/s) is within likely run-to-run variation. Using `num_areas` $in {8, 12}$ per environment in this configuration did not help (3844 and 3999 timesteps/s). The performance of each configuration is available in @training_performance_results.

#figure(
  stb-table(
    columns: 3,
    align: (left, center, left),
    header: ("Parameter", "Values considered", "Description"),
    [`concurrent_trainers`],
    [${2, 4, 8, 12}$],
    [Number of independent models training simultaneously, each in its own process.],
    [`pytorch_threads`],
    [${8, 16}$],
    [Threads available to each trainer's PyTorch thread pools.],
    [`num_inst`],
    [${4, 8, 10, 16}$],
    [Number of Unity environment instances per trainer. Each contains 6 training areas, so each instance steps 6 agents in parallel.],
  ),
  caption: "Parameters varied in the training performance grid search.",
) <training_performance_variables>

= Experiments and Results <sec:results>

To evaluate how auxiliary losses affect agent performance, we trained every combination of active auxiliary losses, auxiliary loss weight and model architecture for 600 PPO iterations. Each iteration collected 256 frames from each of 48 concurrent environments, so each run totals about 7.4 million timesteps ($approx 82 "hours"$ of simulated time). We chose 600 iterations because a test run showed the baseline feedforward (FF) model's reward plateauing well before this point (@baseline_reward_per_timestep). Each configuration was trained with 6 different seeds.

To evaluate a run, we took measurements of its performance during the rollout at each training step on the unseen, randomly generated test tracks. We then averaged each statistic over these 50 checkpoints to get one value per run. Averaging reduces checkpoint-to-checkpoint noise. Because consecutive checkpoints are strongly correlated, we treat each average as a single observation, since doing otherwise would lead to an overestimation of the sample size. Therefore, each configuration has $N = 6$ samples (one per seed) rather than $6 times 50$.

== Baseline Model Performance

The baseline feedforward model trained with the PPO loss and no auxiliary targets performed well in the primary task across $N=6$ seeds. It achieved a mean CPMP across 6 seeds of $0.0034 plus.minus 0.0028 "crashes/m"$, indicating approximately one crash every 297 metres. It achieved a mean PPS of $4.13 plus.minus 0.49 "m/s" approx 15 "km/h"$.

The recurrent model performed significantly worse, with a mean CPMP of $0.0381 plus.minus 0.0499 "crashes/m"$, about 11x higher than the feedforward model. It achieved a mean PPS of $2.00 plus.minus 0.692739 "m/s" approx 7.2 "km/h"$, approximately half the performance of the feedforward model.

Before we consider the effect of auxiliary losses, we first establish what the baseline models' internal representations encode in @sec:baseline_model_features.

== Learned Features of the Baseline Models <sec:baseline_model_features>

Consider the network in @network_architecture. Once trained, each layer $l$
maps an input $bold(x)$ to an intermediate representation
$bold(h)^((l))$, which becomes the input to the following layer. We would like to know what
information these intermediate representations encode, and in particular whether they encode
privileged state variables (e.g. velocity, slip, upcoming curvature) so we can better understand the model.

Alain and Bengio @alain2018understandingintermediatelayersusing introduced
_linear probes_ for this purpose; the trunk network's weights are frozen, and a
separate linear classifier (the probe) is trained in a supervised manner on the representations,
$bold(h)^((l))$, of each layer to predict the desired target. Since the
probe cannot change the representation, its test accuracy measures how much
class information is _linearly_ available at that layer. Anand et al.
@anand2020unsupervisedstaterepresentationlearning extended this idea to
reinforcement learning, probing an encoder's representations for ground-truth
state variables of Atari games.

The probe is deliberately linear; a sufficiently expressive probe could compute the target even from the raw LiDAR, so its accuracy would say more about the probe than about the representation @belinkov2021probingclassifierspromisesshortcomings. Since our targets are continuous, we use linear _regression_ probes, as McGrath et al. @mcgrath2022alphazero and Gurnee and Tegmark @gurnee2024languagemodelsrepresentspace do.

A linear probe has the same form as our auxiliary heads: a single dense layer on the same 64-dimensional trunk output. The difference is that the probe is fitted by ordinary least squares (OLS) to a frozen trunk, while an auxiliary head is trained jointly with the policy, and its gradients reshape the trunk. A baseline probe's $R^2$ therefore approximates what an auxiliary head could achieve without changing the representation.

To establish what the baseline represents without auxiliary supervision, linear probes were fit to the output of the final trunk layer to predict each auxiliary target at various points during the model's training. Each probe is an OLS regression model, trained on intermediate representations from a \~35-minute rollout (52429 timesteps) and evaluated on a separate \~9-minute rollout (13107 timesteps). @baseline_lr_model_dumbell reports out-of-sample $R^2$ at initialisation and after 600 PPO iterations.

#figure(
  image("../results/figures/probe_dumbbell.pdf", height: 150pt),
  caption: [Mean out-of-sample $R^2$ scores of linear regression probing of the final layer of the trunk on the (a) recurrent baseline model and (b) feedforward baseline model. Error bars show the standard error of the mean (SEM) across $N = 6$ different seeds. Exact values are reported in @baseline_r2_scores.],
) <baseline_lr_model_dumbell>

Quantities describing the vehicle's _instantaneous dynamics_ are already highly linearly decodable at initialisation in both models. Lateral and angular velocities have high mean $R^2$ scores across the 6 seeds in both model architectures. The recurrent model has a mean $R^2$ for forward velocity, but the feedforward's $R^2$ is much lower.
Since both trunks are untrained and randomly He-initialised @he2015delvingdeeprectifierssurpassing, the high initial $R^2$ values reflect information that is close to linear in the observation and survives random projections, rather than a learned representation. Alain and Bengio @alain2018understandingintermediatelayersusing observed a similar effect in intermediate layers of MNIST models #footnote([Alain and Bengio do not specify which initialisation scheme they use]).

Training does not improve the decodability of any of these quantities, except forward velocity in the FF model, and in the RNN all three fall. The pattern is clearer when the targets are split into _lateral_ quantities (lateral velocity, yaw rate and lateral slip) and _forward_ quantities (forward velocity and forward slip). Lateral quantities are highly decodable in both untrained models and change little with training. They are easily determined#footnote([In the bicycle kinematics model by Althoff et al. @althoff2017commonroad, $omega_y approx v_f dot tan("steering angle") / "wheelbase"$. Our model isn't exactly a bicycle model, but this is an approximation.]) by the current steering angle, which is a direct input to the trunk, so they survive a random projection. Longitudinal quantities instead depend on the _history_ of throttle inputs. The FF trunk receives only the current throttle and must infer speed from changes across the LiDAR stack, which is not linear in the ray lengths; its initial $R^2$ is correspondingly low. A randomly initialised GRU, by contrast, behaves like a fading memory of past inputs, from which a leaky integral of throttle, and hence speed, can be read out linearly @jaeger2001echo. We therefore hypothesise that the RNN's high initial longitudinal $R^2$ is a property of the recurrence rather than a learned representation, and that training moves the two architectures towards each other: the FF trunk learns to extract speed from the frame stack, while the RNN repurposes its recurrent state and longitudinal decodability falls. A fall in _linear_ decodability need not mean the information is discarded. PPO does not reward linear decodability, so the RNN may retain speed in a nonlinear form.

Overall, training of both models trades away decodability of instantaneous dynamics and lateral slip in favour of more decodable track curvature beyond the immediate vicinity of the vehicle, and forward slip in the feedforward model. Because the baseline agent learns the close-ahead and medium-ahead curvature values, we hypothesise that forcing earlier learning of these quantities through auxiliary losses may improve the agent's performance, and we investigate this in @sec:agent_performance_after_auxiliary_learning and @sec:learned_features_after_auxiliary_learning.


== Agent Performance After Auxiliary Learning <sec:agent_performance_after_auxiliary_learning>

The models are now trained with the same reward function as the baseline model, but with the addition of one or more auxiliary heads and their associated auxiliary losses, as described in @sec:weighting_scheme.

@fig:auc_comparison compares the reward AUC of models trained with different auxiliary loss weights against the two baseline models. Some auxiliary losses improve the agent's training speed, while others degrade it. Notably, close-ahead curvature losses improve the AUC for both the feedforward and recurrent models, especially at higher weights, and these models also show some of the lowest variability across seeds. The baseline RNN model performed poorly, with a mean AUC well below the feedforward baseline. However, adding losses for forward wheel slip (at a weight of 0.1), close-ahead curvature (especially at weights 0.3 and 1), and all heads combined (with weight 0.1) improved it substantially. With the close-ahead curvature loss at weights of 0.3 and 1, the recurrent models exceed the feedforward baseline and nearly match the best feedforward model, closing the gap between the two architectures.

#figure(
  image("../results/figures/auc_comparison.pdf"),
  caption: [Reward AUC of the models trained with different auxiliary losses and loss weights over their 600 training iterations, compared to the baseline model (red). The error bars indicate the standard error of the mean across 6 different seeds each. (a) Shows only selected runs for clarity, while (b) shows all runs.],
) <fig:auc_comparison>


The auxiliary losses also affect the two architectures very differently. Relative to their own baseline, 26 of the 33 recurrent configurations improve the reward AUC, compared to only 4 of the 33 feedforward configurations. The same target often has an opposite effect on the two architectures; for example, the forward velocity loss reduces the reward for every weight for the feedforward model, but increases it at every weight for the recurrent model. This suggests that some auxiliary losses mainly compensate for difficulties in training the recurrent model, rather than improving agents in general.


Considering AUC alone is not sufficient to evaluate the performance of the models, as it does not allow us to understand the trade-off between speed and safety. We therefore also evaluate the mean of the last 50 training iterations of each model's metrics (mean reward, PPS, and CPMP) against the baseline model in
@fig:last_50_means_heatmap. The curvature close auxiliary loss features as a strong improvement to both model architectures, achieving up to a -96% CPMP when compared to the recurrent baseline, and a -64% CPMP on the feedforward model. These models are not only safer, but also faster than their respective baselines (+125%, +13% PPS respectively).

The findings in @fig:last_50_means_heatmap must be interpreted with caution, however, as after correcting for multiple comparisons using the Benjamini-Hochberg procedure @benjamini1995controlling, they are not significant at $alpha = 0.05$. We therefore consider these findings as screening for trends rather than definitive conclusions.

#figure(
  image("../results/figures/last_50_means_heatmap.pdf", width: 108%),
  caption: [Mean of the last 50 training iterations of each model's metrics (mean reward, progress per second, and CPMP) vs the baseline model. The model name consists of the active auxiliary loss group and weight. The $p_"adj"$-value is reported in brackets beneath the value in each cell, using a two-sided t-test for the null hypothesis that the means is equal to the baseline model's mean. Adjusted for multiple comparisons in each pane using the Benjamini-Hochberg procedure @benjamini1995controlling],
) <fig:last_50_means_heatmap>

@fig:progress_vs_collision shows the mean PPS vs CPMP for each model configuration, with the baseline FF model marked with the dotted lines. The trend is clear that the close-ahead curvature losses at high weights improve both speed and safety for both architectures.

Importantly, @fig:last_50_means_heatmap and @fig:progress_vs_collision indicate that the majority of auxiliary losses _do not_ improve the FF agent's driving capability, and in most cases degrade it. In contrast, the recurrent agent benefits from many auxiliary losses, and in particular from close-ahead curvature and forward wheel slip. This suggests that the recurrent architecture is more difficult to train, and that auxiliary losses can help it learn better representations of the privileged information.

#figure(
  image("../results/figures/progress_vs_collision.pdf"),
  caption: [Comparison of different models' mean progress per second vs collisions per metre of progress. Bottom right quadrant = faster and safer than the baseline. Bottom left quadrant = slower but safer than the baseline. For readability, some run configurations are cropped off the chart.],
) <fig:progress_vs_collision>

To achieve a higher-power statistical test of the effect of the close-ahead curvature auxiliary loss on the FF network, we run a follow-up experiment with 6 new seeds for each of the close-ahead curvature FF and baseline FF configurations. Comparing only four configurations allows us to more effectively detect statistical differences.

Training with the close-ahead curvature auxiliary loss improves the feedforward model's training speed, stability, and performance, as shown in @fig:training_perf. It achieves a significantly higher PPS (adjusted p-value = 0.036) of +30% compared to the baseline, and a significantly lower CPMP (adjusted p-value = 0.036), 93% better than the baseline on average across the 6 seeds. Importantly, the follow-up experiment drew worse-performing seeds for the baseline compared to the screening, so the unusually good results are partly influenced by the baseline's underperformance.

#figure(
  image("../results/figures/training_perf.pdf"),
  caption: [Training curves for the feedforward model with and without the close-ahead curvature auxiliary loss across 6 seeds. (a) Mean reward per timestep, (b) mean PPS, and (c) smoothed CPMP on a log scale. The solid lines show the mean across 6 seeds, and shaded areas show a 95% confidence interval of the mean.],
) <fig:training_perf>

== Learned Features After Auxiliary Learning <sec:learned_features_after_auxiliary_learning>

Applying the same probing technique from @sec:baseline_model_features after training with auxiliary losses enabled, we find that the decodability of privileged quantities improved significantly when auxiliary losses were used, but that an increase in decodability does not always translate to an improvement in performance.

The decodability of the close-ahead curvature targets improved significantly in both architectures when the close-ahead curvature auxiliary loss was used, as shown in @fig:r2score_diff_curvature_close. The mean out-of-sample $R^2$ for the close-ahead curvature targets increased by up to 0.45 in the feedforward model and up to 0.49 in the recurrent model on average across 6 seeds, indicating that the internal representations of these models now encode this information in a more decodable fashion. When close-ahead curvature losses were applied to the FF model, the decodability of the medium-ahead curvature targets also improved, though may be confounded by the fact that the medium-ahead curvature targets are highly correlated with the close-ahead curvature targets.

Particularly with highly-weighted close-ahead curvature losses in the FF model, the decodability of the forward wheel slip decreased.

#figure(
  image("../results/figures/probe_heatmap_aux_curvature_close.pdf", width: 110%),
  caption: [Absolute difference in mean out-of-sample $R^2$ between the baseline and the model with close-ahead curvature auxiliary losses in (a) the FF network and (b) the recurrent network. The X-axis shows the auxiliary target, and the Y-axis shows the auxiliary training configuration. Red boxes indicate the features that are supervised by the auxiliary loss. Bold where the null hypothesis that the means are equal is rejected ($alpha = 0.05$), corrected for false discovery using the Benjamini-Hochberg procedure @benjamini1995controlling within each architecture across all auxiliary losses and targets. The results for all auxiliary heads are available in @aux_head_regression_results.],
) <fig:r2score_diff_curvature_close>

== Summary of Findings

The experiments address three questions: what a baseline agent's representation encodes, whether auxiliary losses improve driving, and how they reshape the representation.

*What the baseline encodes:* Lateral velocity, yaw rate and lateral slip are already linearly decodable in untrained networks, since they are close to linear in the steering input. PPO training trades this information away in favour of upcoming track curvature in both architectures, and forward slip in the feedforward model (@sec:baseline_model_features).

*Effect on driving:* Close-ahead curvature is the only target that improved both architectures in the screening experiment (up to +13% PPS and -64% CPMP for the feedforward model, and +125% PPS and -96% CPMP for the recurrent model). A follow-up with fresh seeds confirmed the feedforward result: +30% PPS and -93% CPMP (adjusted p-value = 0.036).

Beyond curvature, the two architectures respond very differently: auxiliary losses improved the reward AUC in 26 of 33 recurrent configurations but only 4 of 33 feedforward ones, consistent with the findings of Lample et al. @lample2017fps. Because the recurrent baseline is underperforms compared to the FF model, this suggests that auxiliary losses mainly ease the training of a struggling agent. Part of this benefit may be independent of the target itself. Every effect depends strongly on the loss weight: for example, enabling all targets at $w = 0.1$ raised the recurrent model's AUC to \~73, but at $w = 1$ it remained near the baseline \~42.

*Effect on representations:* Auxiliary losses made their targets more decodable (close-ahead curvature $R^2$ rose by up to 0.45 in the feedforward model and 0.49 in the recurrent model), sometimes at the expense of other quantities, such as forward slip in the feedforward model. Greater decodability does not, however, imply better driving: enabling all targets at $w = 1$ significantly increased decodability, yet produced one of the worst feedforward agents.

*Interpretation:* We hypothesise that close-ahead curvature helps because (a) the auxiliary loss provides a low-variance signal for a quantity the policy learns anyway, so it is learned earlier, which is consistent with the faster rise in @fig:training_perf; and (b) curvature describes what the car must do next, whereas velocity and slip describe what it has already done.

*Probing as a guide:* In the feedforward model, the quantities that became more decodable under plain PPO (close-ahead curvature in both and forward slip) are also those that helped as auxiliary targets. This does not hold for the recurrent model, which benefits from forward velocity and forward slip even though their decodability did not rise during training. Probing may therefore be a useful heuristic for choosing targets, but this relationship is untested.


= Conclusions and recommendations <sec:conclusion>

== Summary

This project investigated whether auxiliary losses that predict privileged information improve a LiDAR-only end-to-end racing agent. All five objectives in @sec:problem_statement_and_objectives were met: a RoboRacer-calibrated Unity simulator was built (@sec:simulator), feedforward and recurrent PPO baselines were trained and probed (@sec:baseline_model_features), and ten auxiliary target categories were evaluated at three weights over six seeds (@sec:agent_performance_after_auxiliary_learning).

The main findings are:
+ Untrained networks already linearly encode the vehicle's dynamics; training trades this for upcoming track curvature.
+ Close-ahead curvature is confirmed to help both architectures. In the follow-up experiment, it reduced the feedforward agent's CPMP from $0.011 plus.minus 0.0081$ to $0.001 plus.minus 0.0003 "crashes/m"$ and raised its PPS from $3.57 plus.minus 0.94$ to $4.66 plus.minus 0.068 "m/s"$ ($p = 0.036$). The recurrent agent improved from a CPMP of $0.0381 plus.minus 0.0499$ to #todo("VALUE") and a PPS of $2.00 plus.minus 0.69$ to #todo("VALUE").
+ Auxiliary losses mostly help the recurrent agent (26 of 33 configurations improved, versus 4 of 33 feedforward).
+ Greater decodability does not guarantee better driving, and every effect depends on the loss weight.
+ There exists a trend that quantities that improve decodability during PPO training are also the ones that improve driving when used as auxiliary targets. We do however, not present a clear, proven relationship.

Apart from the feedforward curvature result, these comparisons were not significant after Benjamini–Hochberg correction, so findings 3 and 4 are trends rather than confirmed effects.

== Limitations

The feedforward agent receives 50 LiDAR frames and the recurrent agent 4, so their differences are not due to recurrence alone. The 600-iteration budget came from a feedforward pilot, so the recurrent baseline may have been undertrained. The leave-one-in design ignores interactions between targets, linear probes miss nonlinearly encoded information, and all work was in simulation. Furthermore, our work achieved improved performance, but it was only possible by evaluating many different auxiliary loss configurations. We do not provide a method in general to _a priori_ determine which auxiliary losses will improve the agent's performance, or to select loss weights. Although we ran many training runs to explore the effect of auxiliary losses, we did not consider whether this compute budget would be better spent on other avenues, such as tuning of the PPO agent.

== Recommendations and future work

Practitioners should probe a baseline before choosing auxiliary targets, favour quantities training already moves towards, and test several weights per target. Future work should confirm the recurrent result with fresh seeds and a matched frame stack, combine close-ahead curvature with other targets, evaluate primary-task-aware weighting such as AuxiLearn @navon2021auxiliarylearningimplicitdifferentiation, and transfer the agents to a physical RoboRacer.


#pagebreak()
#bibliography("./hyagriva.yaml", style: "ieee", title: [Bibliography])

#in-appendix.update(true)
#set heading(supplement: none, numbering: none)

= Appendix

#counter(heading).update(1)
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

//#counter(heading).update(ar => (ar.at(1), 0))

#set page(flipped: true)
== Project Timeline
#[
  #set text(size: 0.9em)

  #figure(
    gantty.gantt(
      (
        tasks: (
          (
            name: [Background research],
            intervals: ((start: "2026-06-05", end: "2026-10-15"),),
            subtasks: (
              (
                name: [Reinforcement learning],
                intervals: ((start: "2026-06-05", end: "2026-07-17"), (start: "2026-09-30", end: "2026-10-30")),
              ),
              (
                name: [Auxiliary learning and privileged information],
                intervals: ((start: "2026-06-22", end: "2026-07-31"), (start: "2026-09-30", end: "2026-10-30")),
              ),
              (
                name: [Autonomous racing and RoboRacer],
                intervals: ((start: "2026-07-06", end: "2026-08-14"), (start: "2026-09-30", end: "2026-10-30")),
              ),
            ),
          ),
          (
            name: [Simulator development],
            intervals: ((start: "2026-08-10", end: "2026-10-24"),),
            subtasks: (
              (
                name: [Setting up AutoDrive],
                intervals: ((start: "2026-08-10", end: "2026-09-28"),),
              ),
              (
                name: [Custom simulator],
                intervals: ((start: "2026-09-30", end: "2026-10-24"),),
              ),
              (
                name: [Benchmark environment performance],
                intervals: ((start: "2026-09-05", end: "2026-10-21"),),
              ),
            ),
          ),
          (
            name: [Baseline agent],
            intervals: ((start: "2026-09-20", end: "2026-10-23"),),
            subtasks: (
              (
                name: [PPO training pipeline (TorchRL, ML-Agents)],
                intervals: ((start: "2026-09-20", end: "2026-09-28"),),
              ),
              (
                name: [Trainer performance tuning],
                intervals: ((start: "2026-09-20", end: "2026-10-10"),),
              ),
              (
                name: [Baseline training and evaluation],
                intervals: ((start: "2026-09-28", end: "2026-10-23"),),
              ),
            ),
          ),
          (
            name: [Auxiliary learning experiments],
            intervals: ((start: "2026-09-26", end: "2026-10-25"),),
            subtasks: (
              (
                name: [Auxiliary heads and losses],
                intervals: ((start: "2026-09-26", end: "2026-10-09"),),
              ),
              (
                name: [Loss-weight grid search (6 seeds)],
                intervals: ((start: "2026-10-06", end: "2026-10-15"),),
              ),
              (
                name: [Linear probing and statistical analysis],
                intervals: ((start: "2026-10-09", end: "2026-10-25"),),
              ),
            ),
          ),
          (
            name: [Report writing],
            intervals: ((start: "2026-09-23", end: "2026-10-31"),),
            subtasks: (
              (
                name: [Literature review chapter],
                intervals: ((start: "2026-09-23", end: "2026-10-24"),),
              ),
              (
                name: [Agent and method chapters],
                intervals: ((start: "2026-09-29", end: "2026-10-17"),),
              ),
              (
                name: [Results and conclusion],
                intervals: ((start: "2026-10-13", end: "2026-10-26"),),
              ),
              (
                name: [Revision and submission],
                intervals: ((start: "2026-10-25", end: "2026-10-31"),),
              ),
            ),
          ),
        ),
      ),
      drawer: gantty.drawers.default-drawer
        + (
          headers: gantty.header.default-headers-drawer.with(headers: (
            gantty.header.default-month-header(),
          )),
          milestones: gantty.milestones.default-milestones-drawer.with(today-content: none),
        ),
    ),
    caption: [Timeline of the project, showing the main tasks and their durations.],
  )
]
#set page(flipped: false)

== Graduate Attributes
=== Complex Engineering Problem

The project features a first-principles formulation of autonomous racing as a POMDP and of the vehicle dynamics (@sec:pomdp), specialist RL knowledge (@sec:rl), and engagement with current research on privileged information, auxiliary learning and probing (@sec:related_literature, @sec:baseline_model_features). It has no obvious solution: a LiDAR-only agent must learn quantities it cannot observe, and it is unclear which privileged targets or loss weights will help. It involves conflicting requirements (speed vs. safety (@sec:agent_performance_after_auxiliary_learning), primary vs. auxiliary losses, fidelity vs. training speed (@sec:simulator)) and coupled subsystems, since the trainer and simulator compete for the same hardware and must be tuned together.

=== Problem Solving (GA1)

- *Identification and literature:* Starting from road crashes caused by human error, a public health issue (SDG 3.6), I narrowed the project to a LiDAR-only RL agent that must learn unobservable quantities such as velocity, slip and upcoming curvature. The literature showed auxiliary losses had not been studied for LiDAR-only racing (@sec:related_literature), and I turned this gap into objectives (@sec:problem_statement_and_objectives).

- *Formulation from first principles:* I formulated racing as a POMDP (@sec:pomdp), derived the policy gradient theorem underlying PPO (@sec:policy_gradient_theorem_proof), modelled the vehicle from rigid-body mechanics, slip kinematics and a Pacejka fit (@sec_wheelcollider), and derived curvature targets from differential geometry (@sec:simulator).

- *Analysis and method selection:* Benchmarks used to justify the simulator (@sim_benchmarks), heavy-tailed targets justify the Huber loss (@sec:loss_function). I traced failures to their causes, such as tanh saturation and LiDAR tilt from chassis pitch (@sec:agent).

- *Substantiated conclusions:* With 6 seeds per configuration, one observation per seed, bootstrapped confidence intervals, Benjamini–Hochberg-corrected t-tests and out-of-sample $R^2$ (@sec:metrics, @sec:results), I showed that close-ahead curvature is the primary target that helps both architectures and that decodability does not guarantee better driving, flagging non-significant results and hypotheses (@sec:conclusion).

- *Sustainable development:* The work supports road safety and the interpretability needed for safety-critical learning systems. Simulation avoided hardware damage and real-vehicle risk, and throughput tuning cut compute energy.

=== Application of Scientific and Engineering Knowledge (GA2)

- *Mathematics:* Track curvature comes from the osculating circle, and closed tracks from a mean-reverting random walk, Catmull-Rom splines and polygon offsetting (@sec:track). Numerical methods included a least-squares Pacejka fit (@wheel_friction_curve) and trapezoidal AUC integration; statistics included normalisation, binomial and bootstrapped confidence intervals, OLS probes and corrected t-tests (@sec:metrics, @sec:results).

- *Natural sciences:* The RoboRacer is modelled as a rigid body on four suspended wheels with slip-dependent friction and a rate-limited servo, using a published calibration (@sec:simulator, @wheel_collider_properties). The same physics explained an observed failure: weight transfer pitches the chassis, the LiDAR scans over the walls and gradients explode, which layer normalisation fixed (@sec:agent).

- *Computing:* A C\# Unity simulator and a PyTorch/TorchRL trainer communicate over gRPC via ML-Agents (@sec:system_overview). 1D convolutions along the ray axis match the network to the sensor (@network_architecture), and a grid search, informed by OS and threading knowledge, maximised throughput on 64 cores (@system_diagram, @training_performance_results).

- *Specialisation:* As an Electrical & Electronic student specialising in Data Engineering, I applied deep RL (@sec:pomdp, @sec:ppo), multi-task learning with a Huber loss (@sec:loss_function), linear probing (@sec:baseline_model_features) and statistical testing (@sec:results).

=== Engineering Design (GA3)
The major design problem was a complete system for training and evaluating LiDAR-only racing agents with auxiliary losses, designed against requirements from the objectives (@sec:problem_statement_and_objectives).

- *Identifying needs:* The simulator had to model slip meaningfully, report privileged information every step, generate unlimited tracks and run fast. The F1Tenth gym linearises slip, and AutoDrive lacks track generation and privileged information (@sec:simulator).

- *Simulator:* My Unity simulator reuses AutoDrive's `VehicleController` and `IMU` and adds four `WheelCollider`s, wall colliders and a feature extractor (@system_diagram, @sec_wheelcollider). It is only 19% slower than the F1Tenth gym (@sim_benchmarks).

- *Track generator:* An original random walk with a restoring strength that ramps up over the lap lets tracks wander yet close (@sec:track, @fig:walk-step). Polygon offsetting avoids narrow sections (@trackgen_inset_outset), and rejecting the rare degenerate tracks (0.05% and 1.35%) costs little.

- *Agent:* A shared convolutional trunk feeds policy, value and auxiliary heads, so auxiliary gradients shape the policy's representation (@sec:agent, @network_architecture). A clamped linear output fixed tanh saturation, layer normalisation fixed pitch-induced gradient explosions, and the two variants differ only in the GRU.

- *Loss and experiments:* Testing ten categories alone at three weights needs 34 configurations instead of $4^10 approx 1.05 "million"$, at the cost of ignoring interactions (@sec:weighting_scheme). Normalisation and the Huber loss stop heavy-tailed targets dominating (@sec:loss_function), and reward weights can be tuned to an application's risk tolerance (@sec:reward_function).

=== Investigations, Experiments and Data Analysis (GA4)

The investigation asked which privileged targets, as auxiliary losses, help a LiDAR-only racing agent and how they change its representation, a question the literature had not answered (@sec:related_literature).

- *Research-based method:* Since Lample et al. @lample2017fps found auxiliary losses helped only recurrent agents, I tested both architectures. I adopted linear probing @alain2018understandingintermediatelayersusing @anand2020unsupervisedstaterepresentationlearning, keeping probes linear so $R^2$ reflects the representation rather than the probe @belinkov2021probingclassifierspromisesshortcomings (@sec:baseline_model_features).

- *Design of experiments:* Each category was enabled alone at three weights against a no-auxiliary baseline, with six seeds and a fixed reward, hyperparameters and 600-iteration budget from a pilot run (@sec:weighting_scheme, @baseline_reward_per_timestep). Agents were evaluated on unseen tracks, and preliminary benchmarks made the runs feasible (@sim_benchmarks, @sec:trainer_performance_tuning).

- *Analysis of data:* The last 50 checkpoints of each run were averaged into one observation per seed to avoid inflating the sample size, then compared with Benjamini–Hochberg-corrected t-tests @benjamini1995controlling and reward AUC (@sec:metrics). Probes were scored on a separate rollout, and collisions per metre replaced collisions per episode, which favours slow agents.

- *Critical interpretation:* Velocities and yaw rate are decodable even in untrained networks, so I did not credit this to learning, and greater decodability did not guarantee better driving (@sec:learned_features_after_auxiliary_learning).

- *Conclusions and recommendations:* Close-ahead curvature helps both architectures, effects depend strongly on weight, and auxiliary losses mainly ease recurrent training (@sec:agent_performance_after_auxiliary_learning). I reported where differences miss $alpha = 0.05$, labelled hypotheses as such, and recommended adaptive weighting, richer environments and work on predicting *a priori* which losses and weights help (@sec:conclusion).

=== Use of Engineering Tools (GA5)

- *Simulation:* I chose Unity with PhysX over the F1Tenth gym after benchmarking (@sim_benchmarks). PhysX uses Euler rather than RK4 integration, and the `WheelCollider` lacks servo rate limits and wheel-wall collisions, so I added AutoDrive's `VehicleController` and box colliders (@sec:simulator). I used Clipper2 for wall offsetting and rejected the \~1.35% of tracks where it produced "islands" (@sec:track).

- *Machine learning:* PyTorch and TorchRL connect to Unity via ML-Agents (@system_diagram). I fixed tanh-squashed Gaussian saturation and unbounded trunk activations in the architecture (@sec:agent), and rejected Hyperband and ASHA, which can kill RL runs that improve late (@sec:finding_optimal_weights).

- *Analysis:* I used NumPy, Pandas, Matplotlib and Seaborn, recognising their limits: linear probes measure only _linearly_ decodable information (@sec:baseline_model_features), $R^2$ suits targets with different units (@sec:r2_score), and $N = 6$ seeds leaves many differences non-significant (@sec:results).

- *Compute and documentation:* A 28-configuration grid search tuned the trainer, with the top configurations within run-to-run variation (@sec:trainer_performance_tuning). The report was written in Typst, with figures in CeTZ, Fletcher and Lilaq.

=== Professional and Technical Communication (GA6)

The report targets engineers who need not be RL specialists.

- *Structure:* The report moves from road safety, understandable to lay-readers, to the technical gap (@sec:related_literature), and introduces concepts intuitively before formally, e.g. the "pulled-back random walk" (@sec:track).

- *Conventions:* A notation chapter and acronym list define every symbol, only referenced equations are numbered, tables use booktabs style, and the layout follows the Stellenbosch University thesis class.

- *Figures:* I drew the key diagrams by hand rather than with AI so each shows exactly the textual point (@system_diagram, @network_architecture, @fig:walk-step), with self-contained captions.

- *Honest reporting:* Non-significant results, hypotheses and misleading metrics are flagged (@sec:agent_performance_after_auxiliary_learning).

- *Oral communication:* I met my supervisor regularly and presented to the research group every second week.

=== Individual Work (GA8)

I designed and implemented the simulator, track generator, agent, training pipeline and analysis individually, writing the training and model code by hand (see the AI declaration).

- *Planning:* I planned in phases (Gantt chart) and adapted, switching to a custom simulator when AutoDrive proved unsuitable.

- *Resources:* About 400 runs, roughly $3 times 10^9$ timesteps, were feasible only through throughput tuning (@sec:trainer_performance_tuning) and the leave-one-in design (@sec:weighting_scheme).

- *Ethics:* I acknowledged all sources and software, declared all AI use, and reported negative results.

- *Supervision:* I met my supervisor weekly and incorporated their feedback.

=== Independent Learning Ability (GA9)

Most of the required knowledge was outside my coursework.

- *Reinforcement learning:* I learned RL from Sutton and Barto, David Silver's lectures and primary sources, deriving the policy gradient theorem myself (@sec:policy_gradient_theorem_proof).

- *Tools and literature:* I learned Unity, C\#, TorchRL, ML-Agents and Typst, and adapted probing from interpretability research to regression targets (@sec:baseline_model_features).

- *Self-evaluation:* I diagnosed failures instead of tuning them away, recognised the limited power of 6 seeds and my untested hypotheses (@sec:results), and identified how to resolve them (@sec:conclusion).


=== Sustainable Development

The long-term motivation is road safety (SDG 3.6). Autonomous driving could reduce crashes caused by human error and lower emissions through smoother traffic flow, but only if learned driving policies become reliable and interpretable. This project contributes a small step towards both.

*Efficient resource use and re-use:* Rather than building a simulator from scratch, I re-used AutoDrive's components, a published vehicle calibration and an existing polygon library. Working entirely in simulation avoided damage to physical vehicles and the material cost of crash testing. The leave-one-in design and the throughput tuning both reduced the compute, and hence the energy, needed for the experiments.

*Whole-life cost:* Auxiliary heads exist only during training and are discarded at deployment. Any improvement they bring therefore adds no onboard computation or energy use over the vehicle's operating life, unlike approaches that add sensors or larger networks.

*Net zero carbon:* Training hundreds of RL agents is energy-intensive, and South Africa's electricity is predominantly generated from coal. A natural improvement would be to measure and report the energy use of the experiments, and to prefer methods, like auxiliary losses, that improve sample efficiency so that fewer training timesteps are needed.

=== Critical Thinking

Critical thinking affected the project in several places. I chose a less common simulator because the literature's default linearises the very slip dynamics I wanted to predict. I rejected adaptive weighting methods because they balance all tasks, while only the driving task matters here (@sec:finding_optimal_weights). When probes showed high $R^2$ at initialisation, I did not take this as learned knowledge, but attributed it to random projections of near-linear inputs. I treated the 50 correlated checkpoints of each run as a single observation to avoid inflating the sample size. I corrected for multiple comparisons, and stated when results did not meet the significance threshold. Finally, the central finding is itself a caution against a tempting assumption: making a quantity more decodable does not necessarily make the agent drive better (@sec:learned_features_after_auxiliary_learning). I applied the same scrutiny to AI tools, checking their suggestions against sources and discarding outputs, such as generated diagrams, that did not meet the standard I wanted.

=== Emerging Technologies

The project is built on emerging technologies. End-to-end deep RL for driving is still an active research area that has not yet matched classical pipelines on the RoboRacer platform (@sec:related_literature). I evaluated game engines as physics simulators against a purpose-built research simulator, and I used recent libraries (TorchRL, ML-Agents) to train with them. Linear probing comes from current interpretability research, much of it on large language models, and I applied it to an RL driving agent. Generative AI tools (Claude, Gemini, DeepSeek and Google Scholar Labs) supported literature search and debugging. I treated their outputs as suggestions to be verified, as detailed in the AI declaration. A natural next step would be to transfer the trained agents to a physical RoboRacer, testing whether the representations shaped in simulation survive the reality gap.


#pagebreak()

== AI Declaration

=== AI Work Declaration

- #link("http://claude.ai")[Claude] was used for searching literature, checking the report for errors, advice on clarity of writing, and changing the format of references from BibTex to Hayagriva. Furthermore, Claude was used to explain various tensor shape bugs in PyTorch code, but the final implementation was always done manually, as well as to explain how TorchRL works. Initially, Claude was used to generate diagrams, but I did not like how little control I had over the diagrams, so re-implemented them manually from scratch. Claude was used to generate parts of @fig:walk-step based on a handmade diagram. Claude was used to explain to me why certain training setups may perform badly on the hardware available. Claude was used to explain how to perform the FDR analysis on @aux_head_regression_results, but the code was written by me, and I understand the process. Clause was also used in the formulation of the track curvature calculations in @sec:track_curvature, as well as implementation in code.

- #link("https://gemini.google.com")[Google Gemini] was used to a lesser extent for searching literature, and, before starting the project, for assistance in understanding RL in conjunction with the #link("https://www.youtube.com/watch?v=2pWv7GOvuf0")[David Silver videos]. Gemini was instrumental in explaining potential-based reward shaping in an easy-to-understand way. Gemini was used to do spelling & grammar checking. Google Gemini was used to translate the GA statements more understandable, less flowery form. Gemini was also used to read the report and provide advice on what information could be included in the GA appendix.

- #link("https://scholar.google.co.za/scholar_labs/search")[Google Scholar Labs] was used extensively in searching for literature.
- #link("http://chat.deepseek.com")[DeepSeek] was used to search for literature, and to provide input on the structure and content of the report. For example, it advised which sections could be reduced in length without sacrificing report quality. Deepseek was also used to provide advice on how to make charts look better, although the implementation was done by hand.


=== Own Work Declaration
AI was not used to generate the training code or the model definition code - that was hand-coded. Furthermore, the statistical analysis code was hand-written, and the report was written by hand, with AI used for checking grammar and spelling, and for advice on the writing. The graphs and diagrams were hand-coded. Creation of the simulator was done by hand, although AI was regularly consulted on how Unity works.

#pagebreak()

== WheelCollider properties <wheel_collider_properties>
The values in @fig:wheel_collider_properties are the parameters of the WheelCollider model used in the Unity simulator. These parameters were fit by Samak and Samak @samak2024autonomyorienteddigitaltwins to the RoboRacer vehicle, and are used in the simulator to model the vehicle's dynamics. The WheelCollider model is a simplified physics model that approximates the behaviour of a real wheel, and is used in Unity to simulate the vehicle's movement and interaction with the environment. Identical parameters are used for all four wheels of the vehicle.

#figure(
  stb-table(
    columns: 3,
    align: (left, left, left),
    header: ("Property", "Description", "Value for RoboRacer"),
    [`radius`],
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
) <fig:wheel_collider_properties>

#pagebreak()
== Derivation of the Policy Gradient Theorem <sec:policy_gradient_theorem_proof>

This appendix provides a proof of the policy gradient theorem based on Sutton et al. @@sutton1999policygradient, where, given a policy $pi_theta$ parameterised by $theta$, the gradient of the expected return $J(theta)$ with respect to $theta$ can be expressed as an expectation over trajectories $tau$ sampled from the policy:

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

and since $p(s_0)$, $cal(P)$, $cal(Z)$ and $cal(R)$ do not depend on $theta$, their factors vanish, so

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
  = integral_a nabla_theta pi_theta (a | o_t) dif a
  = nabla_theta integral_a pi_theta (a | o_t) dif a
  = nabla_theta 1 = 0,
$
The past-reward terms therefore vanish in expectation, leaving
$
  nabla_theta J(theta) = EE_(tau tilde p_theta) [sum_(t=0)^(T-1) gamma^t nabla_theta log pi_theta (a_t | o_t) G_t].
$
Removing these zero-mean terms typically reduces the variance of the
Monte Carlo estimate. In practice the factor $gamma^t$ is usually dropped.
This yields a biased estimate of $nabla_theta J(theta)$ for $gamma < 1$
@thomas2014bias however.

#pagebreak()
== Distribution of Auxiliary Targets <sec:prop_data_within_sd>

@fig:prop_data_within_sd shows the proportion of auxiliary target values within 1 standard deviation of the mean, and the proportion of values beyond 3 standard deviations of the mean. It is used in @sec:loss_function to justify the choice of the Huber loss function for the auxiliary losses, since it is more robust to outliers than the SE loss.

#{
  let data = csv("../results/prop_data_within_sd.csv").slice(1)
  figure(
    stb-table(
      columns: 4,
      align: (left, center, center, center),
      header: (
        "Auxiliary target",
        [$hat(P)(|X| < 1 sigma)$],
        [$hat(P)(|X| > 3 sigma)$],
        [$hat(P)(|X| > 3 sigma) div P_"normal" (|X| > 3 sigma)$],
      ),
      ..data
        .map(row => (
          row.at(0),
          [#calc.round(float(row.at(1)) * 100, digits: 2)%],
          [#calc.round(float(row.at(2)) * 100, digits: 2)%],
          [#calc.round(float(row.at(3)), digits: 2)x],
        ))
        .flatten(),
    ),
    caption: [Proportion of auxiliary target values within 1 standard deviation of the mean, and proportion of values beyond 3 standard deviations of the mean. The last column shows the ratio of the proportion of values beyond 3 standard deviations to the expected proportion for a normal distribution (0.27%).],
  )
} <fig:prop_data_within_sd>

#pagebreak()
== Baseline $R^2$ Scores <baseline_r2_scores>

The below table shows the out-of-sample $R^2$ scores of linear regression probing of the final layer of the trunk on the recurrent and feedforward baseline models. The scores are reported at initialisation and after 600 PPO iterations. These results are used in @sec:baseline_model_features to establish what the baseline models' internal representations encode without auxiliary supervision, and what the effect of training is on the decodability of privileged quantities.
#{
  let data = csv("../results/baseline_r2_scores.csv").slice(3)

  figure(
    stb-table(
      columns: 5,
      align: (left, left, left, left, left),
      header: (
        [],
        table.cell("Feedforward baseline", colspan: 2),
        table.cell("Recurrent baseline", colspan: 2),
        [Auxiliary target],
        [Initialisation],
        [Trained],
        [Initialisation],
        [Trained],
      ),
      ..data
        .map(row => (
          row.at(0),
          [#calc.round(float(row.at(1)) * 100, digits: 1)%],
          [#calc.round(float(row.at(2)) * 100, digits: 1)%],
          [#calc.round(float(row.at(3)) * 100, digits: 1)%],
          [#calc.round(float(row.at(4)) * 100, digits: 1)%],
        ))
        .flatten(),
    ),

    caption: [Mean out-of-sample $R^2$ scores across 6 seeds for linear regression probing of the final layer of the trunk on the recurrent and feedforward baseline models. $R^2$ scores are reported at initialisation and after 600 PPO iterations.],
  )
}
#pagebreak()
== Mean Reward Per Timestep of a Baseline FF Model <baseline_reward_per_timestep>
The below figure shows the mean reward per timestep of a test baseline feedforward model that was executed before the hyperparameter grid search. We use this figure in @sec:results to justify the choice of 600 training iterations for each configuration, since it converges after 400-600 iterations.

#figure(
  image("../results/figures/baseline_reward.pdf"),
  caption: [Mean reward per timestep of a baseline feedforward model over 600 training iterations, averaged across the timesteps in each iteration. Qualitatively, the model converges after 400-600 iterations],
)


#pagebreak()
== Training Performance Benchmark Results <training_performance_results>

@fig:training_performance_results shows the benchmark results of training performance with various number of concurrent trainers, trainer threads, and parallel environments. Trainer threads indicates the number of parallel PyTorch processes per trainer.

#[
  #let training_performance_results = (
    csv("../results/bench_perf.csv").slice(1).sorted(key: row => float(row.at(8)), by: (a, b) => a > b)
  )
  #set par(justify: false)

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
    scale(90%, reflow: true, stb-table(
      columns: 5,
      align: (center, center, center, right, right),
      header: (
        "Concurrent trainers",
        "Trainer threads",
        [Parallel envs#footnote("It was not possible to run 16 parallel envs on 12 trainers, because the machine ran out of memory.")],
        "Throughput (timesteps/sec)",
        [Speedup vs realtime#footnote("Assuming 25 Hz decision frequency")],
      ),
      ..training_performance_results.map(row-to-content).flatten(),
    )),
    caption: "Training performance results, sorted by throughput.",
  ) <fig:training_performance_results>
]


#pagebreak()
== $R^2$ Scores After Training with Auxiliary Heads <aux_head_regression_results>

The following two figures, @fig:aux_head_regression_results and @fig:aux_head_regression_results_rnn, show the difference in mean out-of-sample $R^2$ scores of linear regression probing of the final layer of the trunk on the feedforward and recurrent models, respectively, after training with auxiliary heads. The X-axis shows the auxiliary target, and the Y-axis shows the auxiliary training configuration. Red boxes indicate the features that are supervised by the auxiliary loss. Bold where the null hypothesis that the means are equal is rejected ($alpha = 0.05$), corrected for false discovery rate using the Benjamini-Hochberg procedure @benjamini1995controlling.

These figures show that the decodability of privileged quantities is improved significantly in the close- and medium-ahead curvature auxiliary loss configurations, as well as when all auxiliary losses are enabled.

In most configurations, the decodability of the forward wheel slip quantities decreases when auxiliary heads not related to forward wheel slip are enabled.

#figure(
  image("../results/figures/probe_heatmap_aux.pdf", height: 85%),
  caption: [Difference in mean out-of-sample $R^2$ vs the baseline feedforward PPO model. The X-axis shows the auxiliary target, and the Y-axis shows the auxiliary training configuration. Red boxes indicate the features that are supervised by the auxiliary loss. Bold where the null hypothesis that the means are equal is rejected ($alpha = 0.05$), corrected for false discovery rate using the Benjamini-Hochberg procedure @benjamini1995controlling],
) <fig:aux_head_regression_results>
#figure(
  image("../results/figures/probe_heatmap_aux_rnn.pdf", height: 85%),
  caption: [Difference in mean out-of-sample $R^2$ vs the baseline recurrent PPO model. The X-axis shows the auxiliary target, and the Y-axis shows the auxiliary training configuration. Red boxes indicate the features that are supervised by the auxiliary loss. Bold where the null hypothesis that the means are equal is rejected ($alpha = 0.05$), corrected for false discovery rate using the Benjamini-Hochberg procedure @benjamini1995controlling],
) <fig:aux_head_regression_results_rnn>
