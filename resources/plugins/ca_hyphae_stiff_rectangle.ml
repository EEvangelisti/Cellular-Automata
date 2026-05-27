(* ca_hyphae.ml - Toy hyphal growth cellular automaton
   Version with a stiff rectangular obstacle / barrier.
*)

open Scanf

module type PARAMS =
sig
  val n_rows : int
  val n_cols : int

  val growth_prob : float
  val branch_prob : float

  val branch_age : int
  val n_dirs : int
  val wiggle : int
  val branch_jitter : int
  val max_age : int
  val max_stiffness : int
end

module Make (P : PARAMS) : Plugin.AUTOMATON =
struct
  module XYMap = Plugin.XYMap

  type agent = {
    age : int;
    angle : int;
    tip : bool;
    can_branch : bool;
  }

  let n_rows = P.n_rows
  let n_cols = P.n_cols

  (* Reserve display state 255 for stiff obstacle cells.
     Hyphae therefore use 1..254 at most. *)
  let obstacle_chr = Char.chr 255
  let obstacle_stiffness = P.max_stiffness

  let max_age = max 1 (min 253 P.max_age)
  let states = 256

  let import = Plugin.import
  let export = Plugin.export

  let check_row, check_col =
    Plugin.move_functions ~rows:P.n_rows ~columns:P.n_cols

  (* Internal state of the automaton.

     The visible matrix only stores display states.
     Biological information such as tip/body status, angle, branching
     competence, and substrate stiffness is stored here.
  *)
  let agents : agent XYMap.t ref = ref XYMap.empty

  (* Stiffness is deliberately numeric rather than boolean.
     stiffness = 0 means freely colonizable.
     stiffness = 10 is treated as non-colonizable by default.
     Intermediate values can later be used for gradients or probabilistic
     penetration. *)
  let stiffness : int XYMap.t ref = ref XYMap.empty

  let in_bounds r c =
    r >= 0 && r < P.n_rows && c >= 0 && c < P.n_cols

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

  (* Convert a fine-grained angle to a Moore direction, stochastically.

     Example: if the angle lies 25% of the way between E and NE, choose
     E with probability 75% and NE with probability 25%.

     This avoids perfectly straight 8-direction trajectories while keeping
     the universe grid-based.
  *)
  let moore_dir_of_angle angle =
    let n = max 8 P.n_dirs in
    let a = normalize_angle angle in
    let x = a * 8 in
    let d0 = (x / n) mod 8 in
    let rem = x mod n in
    if Random.int n < rem then (d0 + 1) mod 8 else d0

  let offset_of_angle angle =
    moore.(moore_dir_of_angle angle)

  let quarter_turn () =
    let n = max 8 P.n_dirs in
    n / 4

  let branch_angle angle =
    let side = if Random.bool () then quarter_turn () else - quarter_turn () in
    normalize_angle (angle + side + random_signed P.branch_jitter)

  let display_cell age =
    let code = 1 + min max_age age in
    (true, Char.chr code)

  let display_obstacle_cell =
    (* Uses a state absent from the hyphal age palette. *)
    (true, obstacle_chr)

  let stiffness_at coord =
    try XYMap.find coord !stiffness
    with Not_found -> 0

  let can_colonize coord =
    let s = stiffness_at coord in
    if s <= 0 then true
    else
      let max_s = max 1 P.max_stiffness in
      let resistance = min 1.0 (float_of_int s /. float_of_int max_s) in
      Random.float 1.0 >= resistance

  let matrix_of_agents () =
    let mat = Array.make_matrix P.n_rows P.n_cols Plugin.f000 in

    (* Draw stiff substrate first. *)
    XYMap.iter
      (fun (r, c) s ->
         if in_bounds r c && s > 0 then
           mat.(r).(c) <- display_obstacle_cell)
      !stiffness;

    (* Draw hyphae. In normal use, agents never occupy stiff cells. *)
    XYMap.iter
      (fun (r, c) a ->
         if in_bounds r c then
           mat.(r).(c) <- display_cell a.age)
      !agents;

    mat

  let add_agent coord agent map =
    XYMap.add coord agent map

  let update_agent coord f map =
    try
      let a = XYMap.find coord map in
      XYMap.add coord (f a) map
    with Not_found -> map

  let inhibit coord map =
    update_agent coord (fun a -> { a with can_branch = false }) map

  let add_stiff coord value map =
    XYMap.add coord value map

  let remove_stiff coord map =
    XYMap.remove coord map

  let create_obstacle_rectangle () =
    stiffness := XYMap.empty;

    (* Large central rectangle. *)
    let rect_h = max 8 (P.n_rows * 55 / 100) in
    let rect_w = max 8 (P.n_cols * 55 / 100) in
    let top = (P.n_rows - rect_h) / 2 in
    let left = (P.n_cols - rect_w) / 2 in
    let bottom = top + rect_h - 1 in
    let right = left + rect_w - 1 in

    (* Border thickness: 2 or 3 cells. *)
    let thickness = 2 + Random.int 2 in

    (* Build a rectangular wall/ring. *)
    for r = top to bottom do
      for c = left to right do
        let near_top = r - top < thickness in
        let near_bottom = bottom - r < thickness in
        let near_left = c - left < thickness in
        let near_right = right - c < thickness in
        if near_top || near_bottom || near_left || near_right then
          stiffness := add_stiff (r, c) obstacle_stiffness !stiffness
      done
    done;

    (* Carve random holes of length 4-5 cells through the wall.
       The hole crosses the full border thickness. *)
    let n_holes = max 4 ((P.n_rows + P.n_cols) / 35) in

    let carve_top len c0 =
      for r = top to min bottom (top + thickness - 1) do
        for c = c0 to min right (c0 + len - 1) do
          stiffness := remove_stiff (r, c) !stiffness
        done
      done
    in
    let carve_bottom len c0 =
      for r = max top (bottom - thickness + 1) to bottom do
        for c = c0 to min right (c0 + len - 1) do
          stiffness := remove_stiff (r, c) !stiffness
        done
      done
    in
    let carve_left len r0 =
      for r = r0 to min bottom (r0 + len - 1) do
        for c = left to min right (left + thickness - 1) do
          stiffness := remove_stiff (r, c) !stiffness
        done
      done
    in
    let carve_right len r0 =
      for r = r0 to min bottom (r0 + len - 1) do
        for c = max left (right - thickness + 1) to right do
          stiffness := remove_stiff (r, c) !stiffness
        done
      done
    in

    for _ = 1 to n_holes do
      let len = 4 + Random.int 2 in
      match Random.int 4 with
      | 0 ->
          let span = max 1 (rect_w - len - 2 * thickness) in
          let c0 = left + thickness + Random.int span in
          carve_top len c0
      | 1 ->
          let span = max 1 (rect_w - len - 2 * thickness) in
          let c0 = left + thickness + Random.int span in
          carve_bottom len c0
      | 2 ->
          let span = max 1 (rect_h - len - 2 * thickness) in
          let r0 = top + thickness + Random.int span in
          carve_left len r0
      | _ ->
          let span = max 1 (rect_h - len - 2 * thickness) in
          let r0 = top + thickness + Random.int span in
          carve_right len r0
    done

  let create ?zone ~seed () =
    Random.self_init ();
    agents := XYMap.empty;
    create_obstacle_rectangle ();

    for _ = 1 to seed do
      let r = Random.int P.n_rows in
      let c = Random.int P.n_cols in
      let coord = (r, c) in
      if (not (XYMap.mem coord !agents)) && can_colonize coord then
        agents :=
          XYMap.add coord
            {
              age = 0;
              angle = Random.int (max 8 P.n_dirs);
              tip = true;
              can_branch = true;
            }
            !agents
    done;

    matrix_of_agents ()

  (* If a matrix is imported or externally provided, reconstruct a minimal
     internal state. Obstacle cells are reconstructed as stiffness = 10.
     All visible hyphal cells are treated as tips with random directions.
     This is intentionally conservative for a toy model.
  *)
  let reconstruct_if_needed mat =
    if XYMap.is_empty !stiffness then begin
      Array.iteri
        (fun r row ->
           Array.iteri
             (fun c (_, chr) ->
                if chr = obstacle_chr then
                  stiffness :=
                    XYMap.add (r, c) obstacle_stiffness !stiffness)
             row)
        mat
    end;

    if XYMap.is_empty !agents then begin
      Array.iteri
        (fun r row ->
           Array.iteri
             (fun c (_, chr) ->
                if chr <> '\000' && chr <> obstacle_chr then
                  let age = max 0 (Char.code chr - 1) in
                  let coord = (r, c) in
                  if can_colonize coord then
                    agents :=
                      XYMap.add coord
                        {
                          age = min max_age age;
                          angle = Random.int (max 8 P.n_dirs);
                          tip = true;
                          can_branch = true;
                        }
                        !agents)
             row)
        mat
    end

  let age_agent a =
    {
      a with
      age = min max_age (a.age + 1);
      angle = if a.tip then drift_angle a.angle else a.angle;
    }

  let try_grow _old_agents new_agents_ref (r, c) a =
    if a.tip && Random.float 1.0 < P.growth_prob then begin
      let dr, dc = offset_of_angle a.angle in
      let target = wrap_coord (r + dr, c + dc) in

      if (not (XYMap.mem target !new_agents_ref)) && can_colonize target then begin
        (* The old tip becomes a non-tip segment. *)
        new_agents_ref :=
          update_agent (r, c)
            (fun x -> { x with tip = false })
            !new_agents_ref;

        (* A new apical tip is created. *)
        new_agents_ref :=
          add_agent target
            {
              age = 0;
              angle = a.angle;
              tip = true;
              can_branch = true;
            }
            !new_agents_ref
      end
      else begin
        (* Collision, stiff substrate, or failed penetration: the tip stops. *)
        new_agents_ref :=
          update_agent (r, c)
            (fun x -> { x with tip = false })
            !new_agents_ref
      end
    end

  let try_branch _old_agents new_agents_ref (r, c) a =
    if a.can_branch
       && a.age >= P.branch_age
       && Random.float 1.0 < P.branch_prob
    then begin
      let bangle = branch_angle a.angle in
      let dr, dc = offset_of_angle bangle in
      let target = wrap_coord (r + dr, c + dc) in

      if (not (XYMap.mem target !new_agents_ref)) && can_colonize target then begin
        (* Create branch tip. *)
        new_agents_ref :=
          add_agent target
            {
              age = 0;
              angle = bangle;
              tip = true;
              can_branch = true;
            }
            !new_agents_ref;

        (* Mother cell cannot branch again. *)
        new_agents_ref :=
          inhibit (r, c) !new_agents_ref;

        (* Inhibit adjacent cells along the two lateral directions relative to
           the mother axis. This prevents unrealistically adjacent branches. *)
        let a1 = normalize_angle (a.angle + quarter_turn ()) in
        let a2 = normalize_angle (a.angle - quarter_turn ()) in
        let dr1, dc1 = offset_of_angle a1 in
        let dr2, dc2 = offset_of_angle a2 in

        new_agents_ref :=
          inhibit (wrap_coord (r + dr1, c + dc1)) !new_agents_ref;
        new_agents_ref :=
          inhibit (wrap_coord (r + dr2, c + dc2)) !new_agents_ref
      end
    end

  let evolve mat =
    reconstruct_if_needed mat;

    (* First pass: every living cell persists and ages. *)
    let old_agents = !agents in
    let new_agents =
      XYMap.fold
        (fun coord a acc ->
           (* Defensive filter: remove any agent that would have ended up
              inside non-colonizable substrate after import or editing. *)
           if can_colonize coord then
             XYMap.add coord (age_agent a) acc
           else acc)
        old_agents
        XYMap.empty
    in
    let new_agents_ref = ref new_agents in

    (* Second pass: old tips grow; old enough cells may branch. *)
    XYMap.iter
      (fun coord old_a ->
         let current_a =
           try XYMap.find coord !new_agents_ref
           with Not_found -> age_agent old_a
         in

         try_grow old_agents new_agents_ref coord current_a;

         let current_a =
           try XYMap.find coord !new_agents_ref
           with Not_found -> current_a
         in
         try_branch old_agents new_agents_ref coord current_a)
      old_agents;

    agents := !new_agents_ref;
    matrix_of_agents ()
end

let make_module ~growth ~branch ~age ~dirs ~wiggle ~jitter ~max_age ~max_stiffness =
  let module P =
  struct
    let n_rows = !Settings.nrows
    let n_cols = !Settings.ncols
    let growth_prob = growth
    let branch_prob = branch
    let branch_age = age
    let n_dirs = dirs
    let wiggle = wiggle
    let branch_jitter = jitter
    let max_age = max_age
    let max_stiffness = max_stiffness
  end
  in
  (module Make(P) : Plugin.AUTOMATON)

let db_file = Filename.concat !Settings.plugin_folder "ca_hyphae_stiff_rectangle_rules.db"

let _ =
  List.iter
    (fun ca_line ->
       let ca_line = String.trim ca_line in
       if ca_line <> "" && ca_line.[0] <> '#' then
         sscanf ca_line " AUTOMATON %S: G%f/B%f/A%d/D%d/W%d/J%d/M%d/S%d"
           (fun id growth branch age dirs wiggle jitter max_age max_stiffness ->
              let mdl =
                make_module
                  ~growth
                  ~branch
                  ~age
                  ~dirs
                  ~wiggle
                  ~jitter
                  ~max_age
                  ~max_stiffness
              in
              Hashtbl.add Plugin.ca_database
                (Filename.concat "STIFF" id)
                mdl))
    Tools.(nlines (String.trim (read_file db_file)))
