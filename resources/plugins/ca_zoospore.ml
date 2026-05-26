(* ca_zoospore.ml - Plugin file
 *
 * Toy model for swimming Phytophthora zoospores.
 *
 * Rules:
 * - a zoospore is a motile agent with an internal swimming angle;
 * - at each cycle it moves one or two cells, with a strongly right-skewed
 *   bounded speed distribution;
 * - the previous position becomes empty;
 * - upon collision, the zoospore remains in place and changes angle by at
 *   least a user-defined angle, typically 30 degrees;
 * - in the absence of collision, the swimming angle persists for an average
 *   user-defined number of cycles, typically 12.
 *)

open Scanf

module type PARAMS =
 sig
  val n_rows : int
  val n_cols : int

  (* Number of internal angular states.
     With D360, one internal unit is one degree. *)
  val n_dirs : int

  (* Probability of moving two cells instead of one.
     Since speed is bounded in [1; 2], the exact mean is 1 + fast_prob.
     Use a small value, e.g. F0.05 to F0.20, to stay close to one cell/cycle
     while retaining a strongly right-skewed tail. *)
  val fast_prob : float

  (* Small angular noise during free swimming, in internal angular units. *)
  val wiggle : int

  (* Average number of cycles before spontaneous reorientation. *)
  val persistence : int

  (* Minimal reorientation angle after collision, in degrees. *)
  val min_turn_deg : int

  (* Display age range. Use M1 for visually uniform zoospores. *)
  val max_age : int
 end

module Make (P : PARAMS) : Plugin.AUTOMATON =
 struct
  module XYMap = Plugin.XYMap

  type zoospore = {
    age : int;
    angle : int;
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

  (* Strongly right-skewed bounded speed distribution.
     Most zoospores move one cell; a small minority move two cells.
     This is the only possible skewed distribution if the speed is discrete,
     strictly positive, and bounded by two cells/cycle. *)
  let speed () =
    let p = max 0.0 (min 1.0 P.fast_prob) in
    if Random.float 1.0 < p then 2 else 1

  let display_cell age =
    let code = 1 + min max_age age in
    (true, Char.chr code)

  let matrix_of_agents ?old_agents () =
    let mat = Array.make_matrix P.n_rows P.n_cols Plugin.f000 in

    (* Important for motile agents:
       positions occupied in the previous generation but empty now must be
       explicitly redrawn as dead cells. Otherwise Draw.populate will not
       refresh them, and apparent trajectories remain on screen. *)
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

  let shuffle a =
    for i = Array.length a - 1 downto 1 do
      let j = Random.int (i + 1) in
      let tmp = a.(i) in
      a.(i) <- a.(j);
      a.(j) <- tmp
    done

  let inside_initial_circle (r, c) =
    let cx = float P.n_cols /. 2.0 in
    let cy = float P.n_rows /. 2.0 in

    (* Circle occupying roughly one quarter of the grid area.
       Area circle = pi r²
       Area grid / 4 = rows * cols / 4
       therefore r = sqrt(rows * cols / (4 pi)). *)
    let pi = acos(-1.0) in
    let radius =
      sqrt (float (P.n_rows * P.n_cols) /. (8.0 *. pi))
    in

    let dx = float c +. 0.5 -. cx in
    let dy = float r +. 0.5 -. cy in

    dx *. dx +. dy *. dy <= radius *. radius

  let create ?zone ~seed () =
    Random.self_init ();
    agents := XYMap.empty;

    let coords = ref [] in
    for r = 0 to P.n_rows - 1 do
      for c = 0 to P.n_cols - 1 do
        if allowed_by_zone zone (r, c) && inside_initial_circle (r, c) then
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
          }
          !agents
    done;

    matrix_of_agents ()

  let reconstruct_if_needed mat =
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
                      }
                      !agents)
             row)
        mat
    end

  let age_agent a =
    { a with age = min max_age (a.age + 1) }

  let target_after_steps occupied_old occupied_new origin angle steps =
    let dr, dc = offset_of_angle angle in

    let rec loop coord k =
      if k = 0 then Some coord
      else
        let r, c = coord in
        let next = wrap_coord (r + dr, c + dc) in

        (* A zoospore collides if the next position is occupied in the
           previous configuration, or if another zoospore has already claimed
           it in the new configuration. The origin itself is ignored. *)
        let occupied =
          (next <> origin && XYMap.mem next occupied_old)
          || XYMap.mem next !occupied_new
        in

        if occupied then None
        else loop next (k - 1)
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
         let angle = spontaneous_angle a.angle in
         let steps = speed () in

         match target_after_steps old_agents new_agents coord angle steps with
         | Some target ->
             new_agents :=
               XYMap.add target { a with angle } !new_agents

         | None ->
             (* Collision: no displacement, previous position stays occupied,
                but the swimming angle is strongly reoriented. *)
             if not (XYMap.mem coord !new_agents) then
               new_agents :=
                 XYMap.add coord
                   { a with angle = collision_angle angle }
                   !new_agents)
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
                (Filename.concat "ZOOSP" id)
                mdl))
    Tools.(nlines (String.trim (read_file db_file)))
