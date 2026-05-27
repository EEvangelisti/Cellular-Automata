(*  draw.ml
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


open Scanf
open Printf

type drawing_toolbox = {
  t : Cairo.context;
  width : int;
  height : int;
  fg : GMisc.drawing_area;
  bg : Cairo.Surface.t;
}

type graph_params = {
  xr: float; 
  yr: float; 
  sq_size: int; 
  radius: float;
  circles: Cairo.Surface.t array;
  highlight: Cairo.Surface.t;
}

let border_width = ref 5
let gradient_colors = ref [||]

let parse_color s = Tools.(rgb_of_string s |> ratios_of_rgb)

module Gradient = struct
  let sub (r1, g1, b1) (r2, g2, b2) n =
    let dr = (r1 -. r2) /. float n 
    and dg = (g1 -. g2) /. float n
    and db = (b1 -. b2) /. float n in
    let gr = Array.make n (r2, g2, b2) in
    for i = 1 to n - 2 do
      let r, g, b = gr.(i - 1) in
      gr.(i) <- (r +. dr, g +. dg, b +. db)
    done;
    gr.(n - 1) <- (r1, g1, b1);
    gr
  let make ~states ~color_scheme () =
    let clr = Array.map parse_color color_scheme in
    let len = Array.length clr in 
    if states > len then (     
      let n = states / (len - 1) in
      let rec loop res m i =
        if i < len - 1 then (
          let c1 = clr.(len - i - 1) and c2 = clr.(len - i - 2) in
          (if m > 0 then n + 1 else n)
            |> sub c1 c2
            |> (fun x -> loop (x :: res) (m - 1) (i + 1))
        ) else Array.concat res
      in loop [] (states mod (len - 1)) 0
    ) else Array.sub clr 0 states
end

(* Creates gradient only once. *)
let rec get_state_color = ref (fun ~states ~color_scheme s ->
  gradient_colors := Gradient.make ~states ~color_scheme ();
  get_state_color := (fun ~states:_ ~color_scheme:_ s -> 
    Array.get !gradient_colors s);
  !gradient_colors.(s)
)

let init_get_state_color = !get_state_color

let set_rgb cairo clr =
  let red, green, blue = parse_color clr in
  Cairo.set_source_rgb cairo red green blue

let select_gradient_color ~states ~color_scheme cairo n =
  let red, green, blue = !get_state_color ~states ~color_scheme (n - 1) in
  Cairo.set_source_rgb cairo red green blue

let synchronize {width; height; fg; _} =
  fg#misc#queue_draw_area 0 0 width height

let draw d cr =
  Cairo.set_source_surface cr d.bg ~x:0. ~y:0.;
  Cairo.paint cr;
  false

let fresh_background backcolor t w h =
  set_rgb t backcolor;
  Cairo.rectangle t 0. 0. ~w ~h;
  Cairo.fill t;
  Cairo.stroke t

let pi = acos (-1.0)
let a1 = 0.0
let a2 = 2.0 *. pi

let draw_circles ~states ~backcolor ~color_scheme rad =
  let open Cairo in
  let d = 2 * truncate rad + 1 in
  let rec loop res = function
    | 0 -> Array.of_list res
    | i -> let j = i - 1 in
      let s = Cairo.Image.create Cairo.Image.RGB24 ~w:d ~h:d in
      let t = Cairo.create s in
      set_rgb t backcolor;
      set_antialias t ANTIALIAS_SUBPIXEL;
      rectangle t 0. 0. ~w:(float d) ~h:(float d);
      fill t;
      if j = 0 then set_rgb t backcolor
      else select_gradient_color ~states ~color_scheme t j;
      arc t rad rad ~r:rad ~a1 ~a2;
      fill t;
      stroke t;
      loop (s :: res) j
  in loop [] (states + 1)
  
let draw_highlight_circle ~backcolor rad =
  let open Cairo in
  let d = 2 * truncate rad + 1 in
  let s = Cairo.Image.create Cairo.Image.RGB24 ~w:d ~h:d in
  let t = create s in
  set_rgb t backcolor;
  set_antialias t ANTIALIAS_SUBPIXEL;
  rectangle t 0. 0. ~w:(float d) ~h:(float d);
  fill t;
  set_source_rgb t 0.0 1.0 0.0;
  arc t rad rad ~r:rad ~a1 ~a2;
  fill t;
  stroke t;
  s

let rec get_params = ref (fun ~states ~backcolor ~color_scheme d ->
  let w_unit = (d.width - !border_width lsl 1) / !Settings.ncols
  and h_unit = (d.height - !border_width lsl 1) / !Settings.nrows in
  let sq_size = min w_unit h_unit in
  let radius = float (sq_size lsr 1) in
  let xr = float (d.width - sq_size * !Settings.ncols) /. 2. +. radius
  and yr = float (d.height - sq_size * !Settings.nrows) /. 2. +. radius in
  let circles = draw_circles ~states ~backcolor ~color_scheme radius in
  let highlight = draw_highlight_circle ~backcolor radius in
  let res = {xr; yr; sq_size; radius; circles; highlight} in
  get_params := (fun ~states:_ ~backcolor:_ ~color_scheme:_ _ -> res);
  res
)

let init_get_params = !get_params

let clear_cell ~backcolor d x y ~w ~h =
  Cairo.save d.t;
  Cairo.set_operator d.t Cairo.SOURCE;
  set_rgb d.t backcolor;
  Cairo.rectangle d.t x y ~w ~h;
  Cairo.fill d.t;
  Cairo.restore d.t

let populate ?(sync = true) ?save_as ~states ~backcolor ~color_scheme d mat =
  let {xr; yr; sq_size; radius; circles; _} = !get_params 
    ~states 
    ~backcolor 
    ~color_scheme d in
  Array.iteri (fun r -> Array.iteri (fun c (modi, chr) ->
    if modi then begin
      mat.(r).(c) <- (false, snd mat.(r).(c)); (* No more change required. *)
      let x = xr +. float (c * sq_size) -. radius
      and y = yr +. float (r * sq_size) -. radius in

      clear_cell ~backcolor d x y
        ~w:(float sq_size +. 1.)
        ~h:(float sq_size +. 1.);

      if chr <> '\000' then begin
        Cairo.set_source_surface d.t circles.(Char.code chr) ~x ~y;
        Cairo.paint d.t
      end
    end
  )) mat;
  Cairo.stroke d.t;
  Gaux.may ~f:(Cairo.PNG.write (Cairo.get_target d.t)) save_as;
  if sync then synchronize d

let highlight ?(sync = true) ~states ~backcolor ~color_scheme d mat t =
  let {xr; yr; sq_size; radius; highlight; _} = !get_params 
      ~states 
      ~backcolor 
      ~color_scheme d in
  List.iter (fun (r, c) -> 
    let x = xr +. float (c * sq_size)
    and y = yr +. float (r * sq_size) in
    mat.(r).(c) <- (true, snd mat.(r).(c));
    Cairo.set_source_surface d.t highlight ~x ~y;
    Cairo.paint d.t
  ) t;
  Cairo.stroke d.t;
  if sync then synchronize d

let init ~backcolor toolbox =
  let open Cairo in
  set_antialias toolbox.t ANTIALIAS_NONE;
  stroke toolbox.t;
  set_operator toolbox.t OVER;
  fresh_background backcolor toolbox.t 
    (float toolbox.width) 
    (float toolbox.height);
  (* Reinitialize the functions for use with the new automaton. *)
  get_params := init_get_params;
  get_state_color := init_get_state_color;
  synchronize toolbox
