(*---------------------------------------------------------------------------*
 * The "boss" library. This provides a collection of proof routines.         *
 * They provide                                                              *
 *                                                                           *
 *    1. Automatic maintenance of the usual products of a datatype           *
 *       definition.                                                         *
 *                                                                           *
 *    2. Some tools that work using that information.                        *
 *                                                                           *
 *    3. Some basic automation support.                                      *
 *                                                                           *
 *---------------------------------------------------------------------------*)

structure bossLib :> bossLib =
struct

open HolKernel Parse basicHol90Lib;

  type term = Term.term
  type fixity = Parse.fixity
  type thm = Thm.thm
  type tactic = Abbrev.tactic
  type simpset = simpLib.simpset
  type defn = Defn.defn
  type 'a quotation = 'a Portable.frag list


infix ORELSE;

fun BOSS_ERR func mesg =
     HOL_ERR{origin_structure = "bossLib",
             origin_function = func,
             message = mesg};

(*---------------------------------------------------------------------------*
            Datatype definition
 *---------------------------------------------------------------------------*)

fun type_rws tyn = TypeBase.simpls_of (valOf (TypeBase.read tyn));

val Hol_datatype = Datatype.Hol_datatype;


(*---------------------------------------------------------------------------
            Function definition
 ---------------------------------------------------------------------------*)

val Hol_fun = QuotedDef.Hol_fun;
val xDefine = QuotedDef.xDefine
val Define  = QuotedDef.Define

val ind_suffix = QuotedDef.ind_suffix
val def_suffix = QuotedDef.def_suffix;

(*---------------------------------------------------------------------------
            Automated proof operations
 ---------------------------------------------------------------------------*)

fun PROVE thl q = BasicProvers.PROVE thl (Parse.Term q);
val PROVE_TAC = BasicProvers.PROVE_TAC

val RW_TAC  = BasicProvers.RW_TAC

val && = BasicProvers.&&;
infix &&;

(*---------------------------------------------------------------------------
     The following simplification sets will be applied in a context
     that extends that loaded by bossLib. They are intended to be used
     by RW_TAC. The way to choose which simpset to use depends on factors
     such as running time.  For example, RW_TAC with arith_ss (and thus 
     with list_ss) may take a long time on some goals featuring arithmetic 
     terms (since the arithmetic decision procedure may be invoked). In 
     such cases, it may be worth dropping down to use the base_ss, 
     supplying whatever arithmetic theorems are required, so that 
     simplification is quick.
 ---------------------------------------------------------------------------*)

val base_ss = simpLib.++(BasicProvers.bool_ss,pairSimps.PAIR_ss)
              && let open sumTheory optionTheory
                 in [ISL,ISR,OUTL,OUTR,INL,INR,
                     THE_DEF, option_APPLY_DEF] end;

val arith_ss = simpLib.++(base_ss, arithSimps.ARITH_ss)
val list_ss  = simpLib.++(arith_ss, listSimps.list_ss);


val DECIDE     = decisionLib.DECIDE o Parse.Term
val DECIDE_TAC = decisionLib.DECIDE_TAC

fun ZAP_TAC ss thl =
   BasicProvers.STP_TAC ss 
      (tautLib.TAUT_TAC 
          ORELSE DECIDE_TAC
          ORELSE BasicProvers.GEN_PROVE_TAC 0 12 1 thl);


(*---------------------------------------------------------------------------
            Single step interactive proof operations
 ---------------------------------------------------------------------------*)


val Cases  = SingleStep.Cases
val Induct = SingleStep.Induct

val Cases_on          = SingleStep.Cases_on
val Induct_on         = SingleStep.Induct_on
val completeInduct_on = SingleStep.completeInduct_on
val measureInduct_on  = SingleStep.measureInduct_on;

val SPOSE_NOT_THEN    = SingleStep.SPOSE_NOT_THEN

val by = SingleStep.by; (* infix 8 by *)


end;
