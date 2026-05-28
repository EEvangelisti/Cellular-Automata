(*  settings.ml
 *  Copyright (C) 2014-2027 Edouard Evangelisti
 * 
 *  This file is part of Automates.
 *    
 *  Automates is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 * 
 *  Automates is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with Automates.  If not, see <http://www.gnu.org/licenses/>
 *)


open Arg
open Printf

let str x = x

let automaton = ref "LIFE/LIFE"
let set_automaton s = automaton := s

let add_argument ~lbl ~ini ~arg ~str ~def =
  let r = ref ini in
  r, (lbl, arg r, sprintf " %s (default: %s)." def (str ini))

let color_scheme = add_argument 
  ~lbl:"--color-scheme" 
  ~ini:"AMANITA"
  ~arg:(fun r -> Set_string r) 
  ~str 
  ~def:"Color scheme used to draw multi-state cells"

let color_scheme_database = add_argument
  ~lbl:"--color-scheme-database"
  ~ini:"resources/color_schemes.db"
  ~arg:(fun r -> Set_string r)
  ~str
  ~def:"Color scheme database"

let pattern_database = add_argument
  ~lbl:"--pattern-database"
  ~ini:"patterns.db"
  ~arg:(fun r -> Set_string r)
  ~str
  ~def:"Pattern database"

let backcolor = add_argument
  ~lbl:"--backcolor"
  ~ini:"#000000"
  ~arg:(fun r -> Set_string r)
  ~str
  ~def:"Background color of the universe"

let cell_states = add_argument
  ~lbl:"--cell-states"
  ~ini:180
  ~arg:(fun r -> Set_int r)
  ~str:string_of_int
  ~def:"Number of cell states"
  
let nrows = add_argument
  ~lbl:"--rows"
  ~ini:220 (* 120 *)
  ~arg:(fun r -> Set_int r)
  ~str:string_of_int
  ~def:"Number of rows of the universe"

let ncols = add_argument
  ~lbl:"--columns"
  ~ini:400 (* 170 *)
  ~arg:(fun r -> Set_int r)
  ~str:string_of_int
  ~def:"Number of columns of the universe"

let speed = add_argument
  ~lbl:"--speed"
  ~ini:30.0
  ~arg:(fun r -> Set_float r)
  ~str:(sprintf "%.0f")
  ~def:"Duration, in milliseconds, between two generations"

let seed = add_argument
  ~lbl:"--seed"
  ~ini:2000
  ~arg:(fun r -> Set_int r)
  ~str:string_of_int
  ~def:"Number of random activation of cells"

let plugin_folder = add_argument
  ~lbl:"--plugin-folder"
  ~ini:"resources/plugins"
  ~arg:(fun r -> Set_string r)
  ~str
  ~def:"Path to plugin folder"

let prototyping = add_argument
  ~lbl:"--prototyping"
  ~ini:false
  ~arg:(fun r -> Set r)
  ~str:string_of_bool
  ~def:"Load prototyping models instead of ordinary cellular automata"

let save_as_png = add_argument
  ~lbl:"--save-as-png"
  ~ini:false
  ~arg:(fun r -> Set r)
  ~str:string_of_bool
  ~def:"Save frames as PNG images"

let print_stats = add_argument
  ~lbl:"--print-stats"
  ~ini:false
  ~arg:(fun r -> Set r)
  ~str:string_of_bool
  ~def:"Print statistics on elapsed time"

let string_of_plugin_args args =
  match args with
  | [] -> "none"
  | xs ->
      xs
      |> List.map (fun (k, v) -> sprintf "%s=%s" k v)
      |> String.concat ","

let add_plugin_arg plugin_args s =
  match String.index_opt s '=' with
  | None ->
      raise (Bad (sprintf "Invalid plugin argument %S. Expected KEY=VALUE." s))
  | Some i ->
      let key = String.sub s 0 i |> String.trim in
      let value =
        String.sub s (i + 1) (String.length s - i - 1)
        |> String.trim
      in
      if key = "" then
        raise (Bad (sprintf "Invalid plugin argument %S. Empty key." s))
      else
        plugin_args := (key, value) :: !plugin_args

let plugin_args = add_argument
  ~lbl:"--keyval"
  ~ini:[]
  ~arg:(fun r -> String (add_plugin_arg r))
  ~str:string_of_plugin_args
  ~def:"KEY=VALUE argument passed to the selected plugin"

let args = Arg.align [
  snd color_scheme;
  snd color_scheme_database;
  snd pattern_database;
  snd backcolor;
  snd cell_states;
  snd nrows; 
  snd ncols;
  snd speed;
  snd seed;
  snd plugin_folder;
  snd prototyping;
  snd save_as_png;
  snd print_stats;
  snd plugin_args
]

let color_scheme = fst color_scheme
let color_scheme_database = fst color_scheme_database
let pattern_database = fst pattern_database
let backcolor = fst backcolor
let cell_states = fst cell_states
let nrows = fst nrows
let ncols = fst ncols
let speed = fst speed
let seed = fst seed
let plugin_folder = fst plugin_folder
let prototyping = fst prototyping
let save_as_png = fst save_as_png
let print_stats = fst print_stats
let plugin_args = fst plugin_args
