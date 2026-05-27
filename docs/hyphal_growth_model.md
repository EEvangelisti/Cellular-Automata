# Hyphal growth prototype

This document describes the hyphal growth prototype implemented in `ca_hyphae.ml`.

The model is a toy agent-based extension of the **Automates** framework. It represents hyphal growth as the propagation of active tips on a two-dimensional grid. Each growing tip carries internal information such as direction, age, and branching competence.

The purpose of this plugin is not to reproduce the full biology of filamentous growth. Instead, it provides a practical rule-based prototype for exploring how simple local rules can generate branching, collision, and network-like spatial patterns.

The current version should therefore be considered exploratory.

> **Status:** not validated by biological data.

![Hyphal growth model](hyphal_growth_toy_model.gif)

---

## General principle

Each hyphal element is represented as an agent occupying one grid cell.

At each internal model cycle:

1. existing hyphal elements persist;
2. their age increases;
3. active tips may extend into a neighboring cell;
4. sufficiently old and competent elements may generate lateral branches;
5. collisions stop tip extension;
6. the visible matrix is reconstructed from the internal agent map.

The visible grid stores display states, mainly based on age. The biologically relevant information, such as whether a cell is an active tip or a mature segment, is stored internally by the plugin.

---

## Hyphal agent state

Each hyphal element stores the following information:

```ocaml
type agent = {
  age : int;
  angle : int;
  tip : bool;
  can_branch : bool;
}
```

These fields are used as follows:

- `age`: age of the hyphal element;
- `angle`: internal direction of growth;
- `tip`: whether the element is an active apical tip;
- `can_branch`: whether the element is still competent to form a branch.

This distinction is important because the visible grid does not directly encode the full biological state of each element. The matrix is used for rendering, while the plugin maintains a richer internal state.

---

## Initial condition

At creation, the model seeds a number of initial hyphal tips at random positions on the grid.

Each initial tip has:

- age `0`;
- a random direction;
- active tip status;
- branching competence.

Initial seeds are placed only if the chosen grid position is empty. This avoids duplicate agents at the same coordinate.

The initial configuration is therefore a population of independent growing tips.

---

## Rule syntax

Hyphal-growth rules are defined in the automaton database with entries of the following form:

```text
AUTOMATON "example_name": G0.90/B0.02/A12/D360/W3/J20/M50
```

The parameters are:

| Parameter | Meaning | Example |
|---|---|---|
| `G` | probability that an active tip grows during one cycle | `G0.90` |
| `B` | probability that a mature competent cell branches during one cycle | `B0.02` |
| `A` | minimal age required before branching | `A12` |
| `D` | number of internal angular states | `D360` |
| `W` | angular noise applied to active tips | `W3` |
| `J` | angular jitter applied to branch direction | `J20` |
| `M` | maximal display age | `M50` |

Different rule entries define different growth regimes and can be selected as distinct automata within Automates.

---

## Growth probability

The `G` parameter controls apical extension.

At each cycle, an active tip attempts to grow with probability:

```text
G
```

For example:

```text
G0.90
```

means that an active tip attempts to extend in 90% of internal cycles.

When growth succeeds, the old tip becomes a non-tip hyphal segment and a new active tip is created one cell ahead.

This produces tip-driven elongation, where the growing front advances while leaving a persistent hyphal body behind.

---

## Direction and angular resolution

Each tip carries an internal angle.

The number of possible internal angular states is controlled by the `D` parameter.

For example:

```text
D360
```

means that the model uses 360 internal angular states, so one angular unit corresponds approximately to one degree.

The actual spatial update still occurs on a grid. Therefore, the internal angle is converted into one of the eight Moore-neighborhood directions:

```text
E, NE, N, NW, W, SW, S, SE
```

This gives the model a fine internal direction while keeping the spatial representation compatible with a cellular automaton.

---

## Directional drift

The `W` parameter controls small angular deviations during tip growth.

At each cycle, active tips slightly modify their direction by adding a random signed deviation between:

```text
-W and +W
```

For example:

```text
W3
```

means that the internal angle may drift by up to three angular units per cycle.

This produces gently wandering hyphae rather than perfectly straight lines.

---

## Stochastic mapping to grid directions

Although movement occurs on a grid, the plugin does not simply round every angle to the nearest of eight directions.

Instead, it uses a stochastic conversion from internal angle to Moore-neighborhood direction. If the internal angle lies between two grid directions, the model can choose either direction with a probability proportional to the angular position.

This reduces rigid eight-direction artefacts while preserving the simplicity of a grid-based model.

The model therefore remains discrete, but growth appears less mechanically constrained than in a purely eight-direction automaton.

---

## Branching

Branching is controlled by three parameters:

```text
B, A, J
```

A hyphal element can branch if:

1. it is still branch-competent;
2. its age is at least `A`;
3. a random branching event occurs with probability `B`.

For example:

```text
A12
B0.02
```

means that cells become eligible for branching after 12 cycles, and each eligible cell has a 2% chance of producing a branch at each cycle.

Branching is therefore stochastic and age-dependent.

---

## Branch direction

Branches are generated laterally relative to the mother axis.

The model chooses one of the two lateral directions, approximately corresponding to a quarter-turn from the current direction:

```text
+90° or -90°
```

The branch direction is then modified by a random jitter controlled by `J`.

For example:

```text
J20
```

means that the branch angle can deviate from the ideal lateral direction by up to 20 angular units.

This produces variable but generally lateral branching.

---

## Branch inhibition

After a cell produces a branch, it loses branching competence.

The model also inhibits nearby lateral positions relative to the mother axis. This prevents unrealistically dense adjacent branching events.

This rule introduces a minimal form of local spacing between branches.

It is not intended as a detailed biological mechanism, but as a simple way to avoid excessive clustering of branch initiation sites.

---

## Collision behavior

If an active tip attempts to grow into a position that is already occupied, the growth event is cancelled.

The tip then stops and becomes inactive.

This implements a simple collision rule:

```text
occupied target → tip arrest
```

The model does not currently implement fusion, avoidance, overgrowth, or reorientation after collision.

---

## Periodic boundaries

The simulation space uses periodic boundaries.

When a tip attempts to leave one side of the grid, its target position is wrapped to the opposite side.

This toric geometry is a computational convenience. It prevents growth from being stopped artificially by the edge of the matrix.

However, for biological interpretation, one should remember that the model does not currently include explicit physical boundaries.

---

## Display states

The visible matrix is reconstructed from the internal agent map at each generation.

Each occupied position is displayed according to its age.

The display age is capped by:

```text
M
```

For example:

```text
M50
```

means that age-dependent display states are saturated at age 50.

The value of `M` mainly controls rendering and color progression. It does not by itself stop growth or remove old hyphal elements.

---

## Import and reconstruction

The plugin supports the standard Automates import mechanism.

However, when a matrix is imported, the internal state has to be reconstructed from visible cells only. Since the visible matrix does not encode the complete internal state, reconstruction is conservative.

All non-empty visible cells are treated as active tips with random directions and restored branching competence.

This is useful for restarting or visualizing a state, but imported configurations should not be interpreted as exact restorations of the original internal dynamics.

---

## Exporting model states

The plugin uses the standard Automates export mechanism.

Exported states contain the visible matrix, not the full internal agent map.

This means that exported files preserve spatial occupancy and display age, but not necessarily:

- tip status;
- precise internal direction;
- branching competence;
- previous growth history.

For full quantitative analysis, the plugin would need to be extended with dedicated export functions for agent-level observables.

---

## Recovering growth dynamics

The current plugin does not export hyphal trajectories as a dedicated tracking file.

However, growth dynamics can still be recovered in several ways:

1. export successive matrix states;
2. save successive PNG frames;
3. analyse occupied area over time;
4. quantify the number and distribution of tips from internal or derived states;
5. extend the plugin to export agent-level measurements.

Useful measurements include:

- total occupied area;
- radial expansion;
- number of active tips;
- branch density;
- branch spacing;
- collision frequency;
- network anisotropy;
- growth front roughness;
- spatial connectivity.

Such observables would make it possible to compare rule sets quantitatively.

---

## Recommended interpretation

The current model should be interpreted as a proof of concept for agent-based hyphal growth on a cellular automaton grid.

It can be used to test whether simple local rules are sufficient to generate:

- elongated growth;
- persistent hyphal segments;
- lateral branching;
- network-like expansion;
- collision-induced arrest;
- local spacing of branches.

It should not yet be interpreted as a calibrated biological model of real hyphal development.

---

## Possible validation metrics

Future comparison with experimental hyphal growth data should rely on explicit observables, such as:

- extension rate;
- branch frequency;
- branch angle distribution;
- branch spacing;
- hyphal length distribution;
- tip density;
- network density;
- occupied area over time;
- radial expansion rate;
- collision and arrest frequency;
- spatial anisotropy;
- network connectivity.

The model could then be calibrated by adjusting parameters such as `G`, `B`, `A`, `D`, `W`, and `J`.

---

## Current limitations

The current implementation has several deliberate simplifications:

- growth occurs on a discrete grid;
- only neighboring grid cells can be colonized at each extension event;
- the model uses periodic boundaries;
- hyphal thickness is not represented;
- cytoplasmic flow is not represented;
- nutrient gradients are not represented;
- septation is not represented;
- anastomosis is not represented;
- tip splitting is not represented;
- collision leads only to arrest;
- biological parameters have not been fitted to experimental data;
- exported states do not preserve the full internal agent state.

These limitations are acceptable for a prototype, but should be addressed or explicitly discussed before biological interpretation.

---

## Possible extensions

The current model provides a minimal framework that could be extended in several directions.

Possible additions include:

- nutrient-dependent growth;
- local substrate heterogeneity;
- explicit obstacles;
- chemotropic or thigmotropic responses;
- tip reorientation after collision;
- anastomosis;
- variable hyphal thickness;
- explicit apical dominance;
- branching inhibition fields;
- export of individual tip trajectories;
- graph-based network analysis;
- calibration against microscopy data.

These extensions would make the model more biologically informative while preserving the general Automates architecture.

---

## Summary

The hyphal-growth plugin implements a minimal agent-based model of tip-driven filamentous growth on a cellular automaton grid.

Its main purpose is to demonstrate that Automates can represent persistent growing structures with internal state, stochastic elongation, lateral branching, and collision behavior.

The current implementation is useful for methodological development, visualization, and early-stage hypothesis formalization, but remains:

```text
not validated by biological data
```
