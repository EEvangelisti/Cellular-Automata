(*
  ca_larger_than_life.ml — Larger-than-Life cellular automaton plugin for Automates

  This plugin implements a family of Larger-than-Life cellular automata.

  General principle
  -----------------
  Larger-than-Life automata extend Life-like cellular automata by using
  neighborhoods larger than the immediate Moore neighborhood.

  Instead of considering only the eight adjacent cells, each cell counts
  active cells within a square neighborhood of configurable range. Birth and
  survival are then controlled by intervals rather than by exact neighbor
  counts.

  This can generate smoother and larger-scale patterns than classical
  Life-like automata, including expanding fronts, rounded colonies,
  labyrinthine structures, and broad spatial domains.

  Rule format
  -----------
  Rules are read from the file:

      ca_larger_than_life_rules.db

  Each rule must follow the format:

      AUTOMATON "name": <range> <include_center> S<min>..<max> B<min>..<max>

  where:

      range
         Radius of the square neighborhood used for counting active cells.
         A range of 1 corresponds to the usual 3 × 3 neighborhood.

      include_center
         Boolean value indicating whether the central cell itself is included
         in the neighborhood count.

      S<min>..<max>
         Survival interval.
         An active cell survives if the number of active cells in its
         extended neighborhood lies within this interval.

      B<min>..<max>
         Birth interval.
         An inactive cell becomes active if the number of active cells in its
         extended neighborhood lies within this interval.

  Example
  -------
      AUTOMATON "smooth_growth": 5 true S34..58 B34..45

  Interpretation
  --------------
  For each cell, the plugin counts active cells in the extended neighborhood.

  If the current cell is inactive:

      it becomes active if the count is within the birth interval B.

  If the current cell is active:

      it survives if the count is within the survival interval S;
      otherwise, it becomes inactive.

  States and ageing
  -----------------
  The automaton uses at least two states.

  State 0 is inactive. Any non-zero state is considered active when counting
  neighbors.

  Surviving active cells may progress through display states up to the
  configured maximum number of cell states. These states can be used to
  visualize persistence or ageing, but they are all treated as active for
  neighborhood counting.

  Neighborhood
  ------------
  The neighborhood is an extended square Moore-like neighborhood.

  For a range R, the counted region has size:

      (2R + 1) × (2R + 1)

  If include_center is false, the central cell is excluded from the count.
  If include_center is true, the central cell contributes to the count when
  it is active.

  Boundary conditions
  -------------------
  The plugin uses the standard Automates wrapping functions. The universe
  is therefore treated as periodic: cells leaving one side of the grid
  re-enter from the opposite side.

  Notes
  -----
  This is a generic cellular automaton plugin. It is intended for exploring
  large-neighborhood birth/survival rules, smooth growth, fronts, domains,
  and maze-like spatial organization, not as a calibrated physical or
  biological simulator.
*)
open Scanf
open Printf

module type PARAMS =
 sig
  val n_rows : int
  val n_cols : int
  val states : int
  val birth_rules : int * int
  val death_rules : int * int
  val neighborhood_range : int
  val middle_cell_is_active : bool
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

  let norm (_, s) = if s = '\000' then 0 else 1 

  (* Moore neighborhood is composed of 8 adjacent cells. *)
  let extended_moore_neighborhood mat r c =
    let count = ref 0 in
    for ir = r - P.neighborhood_range to r + P.neighborhood_range do
      let row = mat.(check_row ir) in
      for jc = c - P.neighborhood_range to c + P. neighborhood_range do
        let status = norm row.(check_col jc) in
        if ir = r && jc = c then (
          if P.middle_cell_is_active then count := !count + status
        ) else count := !count + status
      done
    done;
    !count

  let bi, bf = P.birth_rules
  let di, df = P.death_rules
  let next_state mat r c (modi, cur) =
    let num = extended_moore_neighborhood mat r c in
    match cur with
    | '\000' when num >= bi && num <= bf -> Plugin.t001
    | '\000'                             -> Plugin.f000
    |    _   when num < di || num > df   -> Plugin.t000
    |    _                               -> let n = Char.code cur in
      if n = states then (false, cur) else (true, Char.(chr (1 + n)))

  let evolve = Plugin.evolve next_state
 end

let make_module ~range ~birth ~death ~active =
  let module P =
   struct
    let n_rows = !Settings.nrows
    let n_cols = !Settings.ncols
    let states = !Settings.cell_states
    let birth_rules = birth
    let death_rules = death
    let neighborhood_range = range
    let middle_cell_is_active = active
   end
  in (module Make(P) : Plugin.AUTOMATON)

let db_file = Filename.concat 
  !Settings.plugin_folder 
  "ca_larger_than_life_rules.db"

let _ =
  List.iter (fun ca_line ->
    sscanf ca_line " AUTOMATON %S: %d %b S%d..%d B%d..%d" 
      (fun id range active s_ini s_end b_ini b_end ->
        Hashtbl.add Plugin.ca_database (Filename.concat "LGTL" id) (
         make_module
          ~birth:(b_ini, b_end) 
          ~death:(s_ini, s_end)
          ~range ~active
        ))
  ) Tools.(nlines (String.trim (read_file db_file)))
