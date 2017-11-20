exception Unimplemented

module type Engine = sig
  type idx
  val index_of_dir : string -> idx
  val to_list : idx -> (string * string list) list
  val or_not  : idx -> string list -> string list -> string list
  val and_not : idx -> string list -> string list -> string list
  val format : Format.formatter -> idx -> unit
end

module MakeEngine
  (S:Data.Set with type Elt.t = string)
  (D:Data.Dictionary with type Key.t = string)
  : Engine
=
struct
  type idx = unit

  let index_of_dir d =
    raise Unimplemented

  let to_list idx =
    raise Unimplemented

  let or_not idx ors nots =
    raise Unimplemented

  let and_not idx ands nots =
    raise Unimplemented

  let format fmt idx =
    Format.fprintf fmt "<abstr>" (* TODO: improve if you wish *)
end

module TrivialEngine =
struct
  type idx = unit
  let index_of_dir d = ()
  let to_list idx = []
  let or_not idx ors nots = []
  let and_not idx ands nots = []
  let format fmt idx = ()
end

module StringKey = struct
  type t = string
  let format fmt s =
    Format.fprintf fmt "%s" s
end

module StringListValue = struct
  type t = string list
  let format fmt slst =
    List.iter (Format.fprintf "%s ") slst
end

module IndexListDictionary = MakeListDictionary(StringKey)(StringListValue)

module ListEngine = struct

  type idx = IndexListDictionary.t

  let index_of_dir dir =
    let files = Sys.readdir dir |> to_list in
    (*TODO: Write code*)

  let to_list index =
    raise Unimplemented

  let or_not index ors nots =
    raise Unimplemented

  let and_not index ands nots =
    raise Unimplemented

  let format fmt index =
    raise Unimplemented

end
(* TODO: replace [TrivialEngine] in the line above with
   an application of [MakeEngine] to some appropriate parameters. *)

module TreeEngine = TrivialEngine
(* TODO: replace [TrivialEngine] in the line above with
   an application of [MakeEngine] to some appropriate parameters. *)
