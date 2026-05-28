(*
  ca_cyclic.ml — Cyclic cellular automaton plugin for Automates

  This plugin implements a family of cyclic cellular automata.

  General principle
  -----------------
  Each cell belongs to one state in a cyclic sequence:

      0 -> 1 -> 2 -> ... -> n -> 0

  At each generation, a cell checks whether enough neighboring cells are
  already in its next cyclic state. If this number reaches the threshold,
  the cell advances to that next state. Otherwise, it remains unchanged.

  This simple rule can generate rich spatial dynamics, including waves,
  rotating fronts, spirals, and cyclic domains.

  Rule format
  -----------
  Rules are read from the file:

      ca_cyclic_rules.db

  Each rule must follow the format:

      AUTOMATON "name": R<range>/T<threshold>/C<states>

  where:

      R  neighborhood range
         R1 corresponds to the usual Moore neighborhood.
         Higher values extend the neighborhood over a larger square region.

      T  threshold
         Minimum number of neighboring cells in the next cyclic state
         required for a cell to advance.

      C  number of cyclic states
         Number of states used by the automaton.

  Example
  -------
      AUTOMATON "spirals": R1/T3/C14

  Interpretation
  --------------
  For each cell:

      current_state = s
      next_state    = s + 1 modulo C

  If at least T cells within range R are already in next_state, then the
  cell becomes next_state. Otherwise, it remains in current_state.

  Boundary conditions
  -------------------
  The plugin uses the standard Automates wrapping functions. The universe
  is therefore treated as periodic: cells leaving one side of the grid
  re-enter from the opposite side.

  Notes
  -----
  This is a generic cellular automaton plugin. It is intended for exploring
  cyclic spatial dynamics and visual pattern formation, not as a calibrated
  physical or biological simulator.
*)

open Scanf
open Printf

module type PARAMS =
 sig
  val n_rows : int
  val n_cols : int
  val states : int
  val threshold : int
  val neighborhood_range : int
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
    ~init:(states +  1) 
    ~rows:P.n_rows
    ~columns:P.n_cols
    ~seed ()

  let check_row, check_col = Plugin.move_functions
    ~rows:P.n_rows
    ~columns:P.n_cols

  (* Only count cells of the same state. *)
  let norm next (_, s) = if s = next then 1 else 0 

  (* Moore neighborhood is composed of 8 adjacent cells. *)
  let extended_moore_neighborhood n mat r c =
    let count = ref 0 in
    for ir = r - P.neighborhood_range to r + P.neighborhood_range do
      let row = mat.(check_row ir) in
      for jc = c - P.neighborhood_range to c + P. neighborhood_range do
        count := !count + norm n row.(check_col jc)
      done
    done;
    !count

  let next_state mat r c (modi, cur) =
    let n = Char.code cur in
    let num = extended_moore_neighborhood 
      (Char.chr (if n = states then 0 else n + 1)) mat r c in
    if num >= P.threshold then (
      if n = states then Plugin.t000 else (true, Char.(chr (1 + n)))
    ) else (false, cur)    

  let evolve = Plugin.evolve next_state
 end

let make_module ~range ~threshold ~states =
  let module P =
   struct
    let n_rows = !Settings.nrows
    let n_cols = !Settings.ncols
    let states = states - 1
    let threshold = threshold
    let neighborhood_range = range
   end
  in (module Make(P) : Plugin.AUTOMATON)

let db_file = Filename.concat !Settings.plugin_folder "ca_cyclic_rules.db"

let _ =
  List.iter (fun ca_line ->
    sscanf ca_line " AUTOMATON %S: R%d/T%d/C%d" 
      (fun id range threshold states ->
        let mdl = make_module ~range ~threshold ~states in
        Hashtbl.add Plugin.ca_database ("CYCL-" ^ id) mdl)
  ) Tools.(nlines (String.trim (read_file db_file)))
