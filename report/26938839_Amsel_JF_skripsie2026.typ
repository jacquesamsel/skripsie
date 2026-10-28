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

#set ref(supplement: it => {
  if it.func() == heading {
    if it.supplement == none { none } else if it.level == 1 { "Chapter" } else { "Section" }
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
#set par(leading: 0.7em, spacing: 1.05em)

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
#set par(justify: true, first-line-indent: (amount: 1.5em, all: false))

= Acknowledgements

This work would not have been possible without the support of my supervisor, Dr. JC Schoeman, who provided valuable guidance and feedback throughout the project. I would also like to thank my friends and peers for their encouragement and support, as well as my family for their support throughout my studies. Finally, I would like to thank the developers of the open-source software and libraries that were used in this project, including, but not limited to, PyTorch, NumPy, Matplotlib, Seaborn, Pandas, Python, and Ubuntu. Without their contributions, this work would have been immensely more difficult.

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
  [Student number #place(horizon + center)[#text("26938839", size: 24pt)]],
  [#place(horizon + center)[#image("./signature.png")]
    Signature
  ],

  [Initials and surname #place(horizon + center)[#text("JF Amsel", size: 24pt)]],
  [Date #place(horizon + center)[#text(datetime.today().display("[day] [month repr:long] [year]"), size: 24pt)]],
)

#pagebreak()

= Abstract

End-to-end reinforcement learning (RL) agents can drive a car directly from raw sensor inputs, but a LiDAR-only agent must implicitly learning quantities it cannot observe, such as its own velocity, tyre slip, and the curvature of the track ahead to perform well. In simulation, these quantities are available as privileged information, yet standard RL provides no direct signal to learn them; even when the reward is dense, it is still an indirect and high-variance teaching signal for these quantities, so the agent learns them slowly. This project investigates whether auxiliary losses that predict privileged information can be applied to improve the performance and training speed of a LiDAR-only end-to-end racing agent, and whether they change what the agent's internal representations encode.

We find that close-ahead track curvature prediction has a positive effect on the training speed, racing performance, crash rate, and representation quality of the agent, while other losses such as velocity and slip prediction have little-to-no effect.




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
- *Calligraphic letters* denote sets or spaces: $cal(S)$, $cal(O)$, $cal(A)$ are the state, observation, and action spaces, except for the reward function $cal(R): cal(S) times cal(A) times cal(S) -> RR$, the observation function, $cal(Z): cal(S) -> Delta_cal(O)$, and the transition function $cal(P): cal(S) times cal(A) -> Delta_cal(S)$. Lowercase elements live in the corresponding space, e.g. $s in cal(S)$,
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

  table.cell(colspan: 2)[*Calculus*],
  [$nabla_theta f(theta)$], [Gradient of the function $f(theta)$ respect to parameters $theta$],

  table.cell(colspan: 2)[*Probability and statistics*],
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

Road traffic crashes remain a leading cause of death and serious injury worldwide @who2018roadsafety, and the overwhelming majority are attributed to human error @hankey1999identification, as cited by Medina et al. @medina2004relationshipinfrastructuredrivererror. Autonomous driving promises to reduce severe and fatal accidents @olofsson2021crashdatabases, improve traffic flow @VanDriel2010congestion, and reduce emissions @ignlinski2017autonomous-vehicles-ghg. Before such systems can be trusted on public roads, however, they must handle difficult situations, where small mistakes compound quickly. Autonomous racing is a demanding proxy for these situations because high speeds, tight control margins, and short recovery times stress the driving policy

Broadly, autonomous driving control architectures fall into two paradigms: modular pipelines and end-to-end learning. Modular pipelines decompose the driving task into distinct sub-problems, such as perception, planning, and control; this provides interpretability and simplifies debugging, but often demands extensive domain expertise and manual tuning. End-to-end learning instead maps raw sensor inputs (e.g., LiDAR or camera frames) directly to control outputs (e.g., speed and steering angle). It avoids hand-engineered intermediate representations, but typically requires vast amounts of data and suffers from poor interpretability, making failures difficult to diagnose @chen2020interpretableendtoendurbanautonomous.

Auxiliary learning, as popularised by Jaderberg et al. @jaderberg2017unreal, presents a compelling method to address these shortcomings. By training a model to perform secondary tasks alongside its primary control objective, the network is encouraged to learn richer, more structured intermediate representations @rafiee2022makesusefulauxiliarytasks while improving interpretability @chen2020interpretableendtoendurbanautonomous. In simulation, privileged ground-truth state is available during training even when it is unavailable to the deployed policy. This motivates the question of whether such auxiliary signals can improve an end-to-end racing agent that must drive from limited onboard sensing.

== Problem Statement and Objectives <sec:problem_statement_and_objectives>
An end-to-end reinforcement learning (RL) agent that drives from LiDAR alone has to learn representations of privileged information that it cannot directly observe in the real world: its own velocity and slip, upcoming track curvature, and, in Head-to-Head (H2H) racing, the opponent's location. Early in training, the agent has not yet learned to drive well enough to explore the track effectively, so the reward signal that would teach it these representations is sparse and noisy. This can lead to slow convergence. This can slow convergence and lead to sub-optimal policies. Privileged information is, however, available in simulation.

This report investigates whether _auxiliary heads_ that predict privileged information from the policy's shared representation can improve a LiDAR-only end-to-end racing agent. The objectives are to:

#set enum(numbering: "(a)")
+ select an appropriate simulation environment for autonomous racing;
+ implement a baseline end-to-end RL agent that drives from LiDAR alone;
+ quantify what representations the baseline agent natively encodes;
+ implement auxiliary learning to provide additional supervisory signals to the agent during training; and
+ compare the auxiliary-learning agent against the baseline on driving performance and representation quality.
#set enum(numbering: "1.")

== Solution Overview and Scope

The project was executed in three phases: simulation development, baseline evaluation, and auxiliary learning experimentation. First, a custom 3D racing simulator was built in Unity using PhysX-based vehicle dynamic and a procedural track generator. This custom simulator was benchmarked against the standard F1Tenth Gym @okelly2020f1tenthgym. Second, a baseline end-to-end reinforcement learning (RL) agent was trainged with Proximal Policy Optimisation (PPO) and a dense progress-based reward. Third, auxiliary heads were added to the network to predict privileged state information during training. The motivation for this approach is developed in the following chapters.

The scope is limited to simulation; no sim-to-real transfer to a physical RoboRacer was attempted. The agent drives from LiDAR and its current steering and throttle only, using a memoryless feedforward policy, and a recurrent policy was also evaluated. Learning is done using PPO, and auxiliary losses are studied; auxiliary rewards and reward shaping are discussed as background but not evaluated. Only single-agent racing is studied, so opponent information is not considered.


== Report Outline

@sec:related_literature reviews the background and related literature. It contrasts classical modular pipelines with end-to-end learning approaches to autonomous racing, and surveys how rivileged information has previously been exploited through other methods. The chapter closes by identifying the gap in the literature that this report addresses: auxiliary losses have not been studied for LiDAR-only end-to-end racing agents, and it is unknown which privileged targets help or how they reshae the policy's representation.

@sec:system_overview provides a brief system overview, describing how the simulator and python training script communicate, and how observations, actions, and rewards flow between them.

@sec:simulator presents the custom Unity simulator. It justifies the choice of simulator, benchmarking it against the F1Tenth gym, and describe the vehicle dynamics implemented, as well as the procedural track generation and privileged information available during training.

@sec:training decsribes the agent and auxiliary learning method. It formalises racing as a POMDP, introduces PPO and the network architecture, and defined the auxiliary targets, loss functions, and weighting strategy, together with the metrics used for evaluation.

@sec:results reports the expirements performed and their results. It first characterises the baseline agent's performance, and, using linear probes, what its internal representation natively encodes; it then evaluates each auxiliary configuration against the baseline on diving performance and representation quality. This chapter tests the central claim that auxiliary losses improve both representation learning and racing behaviour.

@sec:conclusion concludes the report. It summarises the findings against the objectives, discusses limitations, and outlines future work, thereby placing our contributions in the context of the broader autonomous racing literature.

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
Asymetric actor-critic methods @pinto2017asymmetricactorcriticimagebased are a variant of actor-critic methods that train two distinct models: one for the policy, which chooses the agent's actions and only receives the agent's observations as input, and one for the critic, which receives additional privileged informaton as input. The critic is used to estimate the value of each state, which is then used to update the agent to choose actions that lead it into more valuable states. Vasco et al. @vasco2024superhumanvisionbasedreinforcementlearning show that an asymmetric critic can achieve better-than-human performance using a vision-based RL agent in a simulated autonomous racing environment, and perform better than a baseline symmetric actor-critic agent.

=== Teacher-student distillation

Teacher-student distillation @hinton2015distillingknowledgeneuralnetwork involves training a teacher model with access to privileged information, and then using the teacher's outputs to train a student model that does not have access to this information. The student model is trained to mimic the teacher's behaviour, effectively learning from the teacher's understanding of its privileged knowledge. Xu et al. @xu2026visionbasedpolicylearninghighspeedautonomousracing applied this method to LiDAR-based autonomous racing on the RoboRacer platform, and found that the student model was able to achieve better performance than a baseline model trained without a teacher.


=== Auxiliary learning

Auxiliary learning is a method that falls under the umbrella of multi-task learning, where a model is trained to perform multiple tasks simultaneously. Specifically, in auxiliary learning, the model's performance on the auxiliary task is not an objective in itself, but the model's performance on the auxiliary task is used to improve its performance on the primary task. This occurs because the auxiliary task provides additional information that can be used to improve the model's understanding of the primary task, which can lead to better generalisation and faster learning @ruder2017overviewmultitasklearningdeep.

==== Auxiliary Rewards

When privileged information is available, it can be used to construct auxiliary rewards that guide the agent toward desirable behaviors by evaluating performance against sub-goals. For example, in autonomous racing, privileged knowledge of track layout or opponent positions can generate bonuses for staying centered or avoiding near-misses.

While auxiliary rewards act as a form of reward shaping - supplying denser feedback to accelerate learning - there is a crucial distinction between auxiliary rewards and reward shaping. Traditional potential-based shaping, where the agent is, for example, rewarded for moving towards a target and penalised for moving away from it, guarantees that the underlying task and optimal policy remain unchanged @ng1999policy. Auxiliary rewards, however, act as heuristic bonuses that are rarely potential-based. Consequently, they risk altering the task being solved, which can cause the agent to converge on suboptimal policies for the original objective @ng1999policy.

==== Auxiliary losses

Incorporation of _auxiliary heads_ that predict privileged into a model, and using supervised _auxiliary losses_ to train them, has emerged as a promising technique for improving the performance, interpretability, and training time of end-to-end learning approaches. It does so in three ways: it reduces the variance of the learning signal, it allows privileged information to be used even when it is unavailable at inference time, and it improves representation quality @jaderberg2017unreal @navon2021auxiliarylearningimplicitdifferentiation.

Examples of auxiliary learning with privliged information prediction include Lample et al. @lample2017fps who demonstrated outstanding performance in first-person shooter games by training an agent to predict the presence of enemies in the agent's field of view (FOV). They further found that auxiliary losses performed badly on feedforward models, where classification accuracy was limited, but that they were effective on a recurrent model. Mirowski et al. @mirowski2017learningnavigatecomplexenvironments who found auxiliary tasks for depth prediction and loop closure detection improved navigation in 3D mazes, even compared to agents trained with depth information directly as input.

In the field of autonomous driving, Chitta et al. @chitta2022transfuserimitationtransformerbasedsensor applied auxiliary losses for depth prediction, semantic segmentation, and vehicle detection, achieving state-of-the-art performance on the CARLA benchmark, and significantly decreasing the crash rate. Chen et al. @chen2020interpretableendtoendurbanautonomous use auxiliary losses for birds-eye-view prediction in urban environments, improving both interpretability, and performance.

== Evaluation of existing approaches

End-to-end RL agents on the RoboRacer platform generalise well to unseen tracks but have yet to match classical pipelines, and their opaque representations make failures hard to diagnose. For example, one may not understand whether an agent chose to accelerate into a wall because it misjudged its current velocity, or because it thought the track was straighter than it actually is. In simulation, privileged state such as velocity, tyre slip and upcoming track geometry is available but cannot be used at deployment, when these quantities are unavailable. Existing ways of exploiting priviledged information during training each have a limitation: An asymmetric critic improves value estimation but doesn't directly shape the policy’s own representation; teacher-student distillation is complex since it requires a separate teacher and a two-stage pipeline; and auxiliary rewards alter the optimisation objective and must still pass through the high-variance policy gradient.

Auxiliary losses avoid all three: they leave the RL objective unchanged, supply a lower-variance supervised gradient directly to the shared representation, and are simple to implement. They have improved performance in first-person games, 3D navigation and urban driving. However, to our knowledge, they have not been studied for LiDAR-only racing, nor has it been examined which privileged targets help, or how they change what the policy’s representation encodes. This project addresses that gap.

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
//   hat(Y)_i tilde.dot p(y_i | f_i (x)) = N(y_i; f_i (x); f_i^2)
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

= System overview <sec:system_overview>

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

Despite its higher-accuracy physics, the AutoDrive simulator by default does not provide various features that are important for end-to-end training in our auxiliary learning setup. For example, it is missing track generation & privileged information reporting. Therefore, a custom simulator was implemented in Unity using components from the AutoDrive simulator. Specifically, the `VehicleController` and `IMU` components were not re-implemented, but instead used directly from the AutoDrive simulator. The rest of this chapter describes the custom simulator, including its performance, vehicle model, track generation, and privileged information reporting.

== Simulator performance comparison

In simulation-based training, throughput is critical because agents typically require a very large number of timesteps to learn. There are two kinds of timesteps: at each _control timestep_, the agent receives an observation and outputs an action, and at each _physics timestep_, the physics engine advances the numerical physics integration. The simulation timestep is usually shorter than the control timestep, since the dynamics must be integrated at a finer resolution to remain accurate. Following the settings used by Evans et al. @evans2024unifyingf1tenthautonomousracing, we use a control frequency of 25 Hz and a simulation frequency of 100 Hz.

In order to ensure the custom Unity simulator is suitable for training and not just evaluation, its performance was compared to the F1Tenth gym. A rollout of 10 000 control timesteps (6 minutes and 40 seconds in simulation time) was performed in each environment on an M4 MacBook Air, and the average time per control step was measured. Both environments were run in headless mode to remove any potential overhead from the graphical user interface.

Despite the Unity simulator being significantly more complex than the F1Tenth gym, it runs at a comparable speed, using a comparable amount of CPU resources in this environment, as shown in @sim_benchmarks, with the Unity simulator being only 19% slower compared to the F1Tenth Gym in terms of mean steps per second (sps).

Due to the relatively minor performance difference, and Unity's more realistic 3D physics, the Unity simulator was chosen for training the RL agent, despite the F1tenth gym being more widely used in the literature.

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

The tyre model is built on the idea of _slip_. _Longitudinal slip_, $kappa$, is the ratio between the longitudinal slip velocity and the wheel center velocity. _Lateral slip_, $tan(alpha)$, is the ratio between the lateral slip velocity and the wheel center velocity. A wheel slips when it spins faster than
the wheel center moves (wheelspin), turns slower than the wheel center moves (braking), or is dragged sideways (cornering or drifting). A slip value of $0$ therefore indicates a freely rolling wheel, while a slip value of $> 1$ indicates that the point of contact has a higher velocity than the wheel center.

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
On the real-life RoboRacer, steering actuation cannot occur instantaneously, but is limited by the steering servo's maximum angular velocity. The `WheelCollider` component does not model this limitation, so we use the `VehicleController` from AutoDrive to implement a cap on steering speed of $omega_max = 315 degree \/ sec$. This value was also chosen based on the calibration of the RoboRacer platform by Samak and Samak @samak2024autonomyorienteddigitaltwins.

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

Adding track walls to the generated centerline spline is a non-trivial problem. A naive approach is to scale the centerline's vertices outwards by a fixed multiple, or provide a fixed offset from the center, but this can create undrivably narrow sections, as visualised in @trackgen_inset_outset (a) and (b) respectively. We therefore generate the walls using the Clipper2 library @clipper2, which implements a polygon offsetting algorithm inspired by Vatti @vatti1992. The Clipper2 algorithm is robust to self-intersections, but may produce inset "islands" for large inset distances, or for tracks which are close to self-intersecting, as visualised in @trackgen_inset_outset (c).

Empirically, we find that 1350 of the 100 000 tracks produce these islands (C.I. $(1.28%, 1.42%)$), so we simply discard any tracks with islands and re-generate them.



#figure(
  image("../results/figures/trackgen_inset_outset.pdf", width: 120%),
  caption: "Track insets and outsets using different methods",
) <trackgen_inset_outset>

=== Track Curvature
During training, we wish to observe the effect of using track curvature as an auxiliary loss. To this end, we compute the curvature of the track at 16 equally-spaced points along the track ($d in {0.5, ..., 8} "m"$) ahead of the car's current position. The curvature is computed using the formula $c_d = 1 / r_d$, where $r_d$ is the radius of the osculating circle at that point on the track. The osculating circle was introduced by Leibniz @leibniz1686 as cited by @struik1969[p. 419, n. 6]; it is the circle that best approximates a curve at a given point, and its radius is computed from the first and second derivatives of the track’s parametric equations @stewart2020calculus[p. 910-911]:

$
  1/kappa = r = (x'(t)^2 + y'(t)^2)^(3/2) / abs(x'(t) y''(t) - y'(t) x''(t)) = abs(bold(r)'(t))^3 / abs(bold(r)'(t) times bold(r)''(t))
$

= The Agent <sec:training>

In this chapter, we describe the architecture of the agent and the auxiliary losses used to improve its performance. Because we are comparing the effect of auxiliary losses, we train multiple agents with the same architecture, but with different auxiliary losses enabled each time.

We shall first formalise the problem of autonomous racing as a partially observable Markov decision process (POMDP) in @sec:pomdp, then describe the process of reinforcement learning in @sec:rl, describe the architecture of the agent in @sec:agent, and discuss how the weights of the auxiliary losses are chosen in @sec:finding_optimal_weights. Finally, @sec:metrics describes the metrics used to evaluate the performance of the agent.


== Partially Observable Markov Decision Processes (POMDPs) <sec:pomdp>

In order to formally describe the problem of autonomous racing, we first introduce the framework of partially observable Markov decision processes (POMDPs). POMDPs are a generalisation of Markov decision processes (MDPs) that account for the fact that an agent may not have access to the full state of the environment. In a POMDP, the agent receives observations that provide partial information about the underlying environment state, and must make decisions based on this incomplete information.

A POMDPs is defined by the tuple $(cal(S), cal(O), cal(A), cal(P), rho_0, cal(R), gamma, cal(Z))$, based on the work by Kaelbling et al.
@kaelbling1998:

At each time step $t$, the environment is in state $s_t in cal(S)$, where
$cal(S)$ is the state space. This state is a _complete_ description of the
environment at that time. The first state $s_0$ is sampled from an initial state distribution $rho_0$. The agent does not see $s_t$ directly. Instead, it receives an observation $o_t in cal(O)$, typically its sensor inputs (e.g. LiDAR, camera frames), drawn from the observation function,
$o_t ~ cal(Z)(dot | s_t)$: the observation function is a stochastic mapping from the true state to the observation, deciding what the agent observes given the true state. The information in $s_t$ that is missing from
$o_t$ is called _privileged information_. For example, the car may observe its lidar measurements, but not the road curvature ahead directly, which is privileged information.

Based on its observation, the agent uses its policy $pi$ to choose an action $a_t in cal(A)$, where
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
    step((1, 3), $s_1 ~ P(dot | s_0, a_0)$),
    step((0, 4), $a_1 ~ pi(dot | o_0, o_1)$),
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
receives from time $t$ onward,
$ G_t = sum_(k=0)^(T-t) gamma^k r_(t+k), $
where $T$ is the final time step and $gamma in [0, 1]$ is the discount
factor. A reward received $k$ steps ahead is scaled by $gamma^k$, so later
rewards are worth less than immediate ones: when $gamma$ is close to 1 the
agent is far-sighted, and when $gamma$ is close to 0 it is short-sighted.
Since $G_t$ depends on random states, observations and actions, it is a
random variable, and the agent maximises its expectation, $EE[G_0]$, from the
start of the episode. The policy that achieves this maximum is the _optimal policy_ $pi^*$.


=== Value functions
Value functions measure how good it is for the agent to be in a state, or to take an action in that state.
The state-value function,
$
  V^pi (s) = EE_pi [G_t | S_t = s]
$ <state_value_function>
is the expected discounted return starting in state $s$ and then following policy $pi$ thereafter, and is what the critic estimates in PPO (@sec:ppo). The action-value function,
$
  Q^pi (s, a) = EE_pi [G_t | S_t = s, A_t = a]
$ <action_value_function>
measures the expected discounted return starting in state $s$, taking action $a$, and then following policy $pi$ thereafter. Their difference is the advantage function,
$
  A^pi (s, a) = Q^pi (s, a) - V^pi (s),
$ <advantage_function>
which measures how much better action $a$ is than the policy's average action in state $s$, following policy $pi$.

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
necessary for optimal behaviour in some POMDPs @singh1994learningwithoutstateestimation (although there always exists a deterministic optimal policy in fully-observed MDPs). _Actor-critic_ @sutton2018 methods
combine both: a learned value function (the critic) is used to reduce the variance
of the policy gradient, and since the critic is only used in training, it may take privileged information as input. We focus on policy-based and actor-critic
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
  hat(nabla_theta J)(theta) = 1/(sum_(i=1)^N T_i) sum_(i=1)^N sum_(t=0)^(T_i-1) nabla_theta log pi_theta (a^((i))_t | o^((i))_t) dot G^((i))_t
$
Although REINFORCE is simple to implement, it has several drawbacks, including having high variance in its gradient estimates, which can lead to slow convergence and instability during training @santana2026introductiondeepreinforcementimitation, and, being an on-policy algorithm, it can only learn from trajectories generated by the current policy, which can limit exploration and learning efficiency (since it cannot train multiple epochs on the same rollout).

=== Proximal Policy Optimisation (PPO) <sec:ppo>
PPO is a modern actor-critic algorithm for policy learning introduced in 2017 by researchers at OpenAI @schulman2017ppo. It improves on REINFORCE in two ways. First, being an actor-critic method, it learns a value function $V^pi (s)$, which is used to compute an advantage estimate $hat(A)_t$ and so reduces the variance of the policy gradient estimate, $hat(nabla_theta J)(theta)$. Second, it optimises a _clipped surrogate objective_, $cal(L)_"PPO"$, that limits how far each update can move the policy. This prevents large, destructive steps and makes several epochs of updates on the same rollout possible.

Recall that the advantage function in @advantage_function is the difference between the action-value and state-value functions. It therefore measures how much better (positive) or worse (negative) an action is than the policy's average action in that state. In training, $hat(A)_t = hat(A)^pi (s_t, a_t)$ is estimated from observed rewards and the learned value function, $hat(V)^pi (s)$, for example with Generalised Advantage Estimation @schulman2018highdimensionalcontinuouscontrolusing.
In PPO, the clipped surrogate objective is given by
$
  cal(L)_"actor" = -1/(sum_(i=1)^N T_i) sum_(i=1)^N sum_(t=0)^(T_i-1) min(rho_t (theta) dot hat(A)_t, "clip"(rho_t (theta), 1 - epsilon, 1 + epsilon) dot hat(A)_t)
$

where $rho_t (theta) = (pi_theta (a_t | o_t)) / (pi_theta_"old" (a_t | o_t))$ is the ratio of the new policy's probability of taking action $a_t$ given observation $o_t$ to the old policy's, and $epsilon$ is a hyperparameter that controls how much the policy is allowed to change in a single update. The $"clip"$ function ensures that a policy update that would make $r_t (theta)$ fall outside of the interval $[1 - epsilon, 1 + epsilon]$ is clipped to the nearest endpoint of that interval. This prevents large policy updates that could destabilise training. The $min$ function on the other hand ensures that, while the policy's update is capped when an update makes a good action ($A_t > 0$) more likely, it is not protected from penalties if an update makes a bad action ($A_t < 0$) more likely. These two mechanisms together ensure that the policy is updated in a way that improves performance while avoiding large, destabilising changes that are common in other policy gradient methods @schulman2017ppo.

Since PPO is an actor-critic method, it also learns a value function $V^pi (s)$, which is used to compute an advantage estimate $hat(A)_t$ and so reduces the variance of the policy gradient estimate, $hat(nabla_theta J)(theta)$. The value function is learned by minimising the mean squared error between the predicted value and the observed return. The full PPO loss function is therefore a combination of the clipped surrogate objective and the value function loss, along with an entropy bonus to encourage exploration. The final loss function is given by

$
  cal(L)_"PPO" = cal(L)_"actor" + w_"value" dot cal(L)_"value" - w_"entropy" dot cal(H)[pi_theta]
$

where $cal(L)_"value" = (1/2) (hat(V)^pi (s_t) - R_t)^2$ is the value-head loss function.

== Neural Network Architecture <sec:agent>

The agent is a feedforward actor-critic network implemented in PyTorch @paszke2019pytorch, with the TorchRL library @bou2023torchrldatadrivendecisionmakinglibrary.

It has no recurrent state, so the stack of past scans is its only source of temporal information. It consists of a shared _trunk_ followed by three independent heads, each of which takes as input the same 64-dimensional feature vector output from the trunk, as visualised in @network_architecture:

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
      The agent's neural network. A 50-frame LiDAR stack passes through four 1D convolutions; the flattened output is concatenated with the current steering and throttle and passed through three dense layers and a layer norm to give a 64-dimensional feature vector. This shared feature vector is then passed to three independent heads: the policy head outputs the parameters of the action distribution, the value head outputs the state-value estimate, and the auxiliary head outputs predictions of privileged targets.
    ],
  )
} <network_architecture>


As discussed in @sec:related_literature, Lample et al. @lample2017fps found that auxiliary losses were more effective in a recurrent neural network, compared to a feedforward CNN.
We therefore also implement a recurrent version of the agent, which uses a gated recurrent unit (GRU) @cho2014learningphraserepresentationsusing on the 64-d feature vector output from the trunk, before passing it to the three heads. The RNN network takes a reduced frame stack of 4 frames as input. The GRU allows the model to maintain a hidden memory that it can choose to update at each timestep, which can help it learn temporal dependencies in the data.


=== Action Distributions
The policy head outputs a location $mu$ and a raw scale value $x$ for each of
throttle and steering. Each action is sampled independently from a
tanh-squashed Gaussian,
$ a = tanh(u), quad u tilde cal(N)(5 * tanh(mu / 5), sigma^2), $
so that $a in (-1, 1)$, where 1 corresponds to full throttle or full right steering, and -1 corresponds to full reverse or full left steering.

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

Each frame, the environment emits a set of privileged quantities to the trainer, which are used as _auxiliary targets_. The auxiliary head(s) predict these targets during the training process. The auxiliary targets we consider are listed in @auxiliary_targets. During training, the auxiliary losses are added to the PPO loss so that their gradients are combined and backpropagated through the network graph:

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

The choice of auxiliary loss functions, $cal(L)_"aux"^((k))$, has the potential to significantly impact the agent's performance. Since we are predicting continuous quantities, it is natural to use a regression loss function such as Squared Error (SE), Absolute Error (AE), or Huber loss @huber1964robust, defined respectively as

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

The Huber loss's bounded gradient is particularly useful when the target values have a heavy-tailed, non-normal distribution, since the loss is then far less sensitive to extreme values than the SE loss @terven2025lossfunctionsmetricsdeep.



For this reason, we use the Huber loss for all auxiliary targets. With $beta = 1$, since the targets are normalised to zero mean and unit variance (@auxiliary_targets), this makes the loss quadratic for errors within one standard deviation of the mean - where most#footnote([Proportions of the data within 1 standard deviation of the mean are listed in @sec:prop_data_within_sd]) of the fitting takes place - and linear, with a gradient of magnitude $1$, beyond it, so that the extreme target values cannot dominate the gradient.

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

So-called "smart" hyperparameter tuning methods, such as Bayesian optimisation @snoek2012practical and the tree-structured Parzen estimator (TPE) @bergstra2011algorithms, build a model of the relationship between the weights and the agent's performance. This model is then used to guide the search for optimal weights, allowing for more efficient exploration of the search space. These methods can be more effective than grid or random search, but they can also be more complex to implement and still require multiple training runs. Methods such as Hyperband @li2018hyperband and its asynchronous variant ASHA @li2020asha mitigate this cost by giving each trial a small budget and only continuing the best-performing ones. However, such early-stopping methods may prematurely terminate RL trials that perform more exploration early on, despite performing better in the long run, so they are not ideal for our scenario.

=== Adaptive Weighting
Adaptive weighting is an alternative approach that dynamically adjusts the weights of the auxiliary losses during training based on factors like the magnitude of the gradients or the error of the auxiliary predictions. Various methods have been introduced in the literature, such as GradNorm @chen2017gradnorm, which weights tasks that are learning slower more heavily, and Uncertainty Weighting @kendall2018multitask-cvpr, which uses the model's uncertainty in each task to determine the weights. These methods are useful in multi-task learning scenarios, where the performance of all tasks is important, but they are not ideal for our scenario, where the main task (driving) is the only one that matters. In this case, we want to combine auxiliary losses in such a way that improves the main task's performance, not to balance the performance of all tasks.

=== PCGrad <sec:pcgrad>

PCGrad @yu2020gradientsurgerymultitasklearning is a method that modifies the gradients of auxiliary tasks to prevent them from conflicting with the main task's gradients. It does so by projecting the auxiliary task gradients onto the normal plane of the main task's gradient if they conflict. Let $bold(g)_"aux"^((k))$ be the gradient of the model parameters for the $k$-th auxiliary loss and $bold(g)_"PPO"$ be the gradient of the main task loss. If the dot product $bold(g)_"aux"^((k)) dot bold(g)_"main" < 0$, then the auxiliary gradient is projected onto the normal plane of the main task gradient:

$
  bold(g) = bold(g)_"PPO" + sum_(k=1)^K cases(
    bold(g)_"aux"^((k)) - frac(bold(g)_"aux"^((k)) dot bold(g)_"PPO", ||bold(g)_"PPO"||^2) bold(g)_"PPO" "if" bold(g)_"aux"^((k)) dot bold(g)_"PPO" < 0,
    bold(g)_"aux"^((k)) "otherwise"
  )
$

The result is that the auxiliary gradients are modified to avoid conflicting with the main task, as visualised in @pcgrad_diagram.

// --- small vector helpers ---
#let vdot(a, b) = a.at(0) * b.at(0) + a.at(1) * b.at(1)
#let vadd(a, b) = (a.at(0) + b.at(0), a.at(1) + b.at(1))
#let vsub(a, b) = (a.at(0) - b.at(0), a.at(1) - b.at(1))
#let vscale(a, s) = (a.at(0) * s, a.at(1) * s)
#let vunit(a) = vscale(a, 1 / calc.sqrt(vdot(a, a)))

#figure(
  canvas(length: 1cm, {
    import draw: *

    // ===== PARAMETERS: arrow heads relative to each graph's centre =====
    let g-ppo = (-4, 0) // main task gradient (shared by both panels)
    let g-aux-a = (-2.1, 1.8) // panel (a): aux gradient, no conflict (dot > 0)
    let g-aux-b = (2.3, 1.8) // panel (b): aux gradient, conflict (dot < 0)
    let centre-a = (4, 0) // tail of the arrows in panel (a)
    let centre-b = (11, 0) // tail of the arrows in panel (b)
    // ====================================================================

    let red = rgb("#ee3322")
    let blue = rgb("#0000ee")
    let w = 1.6pt

    // arrow from c to c + v, with a label just past its head
    let arrow(c, v, body, col, dash: none) = {
      let head = vadd(c, v)
      line(c, head, stroke: (paint: col, thickness: w, dash: dash), mark: (end: ">"))
      content(vadd(head, vscale(vunit(v), 0.5)), text(fill: col, body))
    }

    // one panel: PCGrad applied to g-aux at centre c
    let panel(c, g-aux, tag) = {
      let conflict = vdot(g-aux, g-ppo) < 0
      let coef = vdot(g-aux, g-ppo) / vdot(g-ppo, g-ppo)
      let g-par = vscale(g-ppo, coef) // component along g-ppo
      let g-proj = vsub(g-aux, g-par) // normal to g-ppo

      arrow(c, g-ppo, $bold(g)_"PPO"$, red)

      if conflict {
        // original aux gradient, faded
        line(
          c,
          vadd(c, g-aux),
          stroke: (paint: blue.lighten(60%), thickness: w),
          mark: (end: ">"),
        )
        // removed component, dotted
        let foot = vadd(c, g-par)
        line(c, foot, stroke: (paint: gray, thickness: 1.2pt, dash: "dotted"), mark: (end: ">"))
        // projected gradient, dashed
        arrow(c, g-proj, $bold(g)_"aux"^((k)) '$, blue, dash: "dashed")
        content(
          (c.at(0) + g-ppo.at(0) / 2, -1.4),
          [*(#tag)* Conflict: $bold(g)_"aux"^((k)) dot bold(g)_"PPO" < 0$, projected],
        )
      } else {
        arrow(c, g-aux, $bold(g)_"aux"^((k))$, blue)
        content(
          (c.at(0) + g-ppo.at(0) / 2, -1.4),
          [*(#tag)* No conflict: $bold(g)_"aux"^((k)) dot bold(g)_"PPO" >= 0$],
        )
      }
    }

    panel(centre-a, g-aux-a, "a")
    panel(centre-b, g-aux-b, "b")
  }),
  caption: [PCGrad. *(a)* If $bold(g)_"aux"^((k))$ does not conflict with $bold(g)_"PPO"$ it is left unchanged. *(b)* If it conflicts, the component along $bold(g)_"PPO"$, is removed, leaving the gradient orthogonal to $bold(g)_"PPO"$, $bold(g)_"aux"^((k))$],
) <pcgrad_diagram>


=== Weighting Scheme Used in This Project <sec:weighting_scheme>

Our aim is to understand the effect of each kind of privileged information on the agent, not to find the best possible weights. Searching over a separate weight for each of the 16 curvature, 3 velocity and 8 slip targets would be intractable (@sec:finding_optimal_weights), and adaptive methods are designed to balance tasks rather than to help a single primary task. We therefore use fixed weights and a _leave-one-in_ design.

The targets are partitioned into $C = 10$ categories (@aux_categories), each with one scalar weight $w_c$. The auxiliary loss of a category is the sum of the Huber losses of its targets,
$
  cal(L)_c = sum_(k in c) cal(L)_"Huber"^((k)),
  quad
  cal(L)_"total" = cal(L)_"PPO" + sum_(c=1)^C w_c cal(L)_c .
$
In a leave-one-in experiment, a single category $c^*$ is enabled with $w_(c^*) in {0.1, 0.3, 1.0}$ and every other weight is zero, giving 30 configurations, each compared against the baseline ($w_c = 0$ for all $c$). The "All" configuration enables every category at the same $w$. All weights are constant throughout training, and since the targets are normalised to zero mean and unit variance, the per-target losses are of comparable magnitude. The limitation is that this approach does not explore interactions _between_ categories.

We also consider the performance of the PCGrad method (@sec:pcgrad) in order to evaluate whether we can achieve better performance without having to tune weights. In this case, all losses are enabled, and the weight for the auxiliary loss is set to $w in {0.03, 0.1, 0.3, 1.0}$.

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

  caption: [The auxiliary targets are grouped into categories, each of which is weighted by a single hyperparameter. The performance of the agent is evaluated for configurations with
  ],
) <aux_categories>

== Metrics <sec:metrics>
=== Progress <sec:progress>
Let $L$ be the total length of the track centreline. At any time $t$, let $d_t in [0, L)$ be the agent's current arc length from the start of the centerline to the point closest to the agent, and let $N_t$ be the total number of completed laps. We define the agent's _absolute progress_ along the track as the total continuous distance travelled from the start:

$ xi_t = d_t + N_t L $

The _progress per step_ is then simply the change in this absolute position between consecutive timesteps, defined as $xi_t - xi_(t-1)$. Because $xi_t$ tracks the cumulative distance across multiple laps, this raw difference naturally handles crossing the finish line without requiring any wrapping operations or modulo arithmetic.

Using this step-wise progress as a reward signal is approximately equivalent to a potential-based reward shaping function @ng1999policy. In this context, the absolute progress $xi_t$ serves as the potential function $Phi(s_t)$ of the current state. Because the reward is defined as (nearly) the difference in potential, $Phi(s_t) - gamma Phi(s_(t-1))$, it heavily incentivises continuous forward movement along the track while theoretically being close to preserving the optimal policy and preventing the agent from exploiting positive-reward cycles.

=== Crash rates
The _crash rate per episode_ is the fraction of total episodes that terminate in a collision rather than reaching the maximum length (45 simulated seconds).

The _crash rate per timestep_ is the total number of collisions divided by the total number of timesteps executed across all episodes. This can be interpreted as an estimate of the  probability of a collision occurring at any given timestep, and is useful for evaluating the agent's safety in a time-normalised manner.

The _collisions per metre of progress along the centerline_ is the total number of crashes divided by the total distance the agent successfully advances along the track centerline. This metric normalizes failures against progression rather than time, providing a balanced measure of the agent's driving competence.

=== Reward function <sec:reward_function>
The agent receives a dense reward at each timestep that encourages fast, collision-free progress along the centerline:

$ r_t = w_p dot (xi_t - xi_(t-1)) - w_c dot c_t $

The first term rewards forward progress, using the progress per step defined in @sec:progress. The second term penalizes collisions: the indicator variable $c_t$ equals 1 if a collision occurs with an obstacle at time $t$, and 0 otherwise.

The weights $w_p$ (reward per metre of progress) and $w_c$ (penalty per collision) balance speed against safety based on the risk tolerance of the application. We set $w_p = 1.0$ and $w_c = 1.0$. Because an episode terminates immediately upon collision, there is already a strong implicit penalty for crashing, allowing $w_c$ to remain relatively low.

=== Area Under the Curve (AUC)
The _area under the curve_ (AUC) evaluates sample efficiency and learning stability by calculating the definite integral of a performance metric $y(t)$ (e.g., return or progress per step) over the total training time or timesteps $T$:

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

= Experiments & results <sec:results>

Each configuration of (auxiliary targets, auxiliary loss weights), as well as the baseline model, was trained for 600 PPO iterations with 256 frames per iteration on each of 48 concurrent environments, for a total of 7.3 million timesteps ($approx 82 "hours"$ of sim-time). Each configuration was trained on 6 different seeds, and various statistics were recorded for each iteration of each run of each configuration.

== Baseline Model Performance

The baseline feedforward model trained with the PPO loss and no auxiliary targets performed well in the primary task across $N=6$ runs. It achieved a mean crash rate per meter of progress (CRPMP) of $0.0034 plus.minus 0.0028 "crashes/m"$, indicating approximately one crash every 297 meters. It achieved a mean metres of progress per second along the centerline (MPPSC) of $4.13 plus.minus 0.49 "m/s" approx 15 "km/h"$.

The recurrent model performed significantly worse, with a mean crashes per meter of progress of $0.0381 plus.minus 0.0499 "crashes/m"$, almost 10x higher than the feedforward model. It achieved a mean MPPSC of $2.00 plus.minus 0.692739 "m/s" approx 7.2 "km/h"$, approximately half the speed of the feedforward model.

Before we consider the effect of auxiliary losses, we first establish what the baseline models' internal representations encode in @sec:baseline_model_features.

== Learned features of Baseline Model <sec:baseline_model_features>

Consider the network in @network_architecture. Once trained, each layer $l$
maps an input $bold(x)$ to an intermediate representation
$bold(h)^((l)) = f_l (bold(x); theta)$, which becomes the input to the following layer. We would like to know what
information these intermediate representations encode, and in particular whether they encode
privileged state variables (e.g. velocity, slip, upcoming curvature).

Alain and Bengio @alain2018understandingintermediatelayersusing introduced
_linear probes_ for this purpose; the trunk network's weights are frozen, and a
separate linear classifier (the probe) is trained in a supervised manner on the representations,
$bold(h)^((l))$, of each layer to predict the desired target. Since the
probe cannot change the representation, its test accuracy measures how much
class information is _linearly_ available at that layer. Anand et al.
@anand2020unsupervisedstaterepresentationlearning extended this idea to
reinforcement learning, probing an encoder's representations for ground-truth
state variables of Atari games.

The choice of a _linear_ probe is deliberate; a sufficiently expressive probe may compute the target from almost any input, including the
raw network input (LiDAR in our case), so high probe accuracy would say more about the probe than
about the representation @belinkov2021probingclassifierspromisesshortcomings.
Restricting the probe to a linear map means that it can only succeed if the
network has already done the work of encoding the target along some direction in the representation space.

Many of the privileged variables of interest are continuous rather than
categorical, so we use a linear _regression_ probe instead of a classifier, as
done by McGrath et al. @mcgrath2022alphazero to probe AlphaZero for chess
concepts and by Gurnee and Tegmark @gurnee2024languagemodelsrepresentspace to probe language
models for spatial and temporal encodings.

To establish what the baseline represents without auxiliary supervision, linear probes were fit to the output of the final trunk layer to predict each auxiliary target at various points during the model's training. Each probe is an OLS regression model trained on intermediate representations from a \~35-minute rollout  (52429 timesteps) and evaluated on a separate \~9-minute rollout (13107 timesteps). @baseline_lr_model_dumbell reports out-of-sample $R^2$ at initialisation and after 600 PPO iterations.

#figure(
  image("../results/figures/probe_dumbbell.pdf", height: 150pt),
  caption: [Out-of-sample $R^2$ scores of linear regression probing of the final layer of the trunk on the baseline model. Error bars show the standard error of the mean (SEM) across $N = 6$ different seeds],
) <baseline_lr_model_dumbell>

Three distinct patterns emerge. First, quantities describing the vehicle's instantaneous dynamics are already linearly decodable at initialisation: forward velocity has $overline(R)^2 = 0.509$, lateral velocity $0.885$, and angular velocity $0.913$. Since the trunk network is untrained and LeCun-initialised @lecun1998efficientbackprop, this reflects information that is close to linear in the observation and survives a series of random projections, rather than a learned representation; a similar effect was observed by @alain2018understandingintermediatelayersusing when investigating intermediate layers in MNIST models. After training, the decodability of forward velocity remained essentially unchanged ($0.503$), while the decodability of lateral and angular velocity decreased to $0.783$ and $0.783$, respectively. Thus the trunk network does not learn to represent these instantaneous-dynamics quantities in a more linearly decodable way. This is likely because the agent can achieve high performance without explicitly representing them, so trunk capacity is better used for other information.

Second, track curvature is initially decodable only for near horizons: $R^2 = 0.264$ at 0.5 m, $0.181$ at 1.0 m, $0.014$ at 1.5 m, and negative at 2.0 m and beyond. After training, decodability improved at every listed horizon ($Delta R^2 > 0$ from 0.5 m through 8.0 m), although absolute decodability remains moderate only near the vehicle and low for medium- and far-ahead distances.

Third, wheel slip shows distinct patterns for forward and lateral components. Forward wheel slip is initially only weakly decodable for all wheels: back-left $0.081$, back-right $0.148$, front-left $0.082$, and front-right $0.132$. After training these increase to $0.272$, $0.241$, $0.276$, and $0.239$, respectively. Lateral wheel slip is already highly decodable at initialisation: back-left $0.666$, back-right $0.676$, front-left $0.813$, and front-right $0.832$. After training, rear lateral wheel slip decreases to $0.488$ and $0.510$, while front lateral wheel slip remains high at $0.781$ and $0.809$.

This expirement shows that, although the baseline model represents some privileged quantities well initially, it does learn to represent others, such as track curvature through training. We hypothesise that forcing earlier learning of these quantities through auxiliary losses may improve the agent's performance, and we investiage this in @sec:agent_performance_after_auxiliary_learning and @sec:learned_features_after_auxiliary_learning.


== Agent Performance After Auxiliary Learning <sec:agent_performance_after_auxiliary_learning>

The models are now trained with the same reward function as the baseline model (@sec:reward_function), but with the addition of one or more auxiliary heads (and their associated auxiliary losses).

The auxiliary head (and loss) that was most effective in improving the agent's performance was the close-ahead curvature head. It resulted in a measurably higher reward AUC compared to the baseline model, as visualised in @fig:auc_comparison. Note that because the agent restarts after a collision, the reward AUC is only slightly influenced by the crash penalty. It is therefore important to monitor the performance of the agent in terms of each metric individually, as visualised in @fig:last_50_means_heatmap, where the metrics (y-axis) are averaged over the last 50 training iterations and compared to the baseline model's mean. We find that the model trained with a loss for close-ahead curvature achieves both higher racing performance, as well as safety: it achieves a +13% mean metres of progress per timestep (MPPT) along with a -38% collision rate per metre of progress at an auxiliary loss weight of $omega_"aux" = 1.0$. Similar, though less pronounced results are achieved by the front wheel forward slip head, which is, in fact, safer (-59% collisions per metre of progress) than the baseline, and drives faster (+7% mean MPPT). Training the model with all auxiliary heads enabled, and with a small auxiliary loss weight of $omega_"aux" = 0.1$, results in improved safety (-51% collisions per metre of progress) but showed no significant change in racing speed.


#figure(
  image("../results/figures/auc_comparison.pdf"),
  caption: [Reward AUC of the models trained with different auxiliary losses and loss weights over their 600 training iterations, compared to the baseline model (red). The standard deviation bars indicate the standard deviation of the _mean_ AUC across 6 different seeds.],
) <fig:auc_comparison>

#figure(
  image("../results/figures/last_50_means_heatmap.pdf"),
  caption: [Mean of the last 50 training iterations of each model's metrics (mean reward, mean progress per timestep, mean forward velocity, mean number of collisions per metre of progress, mean number of collisions per episode, and mean number of collisions per timestep) vs the baseline model. Bold = statistically significant ($alpha = 10%$), using a two-sided t-test for the null hypothesis that the means are equal.],
) <fig:last_50_means_heatmap>

@fig:progress_vs_collision places each model in a 2D space of the mean progress per second vs the mean number of collisions per metre of progress. It is clear that the close-ahead curvature auxiliary loss is the most effective in improving both speed and safety, while the rear-wheel slip improves safety but has mixed results in terms of speed. Importantly, @fig:last_50_means_heatmap and @fig:progress_vs_collision both indicate that the majority of auxiliary losses _do not_ improve the agent's performance, and in most cases, degrade it.

#figure(
  image("../results/figures/progress_vs_collision.pdf"),
  caption: [Comparison of different models' mean progress per second vs collisions per metre of progress. Bottom right quadrant = faster and safer than the baseline. Bottom left quadrant = slower but safer than the baseline.],
) <fig:progress_vs_collision>

== Learned Features After Auxiliary Learning <sec:learned_features_after_auxiliary_learning>

Applying the same probing technique after auxiliary training, we find that decodability of the privileged quantities improved significantly in many configurations, though not always with a corresponding performance gain. The full results are visualised in @aux_head_regression_results, since they are too numerous to include in the main text.

The close-ahead ($<= 3m$) track curvature auxiliary loss was extremely effective in improving the decodability of the trunk's final layer. It improved the out-of-sample $R^2$ scores in close-ahead curvature quantities by between +16 to +58 percentage points, depending on the weight, and even improved the decodability of quantities that were not directly supervised, such as 3.5-m-ahead curvature (up to +27 percentage points). The medum-ahead ($3m < x <= 6m$) curvature auxiliary loss also improved the decodability of the trunk's final layer, but to a lesser extent.

When losses were introduced for the for wheel slip quantities, the decodability of the corresponding quantities improved significantly for smaller loss weigths ($w_"aux" in {0.1, 0.3}$). Interestingly, when forward wheel slip was supervised for the front wheels, the decodability of the back wheel slip also increased. We hypothesis that this is because the car is driven with an all-wheel-drive configuration, so the front and back wheels are coupled, but this was not tested.

Lateral slip supervision had mixed effects, with the decodability of the corresponding quantities improving significantly only for a larger loss weight ($w_"aux" = 1$), and also resulted in no improvement in the agent's performance.

When all auxiliary losses were enabled, the decodability of almost all quantities improved significantly, but the agent's performance only improved in terms of safety with a low auxiliary loss weight ($w_"aux" = 0.1$). This suggests that the auxiliary losses may be competing for the model's capacity when they are all enabled.

== Qualitative Analysis of Driving Styles

= Conclusions and recommendations <sec:conclusion>

== Summary
This project set out to determine whether auxiliary losses that predict privileged information improve the performance, training speed, and internal representations of a LiDAR-only end-to-end racing agent. All five objectives listed in @sec:problem_statement_and_objectives were met; a custom unity simulator was developed, a baseline PPO agent was trained (@sec:agent), linear regression probes established what the agent natively encodes (@baseline_lr_model_dumbell). Then, auxiliary heads were added to predict privileged state information during training (@sec:training), and the resulting agents were evaluated against the baseline model in terms of racing speed and safety, while also probing the internal representations of the trained agents (@sec:learned_features_after_auxiliary_learning). The results show that auxiliary losses can improve both the agent's performance and its internal representations, but that this is not "free lunch": only certain auxiliary losses improve performance, and only at certain loss weights.

The baseline model already encoded its instantaneous dynamics well at initialisation. In contrast, the decodability of close-ahead and medium-ahead track curvature improved significantly during training with auxiliary heads, and the former had an impressive effect on the agent's driving capability, making it both safer and faster. Far-ahead curvature was not learned well by the model, and did not improve the agent's performance when supervised.

== Future work

The results of this project suggest that more work is needed to determine _a priori_ which auxiliary losses will improve the agent's performance, and at what loss weights, but that auxiliary losses can indeed improve both the agent's performance and its internal representations. Future work could explore the following avenues:
- Investigate the effect of auxiliary losses on the agent's performance in more complex environments, such as those with dynamic obstacles or varying track conditions.
- Explore the use of adaptive weighting methods for auxiliary losses, to dynamically adjust the weights during training based on the agent's performance and the difficulty of the auxiliary tasks.
- Investigate the effect of auxiliary losses on the agent's performance in multi-agent scenarios, where multiple agents are racing against each other


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
                intervals: ((start: "2026-06-05", end: "2026-07-17"),),
              ),
              (
                name: [Auxiliary learning and privileged information],
                intervals: ((start: "2026-06-22", end: "2026-07-31"),),
              ),
              (
                name: [Autonomous racing and RoboRacer],
                intervals: ((start: "2026-07-06", end: "2026-08-14"),),
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

The project addresses a complex engineering problem because it requires a fundementals-based formulation of autonomous racing as a POMDP and first-principles-based design of vehicle dynamic models. It draws on specialist knowledge of RL and autonomous racing, and engages with current research literature on privileged information, auxiliary learning, and representation probing. The problem has no obvious solution: a LiDAR-only agent must learn quantities it cannot observe, and it is not clear which privileged targets or loss weights would help. It involves conflicting requriements (speed vs. safety), balancing the loss weights of the primary task vs. auxiliary tasks, and considering the trade-offs between simulation fidelity and training speed. It also involves many coupled systems



#pagebreak()

== AI Declaration

- #link("http://claude.ai")[Claude] was used for searching literature, checking the report for errors, advice on clarity of writing, and changing the format of references from BibTex to Hayagriva. Furthermore, Claude was used to explain various tensor shape bugs in PyTorch code, but the final implementation was always done manually, as well as to explain how TorchRL works. Initially, Claude was used to generate diagrams, but I did not like how little control I had over the diagrams, so re-implemented them manually from scratch. Claude was used to generate parts of @fig:walk-step based on a handmade diagram. Claude was used to explain to me why certain training setups may perform badly on the hardware available. Claude was used to explain how to perform the FDR analysis on @aux_head_regression_results, but the code was written by me, and I understand the process.

- #link("https://gemini.google.com")[Google Gemini] was used to a lesser extent for searching literature, and, before starting the project, for assistance in understanding RL in conjunction with the #link("https://www.youtube.com/watch?v=2pWv7GOvuf0")[David Silver videos]. Gemini was instrumental in explaining potential-based reward shaping in an easy-to-understand way. Gemini was used to do spelling & grammar checking.

- #link("https://scholar.google.co.za/scholar_labs/search")[Google Scholar Labs] was used extensively in searching for literature.
- #link("http://chat.deepseek.com")[DeepSeek] was used to search for literature, and to provide input on the structure and content of the report. For example, it advised which sections could be reduced in length without sacrificing report quality.

AI was not used to generate the training code or the model definition code - that was hand-written.

== WheelCollider properties <wheel_collider_properties>

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
)

#pagebreak()
== Distribution of Auxiliary Targets <sec:prop_data_within_sd>

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
