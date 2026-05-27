(*  ca_generations.ml - Plugin file
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
