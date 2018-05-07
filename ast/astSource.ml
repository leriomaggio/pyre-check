(** Copyright (c) 2016-present, Facebook, Inc.

    This source code is licensed under the MIT license found in the
    LICENSE file in the root directory of this source tree. *)

open Core

open AstExpression

module Ignore = AstIgnore
module Location = AstLocation
module Statement = AstStatement


module Metadata = struct
  type t = {
    autogenerated: bool;
    debug: bool;
    declare: bool;
    ignore_lines: Ignore.t list;
    number_of_lines: int;
    strict: bool;
    version: int;
  }
  [@@deriving compare, eq, show]

  let create
      ?(autogenerated = false)
      ?(debug = true)
      ?(declare = false)
      ?(ignore_lines = [])
      ?(strict = false)
      ?(version = 3)
      ~number_of_lines
      () =
    {
      autogenerated;
      debug;
      declare;
      ignore_lines;
      number_of_lines;
      strict;
      version;
    }

  let parse path lines =
    let is_python_2_shebang line =
      String.is_prefix ~prefix:"#!" line &&
      String.is_substring ~substring:"python2" line
    in
    let is_debug line =
      String.is_prefix ~prefix:"#" line &&
      String.is_substring ~substring:"pyre-debug" line
    in
    let is_strict line =
      String.is_prefix ~prefix:"#" line &&
      String.is_substring ~substring:"pyre-strict" line
    in
    let is_declare line =
      String.is_prefix ~prefix:"#" line &&
      String.is_substring ~substring:"pyre-do-not-check" line
    in
    let parse_ignore index line ignored_lines =
      let create_ignore ~index ~line ~kind =
        let codes =
          try
            Str.search_forward
              (Str.regexp "pyre-\\(ignore\\|fixme\\)\\[\\([0-9, ]+\\)\\]")
              line
              0
            |> ignore;
            Str.matched_group 2 line
            |> Str.split (Str.regexp "[^0-9]+")
            |> List.map ~f:Int.of_string
          with Not_found -> []
        in
        let ignored_line =
          if String.is_prefix ~prefix:"#" (String.strip line) then
            index + 2
          else
            index + 1
        in
        let location =
          let start_column =
            Str.search_forward (Str.regexp "\\(pyre-\\(ignore\\|fixme\\)\\|type: ignore\\)") line 0
          in
          let end_column = String.length line in
          let start = { Location.line = index + 1; column = start_column } in
          let stop = { Location.line = index + 1; column = end_column } in
          { Location.path; start; stop }
        in
        Ignore.create ~ignored_line ~codes ~location ~kind
      in
      if String.is_substring ~substring:"pyre-ignore" line then
        (create_ignore ~index ~line ~kind:Ignore.PyreIgnore) :: ignored_lines
      else if String.is_substring ~substring:"pyre-fixme" line then
        (create_ignore ~index ~line ~kind:Ignore.PyreFixme) :: ignored_lines
      else if String.is_substring ~substring:"type: ignore" line then
        (create_ignore ~index ~line ~kind:Ignore.TypeIgnore) :: ignored_lines
      else
        ignored_lines
    in
    let is_autogenerated line =
      String.is_substring ~substring:("@" ^ "generated") line ||
      String.is_substring ~substring:("@" ^ "auto-generated") line
    in

    let collect index (version, debug, strict, declare, ignored_lines, autogenerated) line =
      let version =
        match version with
        | Some _ ->
            version
        | None ->
            if is_python_2_shebang line then Some 2 else None in
      version,
      debug || is_debug line,
      strict || is_strict line,
      declare || is_declare line,
      parse_ignore index line ignored_lines,
      autogenerated || is_autogenerated line
    in
    let version, debug, strict, declare, ignore_lines, autogenerated =
      List.map ~f:(fun line -> String.strip line |> String.lowercase) lines
      |> List.foldi ~init:(None, false, false, false, [], false) ~f:collect
    in
    {
      autogenerated;
      debug;
      declare;
      ignore_lines;
      number_of_lines = List.length lines;
      strict;
      version = Option.value ~default:3 version;
    }
end


type t = {
  docstring: string option;
  metadata: Metadata.t;
  path: string;
  qualifier: Access.t;
  statements: Statement.t list;
}
[@@deriving compare, eq, show]


type mode =
  | Default
  | Declare
  | Strict
  | Infer
[@@deriving compare, eq, show, sexp, hash]


let mode source ~configuration =
  match configuration, source with
  | { Configuration.infer = true; _ }, _ ->
      Infer
  | { Configuration.strict = true; _ }, _
  | _, { metadata = { Metadata.strict = true; _ }; _ } ->
      Strict
  | { Configuration.declare = true; _ }, _
  | _, { metadata = { Metadata.declare = true; _ }; _ } ->
      Declare
  | _ ->
      Default


let create
    ?(docstring = None)
    ?(metadata = Metadata.create ~number_of_lines:(-1) ())
    ?(path = "")
    ?(qualifier = [])
    statements =
  {
    docstring;
    metadata;
    path;
    qualifier;
    statements;
  }


let ignore_lines { metadata = { Metadata.ignore_lines; _ }; _ } =
  ignore_lines


let statements { statements; _ } =
  statements


let qualifier ~path =
  let reversed_elements =
    Filename.parts path
    |> List.tl_exn (* Strip current directory. *)
    |> List.rev in
  let last_without_suffix =
    let last = List.hd_exn reversed_elements in
    match String.rindex last '.' with
    | Some index ->
        String.slice last 0 index
    | _ ->
        last in
  let strip = function
    | "builtins" :: tail ->
        tail
    | "__init__" :: tail ->
        tail
    | elements ->
        elements in
  (last_without_suffix :: (List.tl_exn reversed_elements))
  |> strip
  |> List.rev_map
    ~f:Access.create
  |> List.concat
