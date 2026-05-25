(*  automates.ml
 *  Copyright (C) 2014, 2015, 2016, 2017 Edouard Evangelisti
 * 
 *  This file is part of Automates (OCaml Cellular Automata).
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

let main () =
  Action.initialize_interface ();
  GUI.display#show ();
  GUI.main_window#show ();
  GMain.main ()

let _ =
  Printexc.record_backtrace true;
  try main () with exn -> Printexc.print_backtrace stderr; raise exn  
