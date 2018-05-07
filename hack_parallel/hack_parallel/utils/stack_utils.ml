(**
 * Copyright (c) 2015, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the "hack" directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 *
*)

(** Adds some utilities to the Stack module *)

module Ocaml_stack = Stack

module Stack = struct
  include Ocaml_stack
  let merge_bytes : string Stack.t -> string = function stack ->
    let strs = Stack.fold (fun acc x -> x :: acc) [] stack in
    String.concat "" strs
end
