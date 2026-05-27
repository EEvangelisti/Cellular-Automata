(*  gUI.mli
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


(** User interface. It is rather minimalist and consists in a small window for 
  * quick modification of the most important settings. All settings can be 
  * modified at startup using the command line interface. *)

val app_name : string
  (** Application name. *)

val main_window : GWindow.window
  (** Main window. *)

val display : GWindow.window
  (** Tool window to display the cellular automaton. *)

(** Combo box for cellular automata. *)
module Automaton : sig
  val combo_box : GEdit.combo_box
  (** Cellular automata list. *)
  val add : family:string -> name:string -> unit
    (** Adds an automaton. *)
  val set_active : family:string -> name:string -> unit
    (** Defines the active automaton. *)
  val get_active : unit -> string
    (** Returns the active automaton. *)
end

val ca_seed : GEdit.spin_button
  (** Value used as seed for random selection of living cells. *)

val ca_speed : GEdit.spin_button
  (** Duration, in milliseconds, between two generations.
    * ##Default value: 80 ms. *)

val ca_save_as_png : GButton.toggle_button
  (** Indicates whether the successive states are saved as PNG files. *)

(** Combo box for color schemes. *)
module ColorScheme : sig
  val combo_box : GEdit.combo_box
    (** Color scheme selector. *)
  val add : string -> string array -> unit
    (** Adds a new color scheme. *) 
  val set_active : string -> unit
    (** Sets the active color scheme. *)
  val get_active : unit -> string array
    (** Returns the color table of the active color scheme. *)
end

val backcolor : GButton.color_button
  (** Background color. *)

val get_backcolor : unit -> string
  (** Returns the background color in the format ["#abcdef"]. *)

val run : GButton.button
  (** Run the current cellular automaton (see module [Automaton] above). *)

val pause : GButton.toggle_button
  (** Suspend the execution. *)

val clear : GButton.button
  (** Save the selected rows. *)

val save : GButton.button
  (** Paste the selected rows. *)

val status : string -> unit
  (** Message to display to the status bar. *)

val toolbox : Draw.drawing_toolbox option ref
  (** Drawing toolbox used to draw on the GUI. *)

val make_drawing_toolbox : 
  draw:(Draw.drawing_toolbox -> Cairo.context -> bool) -> 
  button_press:(Draw.drawing_toolbox -> GdkEvent.Button.t -> bool) -> unit
  (** Initialization function. *)
  
val exec_with_toolbox : (Draw.drawing_toolbox -> 'a) -> 'a
  (** [exec_with_toolbox f] executes function [f] if a drawing toolbox is 
    * available. *)
