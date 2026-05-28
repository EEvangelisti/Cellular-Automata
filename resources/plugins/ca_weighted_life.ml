(*
  ca_weighted_life.ml — Weighted Life-like cellular automaton plugin for Automates

  This plugin implements a family of weighted Life-like cellular automata.

  General principle
  -----------------
  Weighted Life automata extend classical Life-like automata by assigning
  different weights to the positions of the local neighborhood.

  Instead of simply counting how many neighboring cells are active, the
  plugin computes a weighted local score. Birth and survival are then
  determined by checking whether this score matches the corresponding
  rule lists.

  This makes it possible to explore how local geometry, directional bias,
  and asymmetric neighborhoods affect global pattern formation.

  Rule format
  -----------
  Rules are read from the file:

      ca_weighted_life_rules.db

  Each rule must follow the format:

      AUTOMATON "name":
        NW<nw> NN<nn> NE<ne> WW<ww> ME<me> EE<ee> SW<sw> SS<ss> SE<se> HI<states>
        R<rule> R<rule> ...

  where the nine weights correspond to the 3 × 3 neighborhood:

      NW  NN  NE
      WW  ME  EE
      SW  SS  SE

  and:

      NW, NN, NE, WW, ME, EE, SW, SS, SE
         Integer weights assigned to each neighborhood position.

      ME
         Weight of the central cell itself.

      HI
         Number of display/history states.
         If HI is 0, the default number of cell states is used and history
         mode is disabled. If HI is greater than 0, history mode is enabled.

      RS<n>
         Survival rule.
         An active cell survives if the weighted neighborhood score is n.

      RB<n>
         Birth rule.
         An inactive cell becomes active if the weighted neighborhood score
         is n.

  Example
  -------
      AUTOMATON "example": NW1 NN1 NE1 WW1 ME0 EE1 SW1 SS1 SE1 HI0 RS2 RS3 RB3

  Interpretation
  --------------
  For each cell, the plugin computes a weighted neighborhood score:

      score =
        NW × state(NW) + NN × state(NN) + NE × state(NE) +
        WW × state(WW) + ME × state(ME) + EE × state(EE) +
        SW × state(SW) + SS × state(SS) + SE × state(SE)

  The interpretation of state values depends on whether history mode is
  enabled.

  Without history mode:

      any non-zero state is considered active.

  With history mode:

      only state 1 is considered active for neighborhood scoring;
      higher states are fading or ageing states.

  Birth and survival
  ------------------
  If the current cell is inactive:

      it becomes active if the score matches one of the birth rules.

  If the current cell is active:

      it survives if the score matches one of the survival rules.

  Otherwise, the cell becomes inactive or enters the ageing sequence,
  depending on whether history mode is enabled.

  History mode
  ------------
  When HI is greater than 0, the automaton keeps transient display states.

  In this mode:

      state 0    inactive
      state 1    active
      state > 1  ageing / fading states

  Ageing states are displayed but are not counted as active neighbors.

  This makes it possible to combine weighted Life-like rules with trails,
  fading structures, or refractory-like visual dynamics.

  Neighborhood
  ------------
  The plugin uses a weighted 3 × 3 neighborhood including the central cell.

  By setting the central weight ME to 0, the automaton behaves like a
  classical neighborhood count that excludes the current cell.

  By assigning unequal weights to different positions, one can create
  directional or anisotropic variants of Life-like rules.

  Boundary conditions
  -------------------
  The plugin uses the standard Automates wrapping functions. The universe
  is therefore treated as periodic: cells leaving one side of the grid
  re-enter from the opposite side.

  Notes
  -----
  This is a generic cellular automaton plugin. It is intended for exploring
  weighted neighborhoods, anisotropic local rules, directional effects, and
  Life-like spatial dynamics, not as a calibrated physical or biological
  simulator.
*)

open Scanf
open Printf

module type PARAMS =
 sig
  val n_rows : int
  val n_cols : int
  val states : int
  val history : bool
  val weights : int array
  val birth_rules : int list
  val survival_rules : int list
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

  let norm (_, s) = if s = '\001' then 1 else 0
  let norm_no_history (_, s) = if s = '\000' then 0 else 1

  (* Moore neighborhood is composed of 8 adjacent cells. *)
  let moore_neighborhood norm mat r c =
    let pr = mat.(check_row (r - 1)) 
    and nr = mat.(check_row (r + 1))
    and pc = check_col (c - 1) 
    and nc = check_col (c + 1) 
    and mr = mat.(r) in 
    P.weights.(0) * norm pr.(pc)     + P.weights.(1) * norm pr.(c)  + 
    P.weights.(2) * norm pr.(nc)     + P.weights.(3) * norm mr.(pc) + 
    P.weights.(4) * norm mat.(r).(c) + P.weights.(5) * norm mr.(nc) +
    P.weights.(6) * norm nr.(pc)     + P.weights.(7) * norm nr.(c)  + 
    P.weights.(8) * norm nr.(nc)

  let next_state mat r c (modi, cur) =
    if P.history then begin
      let mem = List.mem (moore_neighborhood norm mat r c) in
      match cur with
      | '\000' when mem P.birth_rules    -> Plugin.t001
      | '\000'                           -> Plugin.f000
      | '\001' when mem P.survival_rules -> (false, '\001')
      | '\001'                           -> (true, '\002')
      | _ -> let n = Char.code cur in
        if n = states then Plugin.t000 else (true, Char.(chr (1 + n)))
    end else begin
      let mem = List.mem (moore_neighborhood norm_no_history mat r c) in
      match cur with
      | '\000' when mem P.birth_rules    -> Plugin.t001
      | '\000'                           -> Plugin.f000
      | _ when mem P.survival_rules      -> let n = Char.code cur in
        if n = states then (false, cur) else (true, Char.(chr (1 + n)))
      | _ -> Plugin.t000
    
    end

  let evolve = Plugin.evolve next_state
 end

let make_module ~birth ~survival ~states ~weights ~history =
  let module P =
   struct
    let n_rows = !Settings.nrows
    let n_cols = !Settings.ncols
    let states = states - 1
    let history = history
    let weights = weights
    let birth_rules = birth
    let survival_rules = survival
   end
  in (module Make(P) : Plugin.AUTOMATON)

let db_file = Filename.concat 
  !Settings.plugin_folder 
  "ca_weighted_life_rules.db"

let retrieve_rules str =
  let ich = Scanning.from_string str in
  let rec loop s_rule b_rule =
    kscanf ich (fun _ _ -> Scanning.close_in ich; s_rule, b_rule) 
     " R%c%d" (function
      | 'S' -> (fun d -> loop (d :: s_rule) b_rule)
      | 'B' -> (fun d -> loop s_rule (d :: b_rule))
      |  _  -> invalid_arg "retrieve_rules"
    )
  in loop [] []

let _ =
  List.iter (fun ca_line ->
    sscanf ca_line 
      " AUTOMATON %S: NW%d NN%d NE%d WW%d ME%d EE%d SW%d SS%d SE%d HI%d %[^\n]" 
      (fun id nw nn ne ww me ee sw ss se hi rem ->
        let weights = [|nw; nn; ne; ww; me; ee; sw; ss; se|]
        and states = if hi = 0 then !Settings.cell_states else hi in
        let survival, birth = retrieve_rules rem in
        Hashtbl.add Plugin.ca_database ("WLIF" ^ id) (
         make_module ~states ~weights ~birth ~survival ~history:(hi > 0)
        ))
  ) Tools.(nlines (String.trim (read_file db_file)))
