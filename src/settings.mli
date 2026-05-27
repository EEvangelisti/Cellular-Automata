(*  settings.mli
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

 
(** Application settings. *)

val args : (Arg.key * Arg.spec * Arg.doc) list
  (** List of available command line arguments. *)

val set_automaton : string -> unit
  (** Sets the name of the initially active cellular automaton. This function
    * is used to take into account anonymous arguments in [Arg.parse]. *)

val automaton : string ref
  (** Name of the initially active cellular automaton. *)

val color_scheme : string ref
  (** Color scheme used for multi-color cell state. *)

val color_scheme_database : string ref
  (** Color scheme database. *)

val pattern_database : string ref
  (** Pattern database. *)

val backcolor : string ref
  (** Background color. *)

val cell_states : int ref
  (** Number of cell states. *)

val nrows : int ref
  (** Number of rows. *)

val ncols : int ref
  (** Number of columns. *)

val speed : float ref
  (** Cellular automaton speed. *)

val seed : int ref
  (** Size of the seed used to initialize the automaton. *)
  
val plugin_folder : string ref
  (** Path to plugin folder. *)

val prototyping : bool ref
  (** Indicates whether only prototyping models should be listed. *)

val save_as_png : bool ref
  (** Indicates whether successive frames should be saved as PNG files. *)
  
val print_stats : bool ref
  (** Prints statistics on elapsed time. *)
