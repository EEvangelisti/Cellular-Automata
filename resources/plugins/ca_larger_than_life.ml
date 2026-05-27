(*  ca_larger_than_life.ml - Plugin file
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
