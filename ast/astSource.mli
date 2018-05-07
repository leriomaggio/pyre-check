(** Copyright (c) 2016-present, Facebook, Inc.

    This source code is licensed under the MIT license found in the
    LICENSE file in the root directory of this source tree. *)

open AstExpression

module Ignore = AstIgnore
module Location = AstLocation
module Statement = AstStatement


module Metadata : sig
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

  val create
    :  ?autogenerated: bool
    -> ?debug: bool
    -> ?declare: bool
    -> ?ignore_lines: Ignore.t list
    -> ?strict: bool
    -> ?version: int
    -> number_of_lines: int
    -> unit
    -> t

  val parse: string -> string list -> t
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


val mode: t -> configuration:Configuration.t -> mode


val create
  :  ?docstring: string option
  -> ?metadata: Metadata.t
  -> ?path: string
  -> ?qualifier: Access.t
  -> Statement.t list
  -> t


val ignore_lines: t -> Ignore.t list

val qualifier: path:string -> Access.t

val statements: t -> Statement.t list
