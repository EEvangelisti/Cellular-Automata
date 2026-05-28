(*
  ca_life.ml — Life-like cellular automaton plugin for Automates

  This plugin implements a family of Life-like cellular automata.

  General principle
  -----------------
  Life-like automata are inspired by Conway's Game of Life and related
  birth/survival systems.

  Each cell is either inactive or active. At each generation, the next state
  of a cell is determined by the number of active cells in its Moore
  neighborhood, composed of the eight adjacent cells.

  An inactive cell may become active if the number of active neighbors
  matches the birth rule. An active cell may survive or disappear depending
  on the survival/death rule.

  This simple framework can generate rich spatial dynamics, including stable
  structures, oscillators, expanding patterns, chaotic transients, and
  self-organized motifs.

  Rule format
  -----------
  Rules are read from the file:

      ca_life_rules.db

  Each rule must follow the format:

      AUTOMATON "name": <survival>/<birth>

  where:

      survival
         List of Moore-neighborhood counts for which an active cell does
         not die.

      birth
         List of Moore-neighborhood counts for which an inactive cell becomes
         active.

  Example
  -------
      AUTOMATON "conway": 23/3

  Interpretation
  --------------
  For each cell, the plugin counts active cells in the Moore neighborhood.

  If the current cell is inactive:

      it becomes active if the count matches the birth rule.

  If the current cell is active:

      it dies if the count does not match the survival rule;
      otherwise, it remains active.

  States and display
  ------------------
  State 0 is inactive.

  Any non-zero state is considered active when counting neighbors. Surviving
  active cells may progress through display states up to the configured
  maximum number of cell states. These states can be used to visualize
  persistence or ageing, but they are all treated as active for neighborhood
  counting.

  Neighborhood
  ------------
  The plugin uses the Moore neighborhood:

      NW  N  NE
       W  C   E
      SW  S  SE

  Only the eight adjacent cells are counted. The central cell is not included
  in the neighborhood count.

  Boundary conditions
  -------------------
  The plugin uses the standard Automates wrapping functions. The universe
  is therefore treated as periodic: cells leaving one side of the grid
  re-enter from the opposite side.

  Notes
  -----
  This is a generic cellular automaton plugin. It is intended for exploring
  classical birth/survival rules and Life-like spatial dynamics, not as a
  calibrated physical or biological simulator.
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
  let prototyping = false
  let configure ~name:_ _ = ()

  let import = Plugin.import
  let export = Plugin.export

  let create ?zone ~seed () = Plugin.create_matrix 
    ~rows:P.n_rows
    ~columns:P.n_cols  
    ~seed ()

  let check_row, check_col = Plugin.move_functions 
    ~rows:P.n_rows 
    ~columns:P.n_cols

  let norm (_, s) = if s = '\000' then 0 else 1 

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
    let mem = List.mem (moore_neighborhood mat r c) in
    match cur with
      | '\000' when mem P.birth_rules -> Plugin.t001
      | '\000'                        -> Plugin.f000
      |    _   when mem P.death_rules -> Plugin.t000
      |    _                          -> let n = Char.code cur in
        if n = states then (false, cur) else (true, Char.(chr (1 + n)))

  let evolve = Plugin.evolve next_state
 end

let make_module ~birth ~death =
  let module P =
   struct
    let n_rows = !Settings.nrows
    let n_cols = !Settings.ncols
    let states = !Settings.cell_states
    let birth_rules = birth
    let death_rules = death
   end
  in (module Make(P) : Plugin.AUTOMATON)

let db_file = Filename.concat !Settings.plugin_folder "ca_life_rules.db"

let _ =
  List.iter (fun ca_line ->
    sscanf ca_line " AUTOMATON %S: %[0-9]/%[0-9]" (fun id s_rule b_rule ->
    Hashtbl.add Plugin.ca_database ("LIFE-" ^ id) (
     make_module
      ~birth:(Plugin.get_birth_rule b_rule) 
      ~death:(Plugin.get_death_rule s_rule)
    ))
  ) Tools.(nlines (String.trim (read_file db_file)))
