(* plugin.ml *)

type cell = bool * char
type 'a matrix = 'a array array

module type AUTOMATON =
 sig
  val n_rows : int
  val n_cols : int
  val states : int
  val import : string -> cell matrix
  val export : string -> cell matrix -> unit
  val check_row : int -> int
  val check_col : int -> int
  val create : seed:int -> cell matrix
  val evolve : cell matrix -> cell matrix
 end

let f000 = (false, '\000')
let t000 = (true , '\000')
let f001 = (false, '\001')
let t001 = (true , '\001')

let create_matrix ?(init = 1) ~rows ~columns ~seed () =
  let mat = Array.make_matrix rows columns f000 in
  let f = match init with
    | 1 -> (fun () -> '\001')
    | n -> (fun () -> Char.chr (Random.int n)) in
  Random.self_init ();
  for i = 1 to seed do
    Random.(mat.(int rows).(int columns) <- (true, f ()))
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

let get_names () = 
  Hashtbl.fold (fun key _ res -> key :: res) ca_database []
  |> List.sort String.compare

module XY = struct
  type t = int * int
  let compare (a, b) (c, d) =
    let tmp = compare a c in
    if tmp = 0 then compare b d else tmp
end

module XYSet = Set.Make(XY)
module XYMap = Map.Make(XY)
