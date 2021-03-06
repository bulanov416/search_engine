open OUnit2
open Data
open Printf

exception Fine

module type Tests = sig
  val tests : OUnit2.test list
end

module IntKey = struct
	type t = int
	let compare a b =
		if a < b then `LT
		else if a = b then `EQ
		else `GT
	let format fmt i =
		Format.fprintf fmt "%d" i
end

module StringValue = struct
	type t = string
	let format fmt s =
		Format.fprintf fmt "%s" s
end

let foo = 0
let bar = "bar"
let not_foo = 1
let not_bar = "BAR"

(* [DictTester] is where you will implement your test harness
 * to find buggy implementations. *)
module DictTester (M: DictionaryMaker) = struct
	module D = M(IntKey)(StringValue)

	let empty_test _ =
		assert D.(empty |> to_list = []);
		assert D.(is_empty empty)

	let insert_test _ =
		assert D.(empty |> insert foo bar |> to_list = [(foo, bar)]);
		assert D.(empty |> insert foo bar |> insert not_foo not_bar |> to_list = [(foo, bar); (not_foo, not_bar)]);
		assert D.(empty |> insert foo bar |> insert foo not_bar |> to_list = [(foo, not_bar)])

	let remove_test _ =
		assert D.(empty |> insert foo bar |> remove foo |> to_list = []);
		assert D.(empty |> insert foo bar |> remove not_foo |> to_list = [(foo, bar)]);
		assert D.(empty |> insert foo bar |> insert not_foo not_bar |> remove not_foo |> to_list = [(foo, bar)])

	let size_test _ =
		assert D.(empty |> size = 0);
		assert D.(empty |> insert foo bar |> size = 1);
		assert D.(empty |> insert foo bar |> insert foo not_bar |> size = 1);
		assert D.(empty |> insert foo bar |> insert not_foo not_bar |> size = 2)

	let member_test _ =
		assert D.(empty |> member foo = false);
		assert D.(empty |> insert foo bar |> member foo);
		assert D.(empty |> insert foo bar |> member not_foo = false);
		assert D.(empty |> insert foo bar |> remove foo |> member foo = false)

	let find_test _ =
		assert D.(empty |> insert foo bar |> find foo = Some bar);
		assert D.(empty |> insert foo bar |> find not_foo = None);
		assert D.(empty |> insert foo bar |> insert foo not_bar |> find foo = Some not_bar)

	let choose_test _ =
		assert D.(empty |> insert foo bar |> choose = Some (foo, bar));
		assert (
			match D.(empty |> insert foo bar |> insert not_foo not_bar |> choose) with
      (* Good, originally implemented to return first added, if it actually returns Some (not_foo, not_bar), the
      implementation isn't technically wrong *)
			| Some (k, v) -> true
      (* We're screwed *)
			| None -> false
		)

	let fold_test _ =
		let dicts =
		[
			D.(empty |> insert foo bar |> insert not_foo not_bar); (* 6 characters, key sum 1 *)
			D.(empty |> insert foo not_bar |> insert not_foo bar); (* 6 characters, key sum 1 *)
			D.(empty |> insert foo bar); (* 3 characters, key sum 0 *)
		]
		and funcs =
		[
			(fun k v init -> k + String.length v + init); (* Adds both keys and values *)
			(fun k v init -> String.length v + init); (* Adds just values *)
			(fun k v init -> k + init); (* Adds just keys *)
		]
		and results = [ [7; 6; 1]; [7; 6; 1]; [3; 3; 0] ] in
		(* What the HELL is this? A FOR loop? By God, why? *)
		for i = 0 to 2 do
			for j = 0 to 2 do
				if not D.(List.nth dicts i |> fold (List.nth funcs j) 0 = List.nth (List.nth results i) j) then
          failwith (sprintf "failed on dictionary %d, folder %d" i j)
			done
		done

	(*TODO: implement general test*)
	let general_test _ = assert true

	let tests =
		[
			"empty" 	>:: empty_test;
			"insert" 	>:: insert_test;
			"remove" 	>:: remove_test;
			"size" 		>:: size_test;
			"member" 	>:: member_test;
			"find" 		>:: find_test;
			"choose" 	>:: choose_test;
			"fold"		>:: fold_test;
		]
end

(* [tests] is where you should provide OUnit test cases for
 * your own implementations of dictionaries and sets.  You're
 * free to use [DictTester] as part of that if you choose. *)

module ListDictionaryTester = DictTester(MakeListDictionary)
module TreeDictionaryTester = DictTester(MakeTreeDictionary)

module MoreTreeTests = struct
	module D = MakeTreeDictionary(IntKey)(StringValue)

	let verbose = true

	let type_test _ =
		assert
		(
			try
				ignore D.(empty |> expose_tree);
				raise Fine
			with
			| Fine -> true
			| _ -> false
		)

	let rep_ok_test _ =
		let badtrees =
		[
			Threenode
			{
				left3 = Twonode
				{
					left2 = Twonode {left2 = Leaf; value = (1, ""); right2 = Leaf};
					value = (2, "");
					right2 = Twonode {left2 = Leaf; value = (3, ""); right2 = Leaf};
				};
				lvalue = (4, "");
				middle3 = Twonode {left2 = Leaf; value = (5, ""); right2 = Leaf};
				rvalue = (6, "");
				right3 = Twonode {left2 = Leaf; value = (7, ""); right2 = Leaf};
			}
		]
		in
		if verbose then printf "\nAll these trees are invalid, and rep_ok should know that:\n";
		List.iter
		(
		fun t ->
			try

				if verbose then Format.printf "%a" D.format t;
				ignore D.(t |> rep_ok);
				raise Fine (*this should NOT be thrown, all the trees in this test are invalid*)
			with
			| Fine -> failwith "rep_ok should have failed!"
			| Failure _ -> ()
			| _ -> failwith "rep_ok produced unexpected behavior!"
		)
		(List.map (fun t -> D.import_tree t) badtrees);
		if verbose then printf "\nrep_ok test successful!\n"

	let insert_test _ =
		let entries = 75 in
		let lots_of_nothing = List.init entries (fun _ -> ()) in
		Random.self_init ();
		try
			let folder init _ =
				let random = (Random.int 99) + 1 in
				if verbose then printf "\nInserting %d...\n" random;
				let next = D.(init |> insert random "") in
				if verbose then Format.printf "%a" D.format next;
				next
			in
			let result = List.fold_left folder D.empty lots_of_nothing in
			if verbose then printf "\nInsert test successful! Inserted %d entries!\n" entries;
			assert D.(result |> rep_ok = result)
		with
		| D.TreeException d as e -> Format.printf "%a" D.format d; raise e
		| e -> raise e

	let remove_test _ =
		let tree1 = Twonode
		{
			left2 = Twonode {left2 = Leaf; value = (1, ""); right2 = Leaf};
			value = (2, "");
			right2 = Twonode {left2 = Leaf; value = (3, ""); right2 = Leaf};
		}
		and tree2 = Threenode
		{
			left3 = Twonode {left2 = Leaf; value = (1, ""); right2 = Leaf};
			lvalue = (2, "");
			middle3 = Twonode {left2 = Leaf; value = (3, ""); right2 = Leaf};
			rvalue = (4, "");
			right3 = Twonode {left2 = Leaf; value = (5, ""); right2 = Leaf};
		}
		in
		if verbose then begin
      printf "\nTwo node remove test:\n";
      tree1 |> D.import_tree |> Format.printf "%a" D.format;
    end;
		for i = 1 to 3 do
			if verbose then printf "\nRemoving %d from two node...\n" i;
			let result = D.(tree1 |> import_tree |> remove i |> rep_ok) in
			if verbose then
				Format.printf "%a" D.format result;
				printf "\nRemoving %d from two node successful.\n" i
		done;
		if verbose then begin
			printf "\nThree node remove test:\n";
			tree2 |> D.import_tree |> Format.printf "%a" D.format;
    end;
		for i = 1 to 5 do
			if verbose then printf "\nRemoving %d from three node...\n" i;
			let result = D.(tree2 |> import_tree |> remove i |> rep_ok) in
			if verbose then
				Format.printf "%a" D.format result;
			 	printf "\nRemoving %d from three node successful.\n" i;
		done

	let tests =
		[
			"type"		>:: type_test;
			"rep_ok"	>:: rep_ok_test;
			"insert" 	>:: insert_test;
			"remove"	>:: remove_test;
		]

end

module MoreListTests = struct
	module D = MakeListDictionary(IntKey)(StringValue)

	let type_test _ =
		assert
		(
			try
				ignore D.(empty |> expose_tree);
				raise Fine
			with
			| Failure _ -> true
			| _ -> false
		)

	let tests =
		[
			"type"	>:: type_test;
		]
end

let tests = ListDictionaryTester.tests @ TreeDictionaryTester.tests @ MoreTreeTests.tests @ MoreListTests.tests
