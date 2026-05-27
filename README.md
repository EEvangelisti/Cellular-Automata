# Automates

**Automates** is a lightweight OCaml platform for prototyping cellular automata 
and agent-based rule models on two-dimensional grids.

It was originally designed as a flexible playground for exploring classical 
cellular automata, but its plugin architecture also makes it suitable for more 
general spatial model prototyping. A model can be implemented as a standard 
automaton, as a grid-based rule system, or as an agent-like simulation in which 
active entities interact with a discrete environment.

The program combines:

- a graphical interface;
- Cairo-based rendering;
- a modular plugin system;
- import and export of model states;
- optional frame capture for visualization;
- command-line parameters for reproducible exploration.

The central goal of **Automates** is to provide a simple, extensible framework 
for testing how local rules generate complex spatial dynamics. It is intended 
for exploratory modelling, teaching, visualization, and early-stage hypothesis 
formalization rather than for fully calibrated simulation.

![Automates overview](images/automates_overview.png)

---

## Documentation

- [User guide](docs/user_guide.md): installation, building, running, repository structure, and plugin basics.
- [Cellular automata](docs/cellular_automata.md): general principles of cellular automata and their implementation in Automates.
- [Model prototyping](docs/model_prototyping.md): use of Automates as a platform for spatial rule-based and agent-like models.

---

## Overview

In **Automates**, space is represented as a two-dimensional matrix. At each 
iteration, a model-specific `evolve` function computes the next state of the 
system. The graphical layer then renders the resulting matrix efficiently.

This design keeps the core application independent from individual models. New 
automata or rule-based simulations can be added as plugins, while reusing the 
same interface, rendering engine, execution loop, and configuration system.

Although simple by design, Automates can be used to explore a broad range of 
spatial dynamics, including Conway-like automata, cyclic automata, coral-like 
growth, maze-forming systems, propagating fronts, hyphal-growth toy models, and 
agent-like simulations on a grid.
