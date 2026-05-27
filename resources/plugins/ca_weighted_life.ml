(*  ca_weighted_life.ml - Plugin file
 *  Copyright (C) 2014, 2015, 2016, 2017 Edouard Evangelisti
 * 
 *  This file is part of Ocelot (OCaml Cellular Automata).
 *    
 *  OCelot is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 * 
 *  Ocelot is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with Ocelot.  If not, see <http://www.gnu.org/licenses/>
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
        Hashtbl.add Plugin.ca_database (Filename.concat "WLIF" id) (
         make_module ~states ~weights ~birth ~survival ~history:(hi > 0)
        ))
  ) Tools.(nlines (String.trim (read_file db_file)))
