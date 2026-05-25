(*  tools.ml
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
 
let read_file str =
  let ich = open_in str in
  let len = in_channel_length ich in
  let buf = Buffer.create len in
  Buffer.add_channel buf ich len;
  close_in ich;
  Buffer.contents buf

let split_at pat = Str.split (Str.regexp_case_fold pat)
let nlines = split_at "\n"
let ncommas = split_at ","
let nspaces = split_at " "

let rgb_of_string s = sscanf s "#%2x%2x%2x" (fun r g b -> r, g, b)
let ratios_of_rgb (r, g, b) = float r /. 255., float g /. 255., float b /. 255.
let string_of_rgb = sprintf "#%02x%02x%02x"
