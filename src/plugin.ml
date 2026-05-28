(*  plugin.ml
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


type cell = bool * char
type 'a matrix = 'a array array

module type AUTOMATON =
 sig
  val n_rows : int
  val n_cols : int
  val states : int
  val prototyping : bool
  val import : string -> cell matrix
  val export : string -> cell matrix -> unit
  val check_row : int -> int
  val check_col : int -> int
  val create : ?zone:bool matrix -> seed:int -> unit -> cell matrix
  val evolve : cell matrix -> cell matrix
  val configure : name:string -> (string * string) list -> unit
 end

let f000 = (false, '\000')
let t000 = (true , '\000')
let f001 = (false, '\001')
let t001 = (true , '\001')

let create_matrix ?(init = 1) ?zone ~rows ~columns ~seed () =
  let mat = Array.make_matrix rows columns f000 in

  let f =
    match init with
    | 1 -> fun () -> '\001'
    | n -> fun () -> Char.chr (1 + Random.int (max 1 (n - 1)))
  in

  let allowed r c =
    match zone with
    | None -> true
    | Some t ->
        r < Array.length t
        && c < Array.length t.(r)
        && t.(r).(c)
  in

  let coords = ref [] in

  for r = 0 to rows - 1 do
    for c = 0 to columns - 1 do
      if allowed r c then
        coords := (r, c) :: !coords
    done
  done;

  let coords = Array.of_list !coords in
  let n = Array.length coords in

  Random.self_init ();

  (* Fisher-Yates shuffle. *)
  for i = n - 1 downto 1 do
    let j = Random.int (i + 1) in
    let tmp = coords.(i) in
    coords.(i) <- coords.(j);
    coords.(j) <- tmp
  done;

  let n_seed = min seed n in

  for i = 0 to n_seed - 1 do
    let r, c = coords.(i) in
    mat.(r).(c) <- (true, f ())
  done;

  mat

let import filename =
  let ich = open_in_bin filename in
  let mat : cell matrix = input_value ich in
  close_in ich;
  mat

let export filename mat =
  let och = open_out_bin filename in
  output_value och mat;
  close_out och

let move_functions ~rows ~columns =
  let rec check_row r = 
    if r < 0 then check_row (rows + r) else 
    if r >= rows then check_row (r - rows) else r
  and     check_col c = 
    if c < 0 then check_col (columns + c) else 
    if c >= columns then check_col (c - columns) else c
  in (check_row, check_col)

let evolve f mat = Array.(mapi (fun r -> mapi (f mat r)) mat)

let get_birth_rule s =
  let rec loop res = function
    | 0 -> res
    | i -> let j = i - 1 in
      loop (Char.code s.[j] - 48 :: res) j
  in loop [] (String.length s) 

let get_death_rule s =
  let rec loop res = function
    | 0 -> res
    | i -> let j = i - 1 in
      let num = Char.code s.[j] - 48 in
      loop (List.filter (fun i -> i <> num) res) j
  in loop [0; 1; 2; 3; 4; 5; 6; 7; 8] (String.length s)

let ca_database = Hashtbl.create 10

let get_names ?(prototyping = false) () = 
  Hashtbl.fold
    (fun key mdl res ->
       let module CA = (val mdl : AUTOMATON) in
       if CA.prototyping = prototyping then key :: res else res)
    ca_database
    []
  |> List.sort String.compare

module XY = struct
  type t = int * int
  let compare (a, b) (c, d) =
    let tmp = compare a c in
    if tmp = 0 then compare b d else tmp
end

module XYSet = Set.Make(XY)
module XYMap = Map.Make(XY)

module Args = struct
  type t = (string * string) list

  let any f t s ~default =
    match List.assoc_opt (String.uppercase_ascii s) t with
    | None -> default
    | Some s -> f s

  let get t = any (fun x -> x) t
  let get_int = any int_of_string
  let get_float = any float_of_string
  let get_bool = any (fun s ->
    match String.lowercase_ascii s with
    | "false" | "no" | "0"| "" -> false
    | _ -> true)
end

module Coord = struct
  type t = int * int
  (** Grid coordinate: row, column. *)

  let check_bounds ~rows ~columns =
    if rows <= 0 || columns <= 0 then
      invalid_arg
        (Printf.sprintf
           "Invalid grid bounds: rows=%d columns=%d"
           rows columns)

  let positive_mod x n =
    let r = x mod n in
    if r < 0 then r + n else r

  let wrap_index ~size x =
    if size <= 0 then
      invalid_arg
        (Printf.sprintf "Invalid wrapping size: %d" size);
    positive_mod x size

  let wrap ~rows ~columns (r, c) =
    check_bounds ~rows ~columns;
    (wrap_index ~size:rows r, wrap_index ~size:columns c)

  let in_bounds ~rows ~columns (r, c) =
    check_bounds ~rows ~columns;
    r >= 0 && r < rows && c >= 0 && c < columns

  let uses_torus ~rows ~columns coord =
    not (in_bounds ~rows ~columns coord)

  let add (r, c) (dr, dc) =
    (r + dr, c + dc)

  let sub (r1, c1) (r2, c2) =
    (r1 - r2, c1 - c2)

  let scale k (r, c) =
    (k * r, k * c)

  let move ~rows ~columns coord offset =
    coord
    |> add offset
    |> wrap ~rows ~columns

  let raw_move coord offset =
    add coord offset

  let move_with_torus_flag ~rows ~columns coord offset =
    let raw = raw_move coord offset in
    let wrapped = wrap ~rows ~columns raw in
    (wrapped, uses_torus ~rows ~columns raw)

  let cell_center (r, c) =
    (float_of_int c +. 0.5, float_of_int r +. 0.5)

  let row (r, _) = r
  let column (_, c) = c

  let to_string (r, c) =
    Printf.sprintf "(%d,%d)" r c
end
