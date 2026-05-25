(*  ca_cyclic.ml - Plugin file
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
  val threshold : int
  val neighborhood_range : int
 end

module Make (P : PARAMS) : Plugin.AUTOMATON =
 struct
  let n_rows = P.n_rows
  let n_cols = P.n_cols
  let states = max 2 (min P.states 255)

  let import = Plugin.import
  let export = Plugin.export

  let create ~seed = Plugin.create_matrix 
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
        Hashtbl.add Plugin.ca_database (Filename.concat "CYCL" id) mdl)
  ) Tools.(nlines (String.trim (read_file db_file)))
