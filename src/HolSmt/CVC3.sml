(* Copyright (c) 2009 Tjark Weber. All rights reserved. *)

(* Functions to invoke the CVC3 SMT solver *)

structure CVC3 = struct

  (* returns SAT if CVC3 reported "sat", UNSAT if CVC3 reported "unsat" *)
  fun result_fn path =
    let val instream = TextIO.openIn path
        val line     = TextIO.inputLine instream
    in
      TextIO.closeIn instream;
      if line = SOME "sat\n" then
        SolverSpec.SAT NONE
      else if line = SOME "unsat\n" then
        SolverSpec.UNSAT NONE
      else
        SolverSpec.UNKNOWN NONE
    end

  (* CVC3, SMT-LIB file format *)
  local val infile = "input.cvc3.smt"
        val outfile = "output.cvc3"
  in
    val CVC3_SMT_Oracle = SolverSpec.make_solver
      (Library.write_strings_to_file infile o Lib.snd o SmtLib.goal_to_SmtLib)
      ("cvc3-optimized -lang smt " ^ infile ^ " > " ^ outfile)
      (fn () => result_fn outfile)
      [infile, outfile]
  end

end
