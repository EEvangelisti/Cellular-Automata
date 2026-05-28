(*  plugin.mli
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


(** Auxiliary functions for plugins. This module implements a set of convenient
  * functions to assist the development of new plugins for cellular automata. *)

type cell = bool * char
  (** Cells are implemented as chars with a boolean flag to indicate whether
    * they need to be drawn again. *)

type 'a matrix = 'a array array
  (** The type of the universe used to run the automaton. *)

val f000 : cell
  (** Dead cell that does not require update. *)

val t000 : cell
  (** Dead cell that requires update. *)

val f001 : cell
  (** New born cell that does not require update. *)

val t001 : cell
  (** New born cell requires update. *)

val create_matrix : 
  ?init:int -> 
  ?zone:bool matrix ->
  rows:int -> 
  columns:int -> 
  seed:int -> unit -> cell matrix
  (** Matrix initialization. *)

val import : string -> cell matrix
  (** Standard import function. *)

val export : string -> cell matrix -> unit
  (** Standard export function. *)

val move_functions : rows:int -> columns:int -> (int -> int) * (int -> int)
  (** Returns the functions [check_row] and [check_col] that are used to 
    * connect the edges of the matrix. *)

val evolve : 
  (cell matrix -> int -> int -> cell -> cell) -> 
  cell matrix -> cell matrix
  (** Standard function to get the next generation of the given matrix. *)

val get_birth_rule : string -> int list
  (** Returns the list of cases where the current empty cell gets populated. *)

val get_death_rule : string -> int list
  (** Returns the list of cases where the current cell does not survive. *)


(** Interface shared by all cellular automata. *)
module type AUTOMATON =
  sig
    val n_rows : int
    val n_cols : int
    val states : int
    val prototyping : bool
    val import : string -> cell matrix
    val export : string -> cell matrix -> unit
    val check_row : int -> int
    val check_col : int -> int
    val create : ?zone:bool matrix -> seed:int -> unit -> cell matrix
    val evolve : cell matrix -> cell matrix
    val configure : name:string -> (string * string) list -> unit
  end

val ca_database : (string, (module AUTOMATON)) Hashtbl.t
  (** Cellular automata database, to be populated by plugins. *)
  
val get_names : ?prototyping:bool -> unit -> string list
  (** Returns the list of all available cellular automata. *)
  
module XYSet : Set.S with type elt = int * int
  (** Sets with coordinate keys. *)

module XYMap : Map.S with type key = int * int
  (** Maps with coordinate keys. *)

(** {2 Argument parsing } *)
module Args : sig
  type t = (string * string) list
  val get : t -> string -> default:string -> string
  val get_int : t -> string -> default:int -> int
  val get_float : t -> string -> default:float -> float
  val get_bool : t -> string -> default:bool -> bool
end

(** {2 Coordinates and torus structure } *)
module Coord : sig
  type t = int * int
  (** Grid coordinate: row, column. *)

  val wrap : rows:int -> columns:int -> t -> t
  val in_bounds : rows:int -> columns:int -> t -> bool
  val uses_torus : rows:int -> columns:int -> t -> bool

  val add : t -> t -> t
  val sub : t -> t -> t
  val scale : int -> t -> t

  val raw_move : t -> t -> t
  val move : rows:int -> columns:int -> t -> t -> t
  val move_with_torus_flag :
    rows:int -> columns:int -> t -> t -> t * bool

  val cell_center : t -> float * float
  val row : t -> int
  val column : t -> int
  val to_string : t -> string
end


