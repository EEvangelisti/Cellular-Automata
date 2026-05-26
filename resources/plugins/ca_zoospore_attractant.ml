(* ca_zoospore_attractant.ml - Plugin file
 *
 * Toy model for swimming Phytophthora zoospores with chemotaxis.
 *
 * Additions relative to ca_zoospore_fixed.ml:
 * - initial zoospores are placed in a centered circle occupying about one
 *   quarter of the grid area;
 * - an attractive substance is defined internally in a circular region in the
 *   upper-right part of the grid;
 * - each zoospore samples the substance within a radius of five cells;
 * - if the best perceived value is <= 10, it swims normally;
 * - if the best perceived value is > 10, it reorients toward the best cell;
 * - if the best perceived value is > 30, it enters an orbit around that cell,
 *   moving through the eight Moore-neighbor positions around the centre.
 *)

open Scanf

module type PARAMS =
 sig
  val n_rows : int
  val n_cols : int

  val n_dirs : int
  val fast_prob : float
  val wiggle : int
  val persistence : int
  val min_turn_deg : int
  val max_age : int
 end

module Make (P : PARAMS) : Plugin.AUTOMATON =
 struct
  module XYMap = Plugin.XYMap

  type orbit = {
    center : int * int;
    phase : int;
  }

  type zoospore = {
    age : int;
    angle : int;
    orbit : orbit option;
  }

  let n_rows = P.n_rows
  let n_cols = P.n_cols

  let max_age = max 1 (min 255 P.max_age)
  let states = max_age + 1

  let import = Plugin.import
  let export = Plugin.export

  let check_row, check_col =
    Plugin.move_functions ~rows:P.n_rows ~columns:P.n_cols

  let agents : zoospore XYMap.t ref = ref XYMap.empty

  (* Internal attractant field. It is not displayed; it only affects movement. *)
  let attractant : float array array ref =
    ref [||]

  let sniff_radius = 5
  let low_threshold = 10.0
  let high_threshold = 30.0

  let pi = acos (-1.0)

  let wrap x n =
    ((x mod n) + n) mod n

  let wrap_coord (r, c) =
    (wrap r P.n_rows, wrap c P.n_cols)

  let normalize_angle a =
    let n = max 8 P.n_dirs in
    ((a mod n) + n) mod n

  let random_signed amplitude =
    if amplitude <= 0 then 0
    else Random.int (2 * amplitude + 1) - amplitude

  let drift_angle angle =
    normalize_angle (angle + random_signed P.wiggle)

  (* Moore directions, using mathematical angles:
       0 = E
       1 = NE
       2 = N
       3 = NW
       4 = W
       5 = SW
       6 = S
       7 = SE
     Rows increase downwards, hence N = -1 row.
  *)
  let moore = [|
    ( 0,  1);  (* E  *)
    (-1,  1);  (* NE *)
    (-1,  0);  (* N  *)
    (-1, -1);  (* NW *)
    ( 0, -1);  (* W  *)
    ( 1, -1);  (* SW *)
    ( 1,  0);  (* S  *)
    ( 1,  1);  (* SE *)
  |]

  (* Ring order around a central cell. This makes the zoospore visit the
     eight surrounding cells cyclically. *)
  let orbit_ring = [|
    (-1,  0);  (* N  *)
    (-1,  1);  (* NE *)
    ( 0,  1);  (* E  *)
    ( 1,  1);  (* SE *)
    ( 1,  0);  (* S  *)
    ( 1, -1);  (* SW *)
    ( 0, -1);  (* W  *)
    (-1, -1);  (* NW *)
  |]

  let moore_dir_of_angle angle =
    let n = max 8 P.n_dirs in
    let a = normalize_angle angle in
    let x = a * 8 in
    let d0 = (x / n) mod 8 in
    let rem = x mod n in
    if Random.int n < rem then (d0 + 1) mod 8 else d0

  let offset_of_angle angle =
    moore.(moore_dir_of_angle angle)

  let min_turn_units () =
    max 1 ((max 8 P.n_dirs * max 0 P.min_turn_deg) / 360)

  let collision_angle angle =
    let n = max 8 P.n_dirs in
    let min_turn = min (n / 2) (min_turn_units ()) in
    let span = max 1 (n - 2 * min_turn + 1) in
    let delta = min_turn + Random.int span in
    normalize_angle (angle + delta)

  let spontaneous_angle angle =
    let persistence = max 1 P.persistence in
    if Random.int persistence = 0 then
      Random.int (max 8 P.n_dirs)
    else
      drift_angle angle

  let angle_of_delta dr dc =
    let n = max 8 P.n_dirs in
    let x = float dc in
    let y = -. float dr in
    let a = atan2 y x in
    let a = if a < 0.0 then a +. 2.0 *. pi else a in
    normalize_angle (int_of_float ((a /. (2.0 *. pi)) *. float n +. 0.5))

  let speed () =
    let p = max 0.0 (min 1.0 P.fast_prob) in
    if Random.float 1.0 < p then 2 else 1

  let display_cell age =
    let code = 1 + min max_age age in
    (true, Char.chr code)

  let create_attractant_field () =
    let field = Array.make_matrix P.n_rows P.n_cols 0.0 in

    (* Upper-right attractant source. *)
    let center_r = P.n_rows / 5 in
    let center_c = (4 * P.n_cols) / 5 in

    (* Radius of the source circle. *)
    let radius = max 3 (min P.n_rows P.n_cols / 8) in
    let sigma = max 1.0 (float radius /. 2.0) in

    (* Spatial Gaussian: values are >10 over most of the source and >30 near
       the centre. Outside the circle, the field is exactly zero. *)
    let edge = 10.0 in
    let peak = 40.0 in

    for r = 0 to P.n_rows - 1 do
      for c = 0 to P.n_cols - 1 do
        let dr = float (r - center_r) in
        let dc = float (c - center_c) in
        let d2 = dr *. dr +. dc *. dc in
        if d2 <= float (radius * radius) then begin
          let g = exp (-. d2 /. (2.0 *. sigma *. sigma)) in
          field.(r).(c) <- edge +. (peak -. edge) *. g
        end
      done
    done;

    attractant := field

  let attractant_at (r, c) =
    if Array.length !attractant = 0 then 0.0
    else !attractant.(r).(c)

  let sniff coord =
    let r0, c0 = coord in
    let best_value = ref 0.0 in
    let best_coord = ref coord in
    let best_delta = ref (0, 0) in

    for dr = -sniff_radius to sniff_radius do
      for dc = -sniff_radius to sniff_radius do
        if dr * dr + dc * dc <= sniff_radius * sniff_radius then begin
          let coord' = wrap_coord (r0 + dr, c0 + dc) in
          let v = attractant_at coord' in
          if v > !best_value then begin
            best_value := v;
            best_coord := coord';
            best_delta := (dr, dc)
          end
        end
      done
    done;

    (!best_value, !best_coord, !best_delta)

  let nearest_orbit_phase center coord =
    let cr, cc = center in
    let best_phase = ref 0 in
    let best_d2 = ref max_int in

    Array.iteri
      (fun i (dr, dc) ->
         let r, c = wrap_coord (cr + dr, cc + dc) in
         let d2 =
           let rr = r - fst coord in
           let cc = c - snd coord in
           rr * rr + cc * cc
         in
         if d2 < !best_d2 then begin
           best_d2 := d2;
           best_phase := i
         end)
      orbit_ring;

    !best_phase

  let orbit_target center phase =
    let dr, dc = orbit_ring.(phase mod 8) in
    let cr, cc = center in
    wrap_coord (cr + dr, cc + dc)

  let next_orbit_move coord orbit =
    let phase =
      if coord = orbit_target orbit.center orbit.phase then
        (orbit.phase + 1) mod 8
      else
        nearest_orbit_phase orbit.center coord
    in
    (orbit_target orbit.center phase, { orbit with phase })

  let matrix_of_agents ?old_agents () =
    let mat = Array.make_matrix P.n_rows P.n_cols Plugin.f000 in

    begin
      match old_agents with
      | None -> ()
      | Some old ->
          XYMap.iter
            (fun coord _ ->
               if not (XYMap.mem coord !agents) then
                 let r, c = coord in
                 mat.(r).(c) <- Plugin.t000)
            old
    end;

    XYMap.iter
      (fun (r, c) a ->
         mat.(r).(c) <- display_cell a.age)
      !agents;

    mat

  let allowed_by_zone zone (r, c) =
    match zone with
    | None -> true
    | Some t ->
        r >= 0
        && r < Array.length t
        && c >= 0
        && c < Array.length t.(r)
        && t.(r).(c)

  let inside_initial_circle (r, c) =
    let cx = float P.n_cols /. 2.0 in
    let cy = float P.n_rows /. 2.0 in

    (* Circle occupying roughly one quarter of the grid area. *)
    let radius =
      sqrt (float (P.n_rows * P.n_cols) /. (4.0 *. pi))
    in

    let dx = float c +. 0.5 -. cx in
    let dy = float r +. 0.5 -. cy in
    dx *. dx +. dy *. dy <= radius *. radius

  let shuffle a =
    for i = Array.length a - 1 downto 1 do
      let j = Random.int (i + 1) in
      let tmp = a.(i) in
      a.(i) <- a.(j);
      a.(j) <- tmp
    done

  let create ?zone ~seed () =
    Random.self_init ();
    agents := XYMap.empty;
    create_attractant_field ();

    let coords = ref [] in
    for r = 0 to P.n_rows - 1 do
      for c = 0 to P.n_cols - 1 do
        if allowed_by_zone zone (r, c)
           && inside_initial_circle (r, c)
        then
          coords := (r, c) :: !coords
      done
    done;

    let coords = Array.of_list !coords in
    shuffle coords;

    let n = min seed (Array.length coords) in
    for i = 0 to n - 1 do
      agents :=
        XYMap.add coords.(i)
          {
            age = 0;
            angle = Random.int (max 8 P.n_dirs);
            orbit = None;
          }
          !agents
    done;

    matrix_of_agents ()

  let reconstruct_if_needed mat =
    if Array.length !attractant = 0 then
      create_attractant_field ();

    if XYMap.is_empty !agents then begin
      Array.iteri
        (fun r row ->
           Array.iteri
             (fun c (_, chr) ->
                if chr <> '\000' then
                  agents :=
                    XYMap.add (r, c)
                      {
                        age = max 0 (Char.code chr - 1);
                        angle = Random.int (max 8 P.n_dirs);
                        orbit = None;
                      }
                      !agents)
             row)
        mat
    end

  let age_agent a =
    match a.orbit with
    | None ->
        { a with age = 0 }
    | Some _ ->
        { a with age = min max_age (a.age + 1) }

  let target_available occupied_old occupied_new origin target =
    not
      ((target <> origin && XYMap.mem target occupied_old)
       || XYMap.mem target !occupied_new)

  let target_after_steps occupied_old occupied_new origin angle steps =
    let dr, dc = offset_of_angle angle in

    let rec loop coord k =
      if k = 0 then Some coord
      else
        let r, c = coord in
        let next = wrap_coord (r + dr, c + dc) in
        if target_available occupied_old occupied_new origin next then
          loop next (k - 1)
        else
          None
    in

    loop origin steps

  let evolve mat =
    reconstruct_if_needed mat;

    let old_agents = !agents in
    let new_agents = ref XYMap.empty in

    let items =
      XYMap.fold
        (fun coord a acc -> (coord, a) :: acc)
        old_agents
        []
      |> Array.of_list
    in

    shuffle items;

    Array.iter
      (fun (coord, a0) ->
         let a = age_agent a0 in

         match a.orbit with
         | Some orbit ->
             let target, orbit' = next_orbit_move coord orbit in
             if target_available old_agents new_agents coord target then
               new_agents :=
                 XYMap.add target { a with orbit = Some orbit' } !new_agents
             else if not (XYMap.mem coord !new_agents) then
               new_agents :=
                 XYMap.add coord
                   { a with angle = collision_angle a.angle; orbit = None }
                   !new_agents

         | None ->
             let value, best_coord, (dr, dc) = sniff coord in

             if value > high_threshold then begin
               let phase = nearest_orbit_phase best_coord coord in
               let orbit = { center = best_coord; phase } in
               let target, orbit' = next_orbit_move coord orbit in

               if target_available old_agents new_agents coord target then
                 new_agents :=
                  XYMap.add target
                    {
                      age = 1;
                      angle = angle_of_delta dr dc;
                      orbit = Some orbit';
                    }
                    !new_agents
               else if not (XYMap.mem coord !new_agents) then
                 new_agents :=
                   XYMap.add coord
                     {
                       a with
                       angle = collision_angle a.angle;
                       orbit = None;
                     }
                     !new_agents
             end
             else begin
               let angle =
                 if value > low_threshold then
                   angle_of_delta dr dc
                 else
                   spontaneous_angle a.angle
               in
               let steps = speed () in

               match target_after_steps old_agents new_agents coord angle steps with
               | Some target ->
                   new_agents :=
                     XYMap.add target { a with angle; orbit = None } !new_agents

               | None ->
                   if not (XYMap.mem coord !new_agents) then
                     new_agents :=
                       XYMap.add coord
                         { a with angle = collision_angle angle; orbit = None }
                         !new_agents
             end)
      items;

    agents := !new_agents;
    matrix_of_agents ~old_agents ()
 end

let make_module ~dirs ~fast ~wiggle ~persistence ~min_turn ~max_age =
  let module P =
   struct
    let n_rows = !Settings.nrows
    let n_cols = !Settings.ncols
    let n_dirs = dirs
    let fast_prob = fast
    let wiggle = wiggle
    let persistence = persistence
    let min_turn_deg = min_turn
    let max_age = max_age
   end
  in
  (module Make(P) : Plugin.AUTOMATON)

let db_file = Filename.concat !Settings.plugin_folder "ca_zoospore_rules.db"

let _ =
  List.iter
    (fun ca_line ->
       let ca_line = String.trim ca_line in
       if ca_line <> "" && ca_line.[0] <> '#' then
         sscanf ca_line " AUTOMATON %S: D%d/F%f/W%d/P%d/A%d/M%d"
           (fun id dirs fast wiggle persistence min_turn max_age ->
              let mdl =
                make_module
                  ~dirs
                  ~fast
                  ~wiggle
                  ~persistence
                  ~min_turn
                  ~max_age
              in
              Hashtbl.add Plugin.ca_database
                (Filename.concat "CHEMO" id)
                mdl))
    Tools.(nlines (String.trim (read_file db_file)))
