type spec_result = Successful
                   | Failure of string * string * string
                   | Error of string

(* Spec内における、一つのitに対応するモジュール
   内部には、内部には、それぞれのit内における各shouldの結果を格納している。
*)
module Example = struct

  type t = {
    description : string;
    mutable expectations : spec_result list;
    example_id : int;
  }

  let current_example = ref None
  let example_counter = ref 0
  let get_id () =
    let new_count = succ !example_counter in
    example_counter := new_count;
    new_count
  ;;

  let new_example desc = {
    description = desc;
    expectations = [];
    example_id = get_id ();
  }
  ;;

  let start_example e = current_example := Some e
  let end_example e = current_example := None

  let add_successful_expectation () =
    match !current_example with
    | None -> failwith "not set to current example"
    | Some e ->
      e.expectations <- Successful :: e.expectations;
      current_example := Some e
  ;;

  let add_failure_expectation ope_str result_str expect_str =
    match !current_example with
    | None -> failwith "not set to current example"
    | Some e ->
      e.expectations <- Failure (ope_str, result_str, expect_str) :: e.expectations;
      current_example := Some e
  ;;

  let add_error str =
    match !current_example with
    | None -> failwith "not set to current example"
    | Some e ->
      e.expectations <- Error str :: e.expectations;
      current_example := Some e
  ;;

end

(* 各describeに対応する型を提供する
   内部には、それぞれのitに対応するExampleのリストを保持している。
*)
module Spec = struct
  type process = unit -> unit
  type t = {
    description : string;
    mutable examples : Example.t list;
    spec_id : int;
    all_preparations : process Queue.t;
    each_preparations : process Queue.t;
    all_post_processes : process Queue.t;
    each_post_processes : process Queue.t;
  }

  let spec_stack = Stack.create ()
  let spec_counter = ref 0
  let get_spec_id () =
    let new_count = succ !spec_counter in
    spec_counter := new_count;
    new_count
  ;;

  let new_spec (desc: string) =
    {description = desc; examples = [];
     spec_id = get_spec_id ();
     all_preparations = Queue.create ();
     all_post_processes = Queue.create ();
     each_preparations = Queue.create ();
     each_post_processes = Queue.create ();
    }

  let run_spec (spec, spec_body) =
    spec_body ();
    spec
  ;;

  let start_spec spec = Stack.push spec spec_stack
  let end_spec spec = Stack.pop spec_stack

  let add_example e =
    let spec = Stack.top spec_stack in
    spec.examples <- e :: spec.examples;
  ;;

  let start_example e =
    let spec = Stack.top spec_stack in
    let e = List.find (fun ex -> ex.Example.example_id == e.Example.example_id)
      spec.examples in

    Example.start_example e;
  ;;

  let new_example = Example.new_example
  let end_example = Example.end_example
  let add_successful_expectation = Example.add_successful_expectation
  let add_failure_expectation = Example.add_failure_expectation
  let add_error = Example.add_error

  let add_preparation spec f = Queue.add f spec.all_preparations
  let add_preparation_for_each spec f = Queue.add f spec.each_preparations
  let add_post_process spec f = Queue.add f spec.all_post_processes
  let add_post_process_for_each spec f = Queue.add f spec.each_post_processes

  let run_each_preparations () = 
    let spec = Stack.top spec_stack in
    Queue.iter (fun f -> f()) spec.each_preparations

  let run_each_post_processes () =
    let spec = Stack.top spec_stack in
    Queue.iter (fun f -> f ()) spec.each_post_processes

  let run_all_preparations spec = 
    Queue.iter (fun f -> f()) spec.all_preparations

  let run_all_post_processes spec =
    Queue.iter (fun f -> f ()) spec.all_post_processes
end
