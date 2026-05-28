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
open Printf

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
  module Args = Plugin.Args
  module Coord = Plugin.Coord
  module Moore = Plugin.Moore

  type zoospore = {
    id : int;
    age : int;
    angle : int;

    (* Tracking metadata.  Each zoospore receives its own acquisition
       window so that trajectories are sampled over time rather than all
       starting at t = 0. *)
    track_start : int;
    track : (int * float * float) list;

    (* True as soon as one recorded transition has crossed a periodic
       boundary.  Such trajectories are excluded from tracks.xml because the
       Python analysis would otherwise interpret the toric jump as a very long,
       biologically implausible displacement. *)
    track_wrapped : bool;
  }

  let n_rows = P.n_rows
  let n_cols = P.n_cols
  let n_dirs = max 8 P.n_dirs
  let check_row, check_col = Plugin.move_functions ~rows:n_rows ~columns:n_cols
  let prototyping = true

  let max_age = max 1 (min 255 P.max_age)
  let states = max_age + 1

  let import = Plugin.import
  let export = Plugin.export

  let agents : zoospore XYMap.t ref = ref XYMap.empty

  (* Trajectory export --------------------------------------------------

     The companion Python script expects an XML file containing one <particle>
     element per trajectory and <detection t=... x=... y=.../> children.
     Coordinates are exported as cell centres: x = column + 0.5,
     y = row + 0.5.

     With [track_length = 20], [track_stride = 6] and [track_end_max = 1000],
     every exported trajectory has 20 detections sampled every six internal
     model cycles.

     If you want 20 full exported displacements rather than 20 recorded
     positions, set [track_length] to 21.

     Trajectories that cross a periodic boundary during their acquisition
     window, including between two exported frames, are deliberately not
     exported. *)

  let automaton_name = ref ""

  let default_track_length = 20
  let default_track_stride = 6
  let default_track_end_max = 1000
  let default_tracks_file = "tracks.xml"

  let track_length = ref default_track_length
  let track_stride = ref default_track_stride
  let track_end_max = ref default_track_end_max
  let tracks_file = ref default_tracks_file
  let save_tracks = ref false

  let generation = ref 0
  let next_agent_id = ref 0
  let warned_write_failure = ref false

  let require_positive name x =
    if x <= 0 then
      invalid_arg (sprintf "Invalid value for %s: %d. Expected a positive integer." name x)

  let configure ~name opts =
    automaton_name := name;

    save_tracks :=
      Args.get_bool opts "SAVE_TRACKS" ~default:false;

    track_length :=
      Args.get_int opts "TRACK_LENGTH" ~default:default_track_length;

    track_stride :=
      Args.get_int opts "TRACK_STRIDE" ~default:default_track_stride;

    track_end_max :=
      Args.get_int opts "TRACK_END_MAX" ~default:default_track_end_max;

    require_positive "TRACK_LENGTH" !track_length;
    require_positive "TRACK_STRIDE" !track_stride;
    require_positive "TRACK_END_MAX" !track_end_max;

    tracks_file :=
      Args.get opts "TRACKS_FILE"
        ~default:
          (sprintf "Tracks_%s_len%d_stride%d_end%d.xml"
             !automaton_name
             !track_length
             !track_stride
             !track_end_max)

  let track_span () =
    (!track_length - 1) * !track_stride

  let latest_track_start () =
    max 0 (!track_end_max - track_span ())

  let track_start_for_index total i =
    if total <= 1 then 0
    else (i * latest_track_start ()) / (total - 1)

  let track_is_complete a =
    List.length a.track >= !track_length

  let last_track_cycle a =
    a.track_start + track_span ()

  let transition_belongs_to_track cycle a =
    (* Even when only one frame out of [track_stride] is exported, a toric
       crossing occurring between two exported frames would produce an
       artefactual jump in the apparent trajectory.  We therefore invalidate
       the whole trajectory if any transition crosses a periodic boundary
       inside the acquisition window. *)
    cycle > a.track_start
    && cycle <= last_track_cycle a

  let should_record cycle a =
    cycle >= a.track_start
    && cycle <= last_track_cycle a
    && (cycle - a.track_start) mod !track_stride = 0
    && not (List.exists (fun (t, _, _) -> t = cycle) a.track)

  let record_tracks cycle =
    agents :=
      XYMap.fold
        (fun coord a acc ->
           let a =
             if should_record cycle a then
               let x, y = Coord.cell_center coord in
               { a with track = (cycle, x, y) :: a.track }
             else
               a
           in
           XYMap.add coord a acc)
        !agents
        XYMap.empty

  let write_tracks_xml () =
    try
      let oc = open_out !tracks_file in
      begin
        try
          output_string oc "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
          output_string oc "<Tracks>\n";

          XYMap.iter
            (fun _ a ->
               if track_is_complete a && not a.track_wrapped then begin
                 fprintf oc
                   "  <particle id=\"%d\" start=\"%d\" wrapped=\"false\">\n"
                   a.id
                   a.track_start;

                 List.iter
                   (fun (t, x, y) ->
                      fprintf oc
                        "    <detection t=\"%d\" x=\"%.6f\" y=\"%.6f\"/>\n"
                        t
                        x
                        y)
                   (List.rev a.track);

                 output_string oc "  </particle>\n"
               end)
            !agents;

          output_string oc "</Tracks>\n";
          close_out oc
        with e ->
          close_out_noerr oc;
          raise e
      end
    with e ->
      if not !warned_write_failure then begin
        warned_write_failure := true;
        prerr_endline
          ("Could not write " ^ !tracks_file ^ ": " ^ Printexc.to_string e)
      end

  let normalize_angle angle =
    Moore.normalize_angle ~dirs:n_dirs angle

  let offset_of_angle angle =
    Moore.offset_of_angle ~dirs:n_dirs angle

  let random_angle () =
    Random.int n_dirs

  let random_signed amplitude =
    if amplitude <= 0 then 0
    else Random.int (2 * amplitude + 1) - amplitude

  let drift_angle angle =
    normalize_angle (angle + random_signed P.wiggle)

  let min_turn_units () =
    max 1 ((n_dirs * max 0 P.min_turn_deg) / 360)

  let collision_angle angle =
    let min_turn = min (n_dirs / 2) (min_turn_units ()) in
    let span = max 1 (n_dirs - 2 * min_turn + 1) in
    let delta = min_turn + Random.int span in
    normalize_angle (angle + delta)

  let spontaneous_angle angle =
    let persistence = max 1 P.persistence in
    if Random.int persistence = 0 then
      random_angle ()
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

  let inside_initial_circle (r, c) =
    let cx = float P.n_cols /. 2.0 in
    let cy = float P.n_rows /. 2.0 in

    (* Circle occupying roughly one eighth of the grid area.
       Area circle = pi r²
       Area grid / 8 = rows * cols / 8
       therefore r = sqrt(rows * cols / (8 pi)). *)
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
    generation := 0;
    next_agent_id := 0;
    warned_write_failure := false;

    let coords = ref [] in
    for r = 0 to P.n_rows - 1 do
      for c = 0 to P.n_cols - 1 do
        if allowed_by_zone zone (r, c) && inside_initial_circle (r, c) then
          coords := (r, c) :: !coords
      done
    done;

    let coords = Array.of_list !coords in
    Plugin.shuffle_array coords;

    let n = min seed (Array.length coords) in
    for i = 0 to n - 1 do
      let id = !next_agent_id in
      incr next_agent_id;
      agents :=
        XYMap.add coords.(i)
          {
            id = id;
            age = 0;
            angle = random_angle ();
            track_start = track_start_for_index n i;
            track = [];
            track_wrapped = false;
          }
          !agents
    done;

    if !save_tracks then begin
      record_tracks !generation;
      write_tracks_xml ()
    end;
    matrix_of_agents ()

  let reconstruct_if_needed mat =
    if XYMap.is_empty !agents then begin
      let cells = ref [] in
      Array.iteri
        (fun r row ->
           Array.iteri
             (fun c (_, chr) ->
                if chr <> '\000' then
                  cells := ((r, c), max 0 (Char.code chr - 1)) :: !cells)
             row)
        mat;

      let cells = Array.of_list !cells in
      let total = Array.length cells in
      Array.iteri
        (fun i (coord, age) ->
           let id = !next_agent_id in
           incr next_agent_id;
           agents :=
             XYMap.add coord
               {
                 id = id;
                 age = age;
                 angle = random_angle ();
                 track_start = track_start_for_index total i;
                 track = [];
                 track_wrapped = false;
               }
               !agents)
        cells
    end

  let age_agent a =
    { a with age = min max_age (a.age + 1) }

  let target_after_steps occupied_old occupied_new origin angle steps =
    let offset = offset_of_angle angle in

    let rec loop coord k =
      if k = 0 then Some (coord, false)
      else
        let next, used_torus =
          Coord.move_with_torus_flag
            ~rows:P.n_rows
            ~columns:P.n_cols
            coord
            offset
        in

        (* A zoospore collides if the next position is occupied in the
           previous configuration, or if another zoospore has already claimed
           it in the new configuration. The origin itself is ignored. *)
        let occupied =
          (next <> origin && XYMap.mem next occupied_old)
          || XYMap.mem next !occupied_new
        in

        if occupied then None
        else
          match loop next (k - 1) with
          | None -> None
          | Some (target, wrapped_later) ->
              Some (target, used_torus || wrapped_later)
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

    Plugin.shuffle_array items;

    let next_generation = !generation + 1 in

    Array.iter
      (fun (coord, a0) ->
         let a = age_agent a0 in
         let angle = spontaneous_angle a.angle in
         let steps = speed () in

         match target_after_steps old_agents new_agents coord angle steps with
         | Some (target, used_torus) ->
             let track_wrapped =
               a.track_wrapped
               || (used_torus && transition_belongs_to_track next_generation a)
             in
             new_agents :=
               XYMap.add target
                 { a with angle = angle; track_wrapped = track_wrapped }
                 !new_agents

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
    incr generation;
    if !save_tracks then begin
      record_tracks !generation;
      if !generation <= !track_end_max then
        write_tracks_xml ();
    end;
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
                ("ZOOSP-" ^ id)
                mdl))
    Tools.(nlines (String.trim (read_file db_file)))
