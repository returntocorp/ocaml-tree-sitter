(*
   Code generator for the AST.ml file.
*)

open Printf
open AST_grammar
open Codegen_util
open Indent.Types

let rec format_body body : Indent.t =
  match body with
  | Symbol ident -> [Line (translate_ident ident)]
  | String s -> [Line (sprintf "string (* %S *)" s)]
  | Pattern s -> [Line (sprintf "string (* pattern %S *)" s)]
  | Blank -> [Line "string (* blank *)"]
  | Repeat body ->
      [
        Inline (format_body body);
        Block [Line "list (* zero or more *)"]
      ]
  | Repeat1 body ->
      [
        Inline (format_body body);
        Block [Line "list (* one or more *)"]
      ]
  | Choice body_list ->
      [
        Line "[";
        Inline (format_choice body_list);
        Line "]"
      ]
  | Seq body_list ->
      [
        Line "(";
        Block (format_seq body_list);
        Line ")"
      ]

and format_choice l =
  List.mapi (fun i body ->
    let name = sprintf "Case%i" i in
    Inline [
      Line (sprintf "| `%s of (" name);
      Block [Block (format_body body)];
      Line "  )"
    ]
  ) l

and format_seq l =
  List.map (fun body -> Block (format_body body)) l
  |> interleave (Line "*")

let format_rule ~use_rec pos len (name, body) : Indent.t =
  let is_first = (pos = 0) in
  let is_last = (pos = len - 1) in
  let type_ =
    if use_rec && not is_first then
      "and"
    else
      "type"
  in
  let ppx =
    if not use_rec || is_last then
      [
        Line "[@@deriving show {with_path = false}]";
      ]
    else
      []
  in
  [
    Line (sprintf "%s %s =" type_ (translate_ident name));
    Block (format_body body);
    Inline ppx;
  ]

let format_types grammar =
  let use_rec, rules =
    let orig_rules = grammar.rules in
    match Topo_sort.sort orig_rules with
    | Some reordered_rules -> false, reordered_rules
    | None -> true, orig_rules
  in
  let len = List.length rules in
  List.mapi
    (fun pos x -> Inline (format_rule ~use_rec pos len x))
    rules
  |> interleave (Line "")

let generate_dumper grammar =
  [
    Line "";
    Line (sprintf "let dump root =");
    Block [
      Line (sprintf "print_endline (show_%s root)"
              grammar.entrypoint);
    ]
  ]

let format grammar =
  format_types grammar @ generate_dumper grammar

let generate grammar =
  let tree = format grammar in
  Indent.to_string tree