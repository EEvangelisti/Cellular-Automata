(*  action.ml
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

  (* Will be used for saving purposes.
       and find_neighbors_boundaries set =
        match XYSet.elements set with
        | [] -> None
        | (r_ini, c_ini) :: rem -> 
          let rec loop r_min r_max c_min c_max = function
            | [] -> Some (r_min, r_max, c_min, c_max)
            | (r, c) :: rem -> loop (min r r_min) (max r r_max) (min c c_min) 
              (max c c_max) rem
          in loop r_ini r_ini c_ini c_ini rem   
      in find_neighbors_boundaries (loop r c) *)

open Scanf
open Printf

let counter = ref 0
let curr_ca = ref None

let with_ca_params f =
  match !curr_ca with
  | None -> invalid_arg "Action.with_ca_params"
  | Some dat -> GUI.exec_with_toolbox (f dat)

let is_running = ref true
let curr_timeout = ref None


module Selection = struct
  open Plugin
  let set = ref XYSet.empty
  let has_elements () = not (XYSet.is_empty !set)
  (* Efface la sélection précédente en redessinant les cases précédemment 
   * sélectionnées avec leur couleur d'origine. *)
  let unselect (mdl, mat) box =
    if has_elements () then begin
      let module CA = (val mdl : Plugin.AUTOMATON) in
      Draw.populate 
        ~states:CA.states
        ~backcolor:(GUI.get_backcolor ())
        ~color_scheme:(GUI.ColorScheme.get_active ()) box mat
    end
  (* Identifie toutes les cases situées dans le voisinage de la case 
   * sélectionnée. Les cases sont identifiées de proche en proche en utilisant
   * le voisinage de Moore. *)
  let find_neighbors r c (mdl, mat) =
    set := (match snd mat.(r).(c) with
      | '\000' -> XYSet.empty
      | _      -> XYSet.singleton (r, c));
    let module CA = (val mdl : Plugin.AUTOMATON) in
    let rec loop r c =
      for ri = r - 1 to r + 1 do
        for cj = c - 1 to c + 1 do
          let ri = CA.check_row ri and cj = CA.check_col cj in
          if ri <> r || cj <> c then
            if snd mat.(ri).(cj) <> '\000' && not (XYSet.mem (ri, cj) !set) 
            then (set := XYSet.add (ri, cj) !set; loop ri cj)
        done
      done;
    in loop r c
  (* Surligne en vert les cases situées dans le voisinage de la case 
   * sélectionnée. Ces cases peuvent alors être copiées, sauvegardées, etc. *)
  let look_around r c (mdl, mat) box =
    unselect (mdl, mat) box;
    find_neighbors r c (mdl, mat);
    if has_elements () then begin
      let module CA = (val mdl : Plugin.AUTOMATON) in
      Draw.highlight
        ~states:CA.states
        ~backcolor:(GUI.get_backcolor ())
        ~color_scheme:(GUI.ColorScheme.get_active ()) 
        box mat (XYSet.elements !set)
    end
  (* Efface toutes les cellules qui ne sont pas surlignées. *)
  let clean_all (mdl, mat) box =
    if has_elements () then begin
      let module CA = (val mdl : Plugin.AUTOMATON) in
      Array.iteri (fun r -> Array.iteri (fun c _ ->
        if not (XYSet.mem (r, c) !set) then mat.(r).(c) <- (true, '\000')
      )) mat;
      Draw.populate 
        ~states:CA.states
        ~backcolor:(GUI.get_backcolor ())
        ~color_scheme:(GUI.ColorScheme.get_active ()) box mat;
      set := XYSet.empty
    end
end

(* Identification d'objets périodiques
1. Identifier tous les groupes de cellules de la matrice
2. Les isoler dans des matrices vides.
3. Stocker des versions normalisées (= ramener les coordonées à l'origine).
4. Boucle sur ?max=20 générations: 
  -> Passer à la génération suivante
  -> S'il n'y a plus de cellules vivantes, échouer
  -> Si on a passé <max> générations, échouer
  -> Sinon, identifier tous les groupes de cellules de la matrice
  -> Normaliser et comparer à la première génération
    -> Si c'est identique: un objet périodique a été identifié
    -> Sinon, boucler.
Nom de l'objet = concaténation de chaque état
string(état) = matrice avec 0 = dead, 1 = alive
FAMILY_AUTOMATON_<NOM DE L'OBJET> *)
module type SPACESHIP_FINDER = sig
  open Plugin
  val split_matrix : cell matrix -> cell XYMap.t list
  val is_spaceship : cell XYMap.t -> (module AUTOMATON) -> bool
end


(* Fonction de sélection de groupe de cellules. *)
let tmp_button_press box t =
  if not !is_running then begin
    let open Draw in
    let nr = !Settings.nrows and nc = !Settings.ncols in
    let w_unit = (box.width - !border_width lsl 1) / nc
    and h_unit = (box.height - !border_width lsl 1) / nr in
    let sq_size = float (min w_unit h_unit) in
    let dx = (float box.width -. sq_size *. float nc) /. 2.
    and dy = (float box.height -. sq_size *. float nr) /. 2. in
    let x = GdkEvent.Button.x t and y = GdkEvent.Button.y t in
    let r = max 0 (min (nr - 1) (truncate ((y -. dy) /. sq_size))) 
    and c = max 0 (min (nc - 1) (truncate ((x -. dx) /. sq_size))) in
    with_ca_params (Selection.look_around r c);
  end;
  false

let get_folder_name ca =
  let ca = Str.global_replace (Str.regexp "/") "_" ca in 
  let {Unix.tm_mday; tm_mon; tm_year; tm_hour; tm_min; tm_sec} = 
    Unix.localtime (Unix.time ())
  in sprintf "%s-%02d-%02d-%02d-%02d:%02d:%02d" ca tm_mday (tm_mon + 1) 
    (tm_year mod 100) tm_hour tm_min tm_sec

let print_elapsed_time ca x y =
  ksprintf GUI.status "%s (Calc %.1f ms, Disp %.1f ms)" ca x y;
  if !Settings.print_stats then printf "%.1f\t%.1f\n%!" x y

let may_save_as dir =
  if GUI.ca_save_as_png#active then (
    incr counter;
    if not Sys.(file_exists dir && is_directory dir) then Unix.mkdir dir 0o755;
    Some (sprintf "%s/IMG_%06d.png" dir !counter)
  ) else None

let one_pass ~folder ca_name (mdl, old) box =
  if !is_running then begin
    let module CA = (val mdl : Plugin.AUTOMATON) in
    let states = CA.states
    and backcolor = GUI.get_backcolor ()
    and color_scheme = GUI.ColorScheme.get_active () in
    if Selection.has_elements () then 
    Draw.populate ~sync:false ~states ~backcolor ~color_scheme box old;
    let x = Unix.gettimeofday () in
    let uni = CA.evolve old in
    let y = Unix.gettimeofday () in
    Draw.populate ?save_as:(may_save_as folder) 
      ~states ~backcolor ~color_scheme box uni;
    let z = Unix.gettimeofday () in
    print_elapsed_time ca_name (1000. *. (y -. x)) (1000. *. (z -. y));
    curr_ca := Some (mdl, uni)
  end;
  true

(* Crée un nouveau chronomètre pour le calcul des générations successives. *)
let update_timeout () =
  Gaux.may ~f:Glib.Timeout.remove !curr_timeout;
  counter := 0;
  let ca = GUI.Automaton.get_active () in
  let folder_base = get_folder_name ca in
  curr_timeout := Some (Glib.Timeout.add 
    ~ms:GUI.ca_speed#value_as_int
    ~callback:(fun () -> one_pass ~folder:folder_base ca |> with_ca_params)
  )

(* Charge toutes les extensions disponibles. *)
let load_plugins () =
  let dir = !Settings.plugin_folder in
  Array.iter (fun file ->
    if Filename.check_suffix file ".cmxs" then begin
      let path = Filename.concat dir file in
      printf "(Automates) Extension %s.\n%!" path;
      Dynlink.loadfile path  
    end
  ) (Sys.readdir dir) 

let scan_automaton s = sscanf s "%[^/]/%[^\n]" (fun x y -> x, y)

(* Remplit la liste déroulante avec le nom des automates cellulaires. *)
let populate_ca_combo_box () =
  let names = Plugin.get_names ~prototyping:!Settings.prototyping () in
  List.iter
    (fun ca ->
       let family, name = scan_automaton ca in
       GUI.Automaton.add ~family ~name)
    names;
  names

(* Remplit la liste déroulante avec les palettes de couleurs disponibles. *)
let populate_color_scheme_combo_box () =
  let ich = Scanning.open_in !Settings.color_scheme_database in
  let rec loop () =
    kscanf ich (fun _ _ -> Scanning.close_in ich) " %[^:] : %[#0-9A-Fa-f ]"
      (fun id colors -> String.trim colors 
        |> Tools.nspaces
        |> Array.of_list
        |> GUI.ColorScheme.add (String.trim id)
        |> loop)
  in loop ()    

(* Exécute un automate cellulaire à partir d'une distribution aléatoire. *)
let run_automaton () =
  GUI.exec_with_toolbox (fun box ->
    let mdl = Hashtbl.find Plugin.ca_database (GUI.Automaton.get_active ()) in
    let module M = (val mdl : Plugin.AUTOMATON) in
    let ini = M.create ~seed:(truncate GUI.ca_seed#value) () in
    curr_ca := Some (mdl, ini);
    let backcolor = GUI.get_backcolor () in
    Draw.init ~backcolor box;
    Draw.populate
      ~states:M.states
      ~backcolor
      ~color_scheme:(GUI.ColorScheme.get_active ())
      box ini;
    update_timeout ())

(* Charge les extensions, les automates cellulaires, les jeux de couleurs et
 * associe des fonctions aux boutons de l'interface graphique. *)
let initialize_interface () =
  load_plugins ();
  let automata = populate_ca_combo_box () in
  populate_color_scheme_combo_box ();

  let initial_automaton =
    if List.mem !Settings.automaton automata then
      !Settings.automaton
    else
      match automata with
      | ca :: _ -> ca
      | [] ->
          failwith
            (if !Settings.prototyping then
               "No prototyping model available."
             else
               "No ordinary cellular automaton available.")
  in

  let family, name = scan_automaton initial_automaton in
  GUI.Automaton.set_active ~family ~name;
  GUI.ColorScheme.set_active !Settings.color_scheme;
  GUI.run#connect#clicked
    ~callback:run_automaton; 
  GUI.pause#connect#toggled
    ~callback:(fun () -> is_running := not GUI.pause#active);
  GUI.clear#connect#clicked ~callback:(fun () -> with_ca_params Selection.clean_all);
  GUI.make_drawing_toolbox ~draw:Draw.draw ~button_press:tmp_button_press
