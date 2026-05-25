(*  draw.mli
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

(** Drawing functions. This module uses Cairo to print cells on the screen. To
  * achieve good performances, all possible cells are created once with good 
  * antialiasing and then simply painted where appropriate. *)

type drawing_toolbox = {
  t : Cairo.context;
  width : int;
  height : int;
  fg : GMisc.drawing_area;
  bg : Cairo.Surface.t;
}

val border_width : int ref

val synchronize : drawing_toolbox -> unit
  (**  *)

val draw : drawing_toolbox -> Cairo.context -> bool
  (**  *)

val init : backcolor:string -> drawing_toolbox -> unit
  (** Draw background and sets antialiasing and so on. *)

val populate :
  ?sync:bool ->
  ?save_as:string -> 
  states:int -> 
  backcolor:string ->
  color_scheme:string array -> 
  drawing_toolbox -> Plugin.cell Plugin.matrix -> unit
  (** Draw the current state of the universe and, if needed, saves it. *)

val highlight :
  ?sync:bool -> 
  states:int -> 
  backcolor:string ->
  color_scheme:string array -> 
  drawing_toolbox -> 
  Plugin.cell Plugin.matrix -> (int * int) list -> unit
  (** Highlight a group of cells. *)
