(* ca_hyphae.ml - Toy hyphal growth cellular automaton *)

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

  let max_age = max 1 (min 254 P.max_age)
  let states = max 2 (min 255 (max_age + 1))

  let import = Plugin.import
  let export = Plugin.export

  let check_row, check_col =
    Plugin.move_functions ~rows:P.n_rows ~columns:P.n_cols

  (* Internal state of the automaton.

     The visible matrix only stores display states.
     Biological information such as tip/body status, angle, and branching
     competence is stored here.
  *)
  let agents : agent XYMap.t ref = ref XYMap.empty

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

  let matrix_of_agents () =
    let mat = Array.make_matrix P.n_rows P.n_cols Plugin.f000 in
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

  let create ?zone ~seed () =
    Random.self_init ();
    agents := XYMap.empty;

    for _ = 1 to seed do
      let r = Random.int P.n_rows in
      let c = Random.int P.n_cols in
      let coord = (r, c) in
      if not (XYMap.mem coord !agents) then
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
     internal state. All visible cells are treated as tips with random
     directions. This is intentionally conservative for a toy model.
  *)
  let reconstruct_if_needed mat =
    if XYMap.is_empty !agents then begin
      Array.iteri
        (fun r row ->
           Array.iteri
             (fun c (_, chr) ->
                if chr <> '\000' then
                  let age = max 0 (Char.code chr - 1) in
                  agents :=
                    XYMap.add (r, c)
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

  let try_grow old_agents new_agents_ref (r, c) a =
    if a.tip && Random.float 1.0 < P.growth_prob then begin
      let dr, dc = offset_of_angle a.angle in
      let target = wrap_coord (r + dr, c + dc) in

      if not (XYMap.mem target !new_agents_ref) then begin
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
        (* Collision or boundary: the tip stops. *)
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

      if not (XYMap.mem target !new_agents_ref) then begin
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
           XYMap.add coord (age_agent a) acc)
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

let make_module ~growth ~branch ~age ~dirs ~wiggle ~jitter ~max_age =
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
  end
  in
  (module Make(P) : Plugin.AUTOMATON)

let db_file = Filename.concat !Settings.plugin_folder "ca_hyphae_rules.db"

let _ =
  List.iter
    (fun ca_line ->
       let ca_line = String.trim ca_line in
       if ca_line <> "" && ca_line.[0] <> '#' then
         sscanf ca_line " AUTOMATON %S: G%f/B%f/A%d/D%d/W%d/J%d/M%d"
           (fun id growth branch age dirs wiggle jitter max_age ->
              let mdl =
                make_module
                  ~growth
                  ~branch
                  ~age
                  ~dirs
                  ~wiggle
                  ~jitter
                  ~max_age
              in
              Hashtbl.add Plugin.ca_database
                (Filename.concat "HYPHA" id)
                mdl))
    Tools.(nlines (String.trim (read_file db_file)))
