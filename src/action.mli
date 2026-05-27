(*  action.mli
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


(** Software conductor. This module implements key functions to synchronize the
  * cellular automaton internal matrix and the user interface. It relies on
  * module [Draw] for drawing functions, module [GUI] for display and to
  * retrive the cellular automata modules added by plugins. *)

val initialize_interface : unit -> unit
(** Loads plugins, initialize cellular automata, color schemes lists and 
  * drawing functions. *)
