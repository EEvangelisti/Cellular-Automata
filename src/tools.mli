(*  tools.mli
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
 
(** Auxiliary functions. These functions are additions to the standard library
  * that proved useful when writing the application and are shared by all 
  * modules. *)
 
val read_file : string -> string
  (** Reads the given text file. *)

val nlines : string -> string list
  (** Splits the given text line by line. *)
  
val ncommas : string -> string list
  (** Splits the given text at every comma. *)

val nspaces : string -> string list
  (** Splits the given text at every space (['\032']). *)

val rgb_of_string : string -> int * int * int
  (** [rgb_of_string "#ffffff"] returns [(255, 255, 255)]. *)

val ratios_of_rgb : int * int * int -> float * float * float
  (** [ratios_of_rgb 255 255 255] returns [(1.0, 1.0, 1.0)]. *)

val string_of_rgb : int -> int -> int -> string
  (** [string_of_rgb 255 255 255] returns ["#ffffff"]. *)
