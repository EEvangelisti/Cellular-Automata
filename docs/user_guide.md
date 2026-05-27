# User guide

This guide explains how to install, build, run, and extend **Automates**.

**Automates** is an OCaml application for exploring two-dimensional cellular automata and grid-based rule models through a graphical interface and a plugin architecture.

---

## Requirements

The current version requires:

- a functional OCaml system;
- `ocamlfind`;
- `lablgtk3`;
- `cairo2`;
- `str`;
- `unix`;
- `dynlink`.

The `str`, `unix`, and `dynlink` libraries are standard OCaml libraries, but 
they still need to be available to the build system through `ocamlfind`.

---

## Installing dependencies

On Debian/Ubuntu-like systems, the required packages can usually be installed with:

```bash
sudo apt install ocaml ocaml-findlib liblablgtk3-ocaml-dev libcairo2-ocaml-dev
```

Package names may vary depending on the Linux distribution.

---

## Checking the OCaml environment

You can check that the required OCaml packages are available with:

```bash
ocamlfind list | grep -E 'lablgtk3|cairo2|str'
```

If one of the packages is missing, the build may fail with an error indicating 
that a package cannot be found.

---

## Building Automates

From the root directory of the repository, run:

```bash
./build.sh
```

Depending on the local organization of the repository, the project can also be 
built from the `src/` directory:

```bash
cd src
make
```

The executable is generated under the configured build directory.

---

## Running Automates

A typical execution uses the compiled executable:

```bash
./automates
```

Several settings can be controlled from the command line, including:

- automaton selection;
- grid size;
- seed size;
- simulation speed;
- plugin folder;
- color scheme;
- PNG frame export.

For example:

```bash
./automates -rows 400 -cols 400 -seed 20
```

Exact options depend on the settings exposed in the current version of the program.

---

## Repository structure

A typical source tree contains:

```text
Sources/
  action.ml        Main execution logic
  automates.ml     Entry point
  draw.ml          Cairo-based rendering functions
  gUI.ml           Graphical interface
  plugin.ml        Plugin interface and shared plugin utilities
  settings.ml      Runtime settings and command-line options
  tools.ml         General utility functions
  plugins/         Automaton plugins
  *.mli            Module interfaces

Documentation/
  Generated documentation and related files

images/
  Representative screenshots and example outputs
```

---

## Plugin architecture

The main strength of **Automates** is its plugin system. Each automaton is 
implemented as an independent module matching a common interface.

A plugin defines:

- the size of the universe;
- the number of cell states;
- functions to create, import, and export matrices;
- an `evolve` function that computes the next generation.

This makes it possible to add new automata without modifying the core engine, 
the graphical interface, the rendering system, or the execution loop.

A plugin may implement classical cellular automata based on birth/survival rules, 
but it may also define more specialized update logic.

---

## Adding a new automaton

To add a new automaton:

1. Write a new plugin module implementing the expected automaton interface.
2. Define the creation, import, export, and evolution functions.
3. Register the plugin in the automaton database.
4. Optionally add a `.db` file to define several parameter sets.
5. Rebuild the project.

This makes it straightforward to explore different rule sets or families of 
automata within the same framework.

---

## Import and export

Automates supports import and export of automaton states when the corresponding 
functions are implemented by the plugin.

This allows simulations to be saved, reloaded, compared, or used as starting 
points for further exploration.

---

## Saving frames

Automates can optionally save successive frames as PNG images.

This is useful for:

- documenting a simulation;
- producing animations;
- comparing spatial patterns over time;
- generating figures for presentations or reports.

The exact command-line options depend on the current settings exposed by the program.

---

## Troubleshooting

### A package cannot be found

Check that the required OCaml packages are visible through `ocamlfind`:

```bash
ocamlfind list | grep -E 'lablgtk3|cairo2|str'
```

If a package is missing, install the corresponding development package for your distribution.

### The graphical interface does not start

Make sure that GTK3 and Cairo bindings are correctly installed and that the 
program is being run in an environment with graphical display support.

### A plugin does not appear

Check that:

- the plugin has been compiled;
- it is located in the expected plugin directory;
- it has been registered in the automaton database;
- the corresponding `.db` file, if required, is correctly formatted.

### The program builds but the selected automaton fails

The issue is likely plugin-specific. Check the plugin’s `create`, `import`, 
`export`, and `evolve` functions, and verify that the expected number of states 
matches the rendering and configuration files.

---

## Related documentation

- [Cellular automata](cellular_automata.md)
- [Model prototyping](model_prototyping.md)
