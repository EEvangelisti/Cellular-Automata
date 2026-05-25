(*  gUI.ml
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

let app_name = "Automates 2.0"
let usage_msg = "Usage: automates [OPTIONS] [AUTOMATON]"

let _ = Arg.parse Settings.args Settings.set_automaton usage_msg

let main_window =
  GMain.init ();
  let wnd = GWindow.window
    ~title:app_name
    ~resizable:false
    ~position:`CENTER () in
  wnd#connect#destroy ~callback:GMain.quit;
  wnd

let spacing = 2
let border_width = 2

let vbox = GPack.vbox
  ~spacing
  ~border_width
  ~packing:main_window#add ()

let table = GPack.table
  ~border_width
  ~row_spacings:spacing
  ~col_spacings:spacing
  ~homogeneous:true
  ~packing:(vbox#pack ~expand:false) ()


module Automaton = struct
  let cols = new GTree.column_list
  let family = cols#add Gobject.Data.string
  let name = cols#add Gobject.Data.string
  let model = GTree.list_store cols

  let family_cell = GTree.cell_renderer_text [
    `FONT "Monospace 10"; `SCALE `SMALL; `WEIGHT `BOLD; 
    `FOREGROUND "#909090"; `WIDTH 40]
  let name_cell = GTree.cell_renderer_text [`XPAD 5]
  
  let combo_box = 
    let combo = GEdit.combo_box ~model
      ~packing:(table#attach ~left:0 ~top:0 ~expand:`X) () in
    combo#pack family_cell;
    combo#add_attribute family_cell "text" family;
    combo#pack name_cell;
    combo#add_attribute name_cell "text" name;
    combo

  let add ~family:x ~name:y =
    let row = model#append () in
    model#set ~row ~column:family x;
    model#set ~row ~column:name y

  let set_active ~family:x ~name:y =
    model#foreach (fun _ row -> 
      let family = model#get ~row ~column:family
      and name = model#get ~row ~column:name in
      let found = family = x && name = y in 
      if found then combo_box#set_active_iter (Some row);
      found)

  let get_active () = 
    match combo_box#active_iter with
    | None -> assert false (* Never happens. *)
    | Some row -> let get = model#get ~row in
      sprintf "%s/%s" (get ~column:family) (get ~column:name)
end


let main_hbox = GPack.hbox 
  ~spacing:5
  ~packing:(table#attach ~left:1 ~top:0 ~expand:`X) ()

let hbox = GPack.hbox
  ~spacing:5
  ~width:60
  ~packing:main_hbox#add ()

let adjustment = GData.adjustment
  ~lower:1.0 
  ~upper:1_000_000.
  ~page_size:0.
  ~value:2000. ()

let ca_seed = GEdit.spin_button
  ~adjustment
  ~numeric:true
  ~update_policy:`IF_VALID
  ~value:(float !Settings.seed)
  ~packing:hbox#add ()

let hbox = GPack.hbox
  ~spacing:5
  ~width:60
  ~packing:main_hbox#add ()

let adjustment = GData.adjustment
  ~lower:5.0 
  ~upper:500.
  ~page_size:0.
  ~value:80. ()

let ca_speed = GEdit.spin_button
  ~adjustment
  ~numeric:true
  ~update_policy:`IF_VALID
  ~value:!Settings.speed
  ~packing:hbox#add ()

module ColorScheme = struct
  let columns = new GTree.column_list
  let name = columns#add Gobject.Data.string
  let scheme = columns#add Gobject.Data.gobject
  let scheme_colors = columns#add Gobject.Data.caml
  let model = GTree.list_store columns
  let scheme_cell = GTree.cell_renderer_pixbuf [`WIDTH 40]
  let name_cell = GTree.cell_renderer_text [`XPAD 5]
  let combo_box = 
    let combo = GEdit.combo_box ~model
      ~packing:(table#attach ~left:0 ~top:1 ~expand:`X) () in
    combo#pack scheme_cell;
    combo#add_attribute scheme_cell "pixbuf" scheme;
    combo#pack name_cell;
    combo#add_attribute name_cell "text" name;
    combo
  let add id colors =
    let row = model#append () in
    model#set ~row ~column:name id;
    model#set ~row ~column:scheme_colors colors;

    let width = 40 in
    let height = 15 in
    let surface = Cairo.Image.create Cairo.Image.ARGB32 ~w:width ~h:height in
    let t = Cairo.create surface in
    let w = float width /. float (Array.length colors) in

    Array.iteri
      (fun i clr ->
         Cairo.rectangle t (float i *. w) 0. ~w ~h:(float height);
         let red, green, blue = Tools.(rgb_of_string clr |> ratios_of_rgb) in
         Cairo.set_source_rgb t red green blue;
         Cairo.fill t)
      colors;
    let tmp = Filename.temp_file "automates_color_scheme_" ".png" in
    Cairo.PNG.write surface tmp;
    let dest = GdkPixbuf.from_file tmp in
    Sys.remove tmp;
    model#set ~row ~column:scheme dest
  let set_active str =
    model#foreach (fun _ row -> 
      let name = model#get ~row ~column:name in
      let found = name = str in 
      if found then combo_box#set_active_iter (Some row);
      found)
  let get_active () = 
    match combo_box#active_iter with
    | None -> assert false (* Never happens. *)
    | Some row -> model#get ~row ~column:scheme_colors
end

let backcolor = GButton.color_button
  ~color:(GDraw.color (`NAME !Settings.backcolor)) 
  ~packing:(table#attach ~left:1 ~top:1 ~expand:`X) ()

let get_backcolor () =
  let gdk = backcolor#color in
  let open Gdk.Color in
  Tools.string_of_rgb (red gdk lsr 8) (green gdk lsr 8) (blue gdk lsr 8)

(* Vidéos avec:
 ffmpeg -i 'IMG_%06d.png' -r 25 -c:v libx264 -crf 20 -pix_fmt yuv420p img.mov *)
let ca_save_as_png = GButton.check_button
  ~active:!Settings.save_as_png
  ~label:"Enregistrer des images PNG"
  ~packing:(table#attach ~left:0 ~top:2 ~expand:`X) ()

let button_box = GPack.button_box `HORIZONTAL
  ~layout:`EDGE
  ~packing:(table#attach ~left:1 ~top:2 ~expand:`X) ()

let button_with_stock ?tooltip ~stock () =
  let btn = GButton.button ~packing:(button_box#pack ~expand:false) () in
  Gaux.may ~f:btn#misc#set_tooltip_markup tooltip;
  GMisc.image ~stock ~packing:btn#set_image ();
  btn
  
let pause =
  let btn = GButton.toggle_button ~packing:(button_box#pack ~expand:false) () in
  btn#misc#set_tooltip_markup "<b>Interrompre</b> l'exécution du programme";
  GMisc.image ~stock:`MEDIA_PAUSE ~packing:btn#set_image ();
  btn

let clear = button_with_stock ~stock:`DELETE ()
let save = button_with_stock ~stock:`SAVE ()

let run = GButton.button
  ~label:"Lancer l'automate cellulaire"
  ~packing:(table#attach ~left:0 ~top:3 ~expand:`X) ()

let display = 
  let wnd = GWindow.window
    ~title:app_name
    ~width:1800 ~height:1000 (* 900 x 700 *)
    ~resizable:false
    ~position:`NONE () in
  (* This window should not be removed. *)
  wnd#event#connect#delete ~callback:(fun _ -> true);
  main_window#connect#destroy ~callback:wnd#destroy;
  wnd

let vbox = GPack.vbox ~packing:display#add ()

let scroll = GBin.scrolled_window
  ~hpolicy:`NEVER 
  ~vpolicy:`NEVER
  ~border_width
  ~packing:vbox#add ()

let status = 
  let obj = GMisc.statusbar ~packing:(vbox#pack ~expand:false) () in
  let context = obj#new_context ~name:"speed" in
  (fun s -> context#push s; ())

let toolbox = ref None

let make_drawing_toolbox ~draw:f ~button_press:g =
  let fg = GMisc.drawing_area ~packing:scroll#add_with_viewport () in

  fg#event#add [`BUTTON_PRESS];

  ignore
    (fg#event#connect#button_press
       ~callback:(fun ev ->
         match !toolbox with
         | None -> false
         | Some dt -> g dt ev));

  ignore
    (fg#misc#connect#draw
       ~callback:(fun cr ->
         match !toolbox with
         | None -> false
         | Some dt -> f dt cr));

  let make_toolbox {Gtk.width; height} =
    let bg = Cairo.Image.create Cairo.Image.ARGB32 ~w:width ~h:height in
    let t = Cairo.create bg in
    let dt = Draw.{fg; bg; width; height; t} in
    toolbox := Some dt;
    display#misc#realize ();
    Draw.init ~backcolor:(get_backcolor ()) dt
  in

  ignore (fg#misc#connect#size_allocate ~callback:make_toolbox)

let exec_with_toolbox f =
  match !toolbox with
  | None -> invalid_arg "GUI.exec_with_toolbox"
  | Some toolbox -> f toolbox
