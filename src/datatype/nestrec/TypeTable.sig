(* =====================================================================*)
(* FILE          : table.sig                                            *)
(* DESCRIPTION   : Signatures for a lookup table.                       *)
(*                 It's undefined what happens if we enter the same     *)
(*                 index but different entries                          *)
(*                                                                      *)
(* AUTHOR        : Healfdene Goguen, University of Edinburgh            *)
(* DATE          : 92.08.01                                             *)
(*                                                                      *)
(* =====================================================================*)

(* Copyright 1992 by AT&T Bell Laboratories *)
(* Share and Enjoy *)

signature TypeTable =
sig
  datatype 'a table_entry = InTable of 'a | NotFound
  type 'a table

  val empty : 'a table
  val enter : {key : Type.hol_type, entry : 'a, table : 'a table} -> 'a table
  val lookup : {key : Type.hol_type, table : 'a table} -> 'a table_entry
  val elts : 'a table -> 'a list
end;
