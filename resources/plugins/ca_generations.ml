(*
  ca_generations.ml — Generations cellular automaton plugin for Automates

  This plugin implements a family of Generations cellular automata.

  General principle
  -----------------
  Generations automata extend Life-like cellular automata by adding
  transient intermediate states.

  A cell can be:

      0       inactive / dead
      1       active / alive
      2..n    fading, refractory, or ageing states

  Dead cells may become active according to a birth rule. Active cells may
  either remain active or enter the fading sequence. Once a cell has entered
  the fading sequence, it progresses through successive states until it
  eventually returns to the inactive state.

  This produces automata with memory-like effects, trails, waves, refractory
  zones, and excitable-medium-like dynamics.

  Rule format
  -----------
  Rules are read from the file:

      ca_generations_rules.db

  Each rule must follow the format:

      AUTOMATON "name": <D>/<B>/<C>

  where:

      D  death / decay rule
         List of Moore-neighborhood counts for which an active cell leaves
         the active state and enters the ageing sequence.

      B  birth rule
         List of Moore-neighborhood counts for which an inactive cell becomes
         active.

      C  number of states
         Total number of states, including the inactive state.

  Example
  -------
      AUTOMATON "example": 23/3/8

  Interpretation
  --------------
  For each cell:

      state 0:
        becomes state 1 if the number of active neighbors matches B

      state 1:
        becomes state 2 if the number of active neighbors matches D
        otherwise remains state 1

      state >= 2:
        advances to the next ageing state until the last state is reached,
        then returns to state 0

  Neighborhood
  ------------
  The plugin uses the Moore neighborhood, composed of the eight adjacent
  cells surrounding the current cell.

  Only cells in state 1 are counted as active neighbors. Fading or ageing
  states are displayed but do not contribute to the neighborhood count.

  Boundary conditions
  -------------------
  The plugin uses the standard Automates wrapping functions. The universe
  is therefore treated as periodic: cells leaving one side of the grid
  re-enter from the opposite side.

  Notes
  -----
  This is a generic cellular automaton plugin. It is intended for exploring
  waves, trails, refractory dynamics, and generational extensions of
  Life-like automata, not as a calibrated physical or biological simulator.
*)

open Scanf
open Printf

module type PARAMS =
 sig
  val n_rows : int
  val n_cols : int
  val states : int
  val birth_rules : int list
  val death_rules : int list
 end

module Make (P : PARAMS) : Plugin.AUTOMATON =
 struct
  let n_rows = P.n_rows
  let n_cols = P.n_cols
  let states = max 2 (min P.states 255)

  let import = Plugin.import
  let export = Plugin.export

  let create ?zone ~seed () = Plugin.create_matrix 
    ~rows:P.n_rows
    ~columns:P.n_cols
    ~seed ()

  let check_row, check_col = Plugin.move_functions
    ~rows:P.n_rows
    ~columns:P.n_cols

  let norm (_, s) = if s = '\001' then 1 else 0 

  (* Moore neighborhood is composed of 8 adjacent cells. *)
  let moore_neighborhood mat r c =
    let pr = mat.(check_row (r - 1)) 
    and nr = mat.(check_row (r + 1))
    and pc = check_col (c - 1) 
    and nc = check_col (c + 1) 
    and mr = mat.(r) in 
    norm pr.(pc) + norm pr.(c) + norm pr.(nc) +
    norm mr.(pc) +               norm mr.(nc) +
    norm nr.(pc) + norm nr.(c) + norm nr.(nc)

  let next_state mat r c (modi, cur) =
    match Char.code cur with
    | 0 -> let mem = List.mem (moore_neighborhood mat r c) in
      if mem P.birth_rules then Plugin.t001 else Plugin.f000 
    | 1 -> let mem = List.mem (moore_neighborhood mat r c) in
      if mem P.death_rules then (true, '\002') else Plugin.f001 
    | n -> if n < states then (true, Char.chr (1 + n)) else Plugin.t000

  let evolve = Plugin.evolve next_state
 end

let make_module ~birth ~death ~states =
  let module P =
   struct
    let n_rows = !Settings.nrows
    let n_cols = !Settings.ncols
    let states = states - 1 (* the raw value contains the 0 (dead) state. *)
    let birth_rules = birth
    let death_rules = death
   end
  in (module Make(P) : Plugin.AUTOMATON)

let db_file = Filename.concat !Settings.plugin_folder "ca_generations_rules.db"


let _ =
  List.iter (fun ca_line ->
    sscanf ca_line " AUTOMATON %S: %[0-9]/%[0-9]/%d" (fun id s_rule b_rule states ->
    Hashtbl.add Plugin.ca_database (Filename.concat "GENE" id) (
     make_module
      ~birth:(Plugin.get_birth_rule b_rule) 
      ~death:(Plugin.get_death_rule s_rule)
      ~states
    ))
  ) Tools.(nlines (String.trim (read_file db_file)))
