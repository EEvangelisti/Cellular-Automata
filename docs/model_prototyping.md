# Model prototyping

**Automates** is not only a viewer for classical cellular automata. It is also 
a lightweight platform for prototyping spatial rule-based models on 
two-dimensional grids.

The central idea is simple: a model can be described as a set of local entities, 
local states, and local update rules. Once these rules are implemented in a 
plugin, Automates provides the graphical interface, rendering system, execution 
loop, import/export functions, and parameter handling.

This makes the software useful as a practical sandbox for exploring how simple 
rules can generate complex spatial dynamics.

---

## Examples

[Zoospore motility prototype](zoospore_model.md)
[Hyphal growth prototype](hyphal_growth_model.md)

---

## From automata to model prototypes

Classical cellular automata are based on a regular grid whose cells evolve 
according to local neighborhood rules. This formalism is powerful, but it can 
also be extended toward more flexible rule-based models.

In Automates, a plugin is free to implement its own logic. 
A model may therefore include:

- classical cell states;
- spatial gradients;
- obstacles or environmental constraints;
- active fronts;
- agent-like entities;
- auxiliary data structures;
- stochastic decisions;
- import and export of model-specific observables.

The grid remains the spatial support, but the biological or physical entities 
represented by the model do not have to be limited to passive cell states.

---

## Agent-based extensions

Some models require entities that carry more information than a simple integer 
state. For example, a motile cell, a growing tip, or a propagating front may 
require additional properties such as:

- position;
- direction or polarity;
- age;
- speed;
- activity status;
- interaction state;
- memory of previous decisions;
- competence to branch, divide, stop, or differentiate.

These entities can be represented either directly in the grid or in auxiliary 
structures maintained by the plugin. The graphical matrix then provides a 
visible projection of the model state, while the plugin controls the underlying 
dynamics.

This approach makes Automates suitable for simple agent-based models coupled to 
a discrete spatial environment.

---

## Biological model prototyping

Automates was designed as a general exploratory framework, but it is 
particularly useful for prototyping biological systems in which local decisions 
generate large-scale spatial organization.

Possible examples include:

- hyphal growth;
- branching networks;
- zoospore movement;
- encystment and germination;
- front propagation;
- local exclusion or competition;
- colonization of a structured tissue;
- interaction between motile cells and a spatial environment.

In such models, the goal is not to reproduce every physical detail of the 
biological system. Instead, the goal is to formalize hypotheses and ask whether 
a given set of local rules is sufficient to generate plausible global behavior.

For example, active hyphal tips can be represented as agent-like entities 
carrying polarity, age, and branching competence. Zoospores can be represented 
as motile agents whose effective trajectories emerge from internal update cycles 
and local stochastic decisions.

---

## Internal cycles and observation scale

A useful distinction can be made between internal model cycles and observable 
time steps.

An internal cycle corresponds to one elementary update of the model. An 
observable frame may correspond to several internal cycles. This allows local 
stochastic movements to integrate into effective displacements at the scale at 
which trajectories are measured or visualized.

For instance, one recorded frame may correspond to six internal model cycles. 
This does not change the model logic; it simply defines the temporal scale at 
which the simulation is observed.

This distinction is especially useful when comparing simulated trajectories 
with experimental tracking data.

---

## What model prototypes can and cannot do

Model prototypes are useful for:

- testing conceptual assumptions;
- comparing alternative local rules;
- identifying emergent spatial patterns;
- detecting unexpected consequences of simple mechanisms;
- generating qualitative predictions;
- defining which observables should be measured experimentally.

They should not be mistaken for fully calibrated simulators unless their 
parameters have been fitted and validated against experimental data.

A prototype can therefore be scientifically useful even before quantitative 
calibration. It provides a formal and visual way to make assumptions explicit.

---

## Validation and observables

When a model is intended to mimic an experimental system, visual similarity is 
only a first step. More robust comparisons should rely on explicit observables.

For motile agents, useful observables include:

- mean speed;
- net displacement;
- trajectory length;
- tortuosity;
- directional persistence;
- angle distributions;
- mean squared displacement;
- frequency of state transitions.

For growing structures, useful observables include:

- total occupied area;
- growth rate;
- branch density;
- tip number;
- network connectivity;
- collision frequency;
- spatial anisotropy;
- colonization efficiency.

Automates plugins can be extended to export such measurements, making it 
possible to compare model outputs with experimental datasets.

---

## Why use Automates for prototyping?

Automates provides a convenient compromise between simplicity and flexibility.

It is simple enough to implement small models rapidly, but flexible enough to 
explore systems that go beyond textbook cellular automata. The plugin 
architecture makes it possible to develop, test, and compare different models 
without modifying the core application.

This makes Automates useful for:

- exploratory modelling;
- teaching spatial rules and emergent behavior;
- testing biological hypotheses;
- developing proof-of-concept simulations;
- preparing more formal models;
- designing observables for experimental comparison.

In this sense, Automates should be viewed as a platform for spatial model 
prototyping rather than as a single-purpose cellular automaton program.

---

## Relation to cellular automata

Model prototyping in Automates builds on the logic of cellular automata but 
relaxes some of their constraints.

A model may still be a classical cellular automaton. However, it may also 
include richer update logic, agent-like entities, stochastic events, memory, or 
model-specific export functions.

The common principle remains the same: complex spatial dynamics are explored 
through explicit local rules.
