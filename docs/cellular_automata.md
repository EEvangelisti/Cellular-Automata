# Cellular automata

This document presents the main cellular automata families available in **Automates**.

Automates was originally designed as a lightweight platform for exploring two-dimensional cellular automata. It provides a common graphical interface, rendering system, execution loop, and plugin architecture, while each automaton family defines its own local rules.

The goal is not to provide an exhaustive mathematical reference, but to describe the kinds of spatial dynamics that can be explored with the current plugins.

![Automates overview](images/automates_overview.png)

---

## General principle

A cellular automaton is a discrete model in which space is represented as a regular grid of cells.

Each cell has a state. At each generation, the state of every cell is updated according to local rules, usually based on the states of neighboring cells.

Despite their simplicity, cellular automata can generate rich spatial dynamics, including:

- stable structures;
- oscillations;
- waves;
- expanding fronts;
- labyrinths;
- self-organized patterns;
- growth-like structures;
- cyclic dominance patterns.

In Automates, these systems are implemented as plugins. This makes it possible to compare different families of automata within the same interface.

---

## Available automaton families

Automates currently includes several broad families of cellular automata:

| Family | General idea | Typical dynamics |
|---|---|---|
| Life-like automata | Binary or quasi-binary automata based on birth and survival rules | still lifes, oscillators, expanding structures |
| Generations automata | Life-like automata with transient intermediate states | waves, trails, refractory patterns |
| Cyclic automata | Cells advance through cyclic states when enough neighboring cells are ahead | rotating waves, spirals, cyclic domains |
| Weighted Life automata | Life-like rules with weighted neighborhoods | anisotropic patterns, directional growth, structured textures |
| Larger than Life automata | Life-like rules using larger neighborhoods and rule intervals | large-scale fronts, smooth growth, maze-like systems |

These families share the same spatial framework but differ in how local neighborhoods are interpreted.

---

## Life-like automata

Life-like automata are inspired by Conway’s Game of Life and related birth/survival systems.

Each cell is usually interpreted as either dead or alive. A dead cell may become alive depending on the number of living neighbors. A living cell may survive or disappear depending on the same local neighborhood count.

These automata are useful for exploring how simple local thresholds can generate complex spatial structures.

Typical behaviors include:

- isolated stable forms;
- oscillating motifs;
- expanding colonies;
- chaotic transients;
- sparse self-organization.

In Automates, Life-like rules provide the most direct entry point into classical cellular automata.

---

## Generations automata

Generations automata extend Life-like systems by adding intermediate states.

Instead of switching directly from alive to dead, a cell can pass through several fading or refractory states before becoming inactive again. This makes it possible to represent memory-like effects, trails, or delayed disappearance.

This family is particularly useful for producing wave-like structures and excitable media.

Typical behaviors include:

- traveling waves;
- decaying trails;
- pulse propagation;
- refractory zones;
- expanding and collapsing patterns.

Generations automata are a natural bridge between classical Life-like systems and more biologically inspired spatial models.

---

## Cyclic automata

Cyclic automata use a set of ordered states arranged in a cycle.

A cell can advance to the next state when enough neighboring cells are already in that next state. This creates local propagation between states, often producing rotating or chasing dynamics.

These automata are useful for exploring spatial competition and cyclic dominance.

Typical behaviors include:

- spirals;
- rotating waves;
- cyclic domains;
- wavefront interactions;
- self-sustained spatial oscillations.

Cyclic automata are visually rich and often produce patterns reminiscent of reaction-diffusion systems, although their rules remain purely discrete.

---

## Weighted Life automata

Weighted Life automata generalize Life-like rules by giving different weights to different positions in the neighborhood.

Instead of simply counting how many neighboring cells are active, the automaton computes a weighted local score. This makes it possible to favor some directions or positions over others.

This family is useful for exploring how local asymmetry affects global pattern formation.

Typical behaviors include:

- directional expansion;
- anisotropic growth;
- structured textures;
- biased propagation;
- altered Life-like dynamics.

Weighted rules make it possible to investigate how changing the geometry of local interactions modifies the resulting spatial organization.

---

## Larger than Life automata

Larger than Life automata extend Life-like systems by using neighborhoods larger than the immediate surrounding cells.

Instead of considering only the eight adjacent cells, these automata count active cells within a broader radius. Birth and survival are then controlled by intervals rather than by single neighbor counts.

This produces smoother, larger-scale dynamics than standard Life-like automata.

Typical behaviors include:

- broad expanding fronts;
- maze-like structures;
- smooth colonies;
- large-scale spatial domains;
- complex growth boundaries.

Larger than Life automata are useful when one wants to study local rules acting at a broader spatial scale.

---

## Neighborhoods and spatial scale

The behavior of a cellular automaton depends strongly on how neighborhoods are defined.

A small neighborhood emphasizes local, pixel-scale interactions. A larger neighborhood allows broader spatial averaging and can generate smoother patterns.

Automates includes automata based on:

- immediate neighborhoods;
- extended neighborhoods;
- weighted neighborhoods;
- cyclic state comparisons;
- rule intervals.

This makes it possible to explore how the spatial scale of local interactions affects global pattern formation.

---

## States and memory

Some automata use only two main states: inactive and active.

Others include several states, which may represent:

- fading activity;
- refractory periods;
- cyclic progression;
- age;
- local memory;
- transient occupation.

Adding states changes the behavior profoundly. It allows patterns to carry a history of previous activity, which can generate trails, waves, delayed responses, or structured propagation.

This is one reason why simple rule-based systems can produce surprisingly rich dynamics.

---

## Why cellular automata are useful

Cellular automata are useful because they make local assumptions explicit.

They provide a compact way to ask questions such as:

- What happens if cells respond only to their immediate neighbors?
- Which local rules generate stable structures?
- Which rules generate waves or expanding fronts?
- How does neighborhood size affect pattern formation?
- How does local memory change spatial dynamics?
- Can complex organization emerge without global coordination?

Automates provides a practical environment for exploring these questions visually and interactively.

---

## Relation to model prototyping

The cellular automata available in Automates form the conceptual and technical foundation of the broader model prototyping approach.

Classical automata use simple cell states and local update rules. More elaborate prototypes may add agent-like entities, auxiliary data structures, stochastic decisions, or model-specific outputs.

The common principle remains the same:

```text
local rules generate spatial dynamics
```

This makes cellular automata a useful starting point for building more specialized rule-based models.

---

## Choosing an automaton family

A simple guide is:

| Goal | Suggested family |
|---|---|
| Explore classical birth/survival rules | Life-like automata |
| Generate waves or trails | Generations automata |
| Explore cyclic dominance or rotating waves | Cyclic automata |
| Test directional or asymmetric local interactions | Weighted Life automata |
| Produce smoother large-scale patterns | Larger than Life automata |

These categories are not exclusive. They are best viewed as complementary tools for exploring different forms of spatial organization.

---

## Current scope

The current cellular automata plugins are intended for exploration, teaching, visualization, and early-stage model design.

They are useful for:

- comparing rule families;
- generating spatial patterns;
- testing local-rule hypotheses;
- producing visual demonstrations;
- building intuition about emergent dynamics.

They should not be interpreted as calibrated physical or biological models unless explicitly parameterized and validated for a given system.

---

## Summary

Automates includes several families of cellular automata, from classical Life-like systems to cyclic, weighted, generational, and larger-neighborhood models.

Together, these automata provide a compact but flexible framework for exploring how simple local rules can generate complex spatial patterns.

They also provide the foundation for more general spatial model prototyping within Automates.
