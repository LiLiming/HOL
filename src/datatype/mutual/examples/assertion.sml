(*---------------------------------------------------------------------------

     Defining an assertion language for a programming logic.

 ---------------------------------------------------------------------------*)

app load ["stringTheory", "listTheory", "setTheory", 
          "mutualLib", "bossLib"];

open mutualLib setTheory bossLib;


(*=======================================================================*)
(* First we define the datatypes for assertion expressions.              *)
(* vexp is a value-yielding expression, of type num.                     *)
(* vexp list is a list of vexp expressions, of type num list.            *)
(* aexp is an assertion expression, yielding a boolean.                  *)
(*=======================================================================*)

val def = 
 define_type [listTheory.list_Axiom]

        `(* vexp ::= n | x | SUC v | v+v | v-v | v*v | f (v1,...,vn)  *)

          vexp = ANUM of num
               | AVAR of string
               | ASUC of vexp
               | APLUS of vexp => vexp
               | AMINUS of vexp => vexp
               | AMULT of vexp => vexp
               | ACONDV of aexp => vexp => vexp
               | ACALL of string => vexp list ;

       (* aexp ::= true | false | v=v | v<v | vs<<vs |
                   a/\a | a\/a | ~a | a==>a | a=b |
                   (a=>a|a) | !x.a | ?x.a                  *)

          aexp = ATRUE
               | AFALSE
               | AEQ of vexp => vexp
               | ALESS of vexp => vexp
               | ALLESS of vexp list => vexp list
               | AAND of aexp => aexp
               | AOR of aexp => aexp
               | ANOT of aexp
               | AIMP of aexp => aexp
               | AEQB of aexp => aexp
               | ACOND of aexp => aexp => aexp
               | AFORALL of string => aexp
               | AEXISTS of string => aexp`;

(*===========================================================================*)
(* We define free variables on assertion expressions.                        *)
(*                                                                           *)
(* Note that because each of these functions take only one                   *)
(* argument, the original version of define_mutual_functions would have      *)
(* worked just as well for this definition; however, this is not true for    *)
(* the definition of the semantics in AV_DEF below.                          *)
(* ========================================================================= *)

val FVav = define_mutual_functions
{name = "FVav", rec_axiom = #New_Ty_Existence_Thm def,
 fixities = NONE,
 def = Term
   `(FVv (ANUM n)         = {})                                    /\
    (FVv (AVAR x)         = {x})                                   /\
    (FVv (ASUC v)         = FVv v)                                 /\
    (FVv (APLUS v1 v2)    = (FVv v1) UNION (FVv v2))               /\
    (FVv (AMINUS v1 v2)   = (FVv v1) UNION (FVv v2))               /\
    (FVv (AMULT v1 v2)    = (FVv v1) UNION (FVv v2))               /\
    (FVv (ACONDV a v1 v2) = (FVa a) UNION (FVv v1) UNION (FVv v2)) /\
    (FVv (ACALL f vs)     = FVvs vs)
     /\
    (FVvs  []             = {}) /\
    (FVvs (CONS v vs)     = (FVv v) UNION (FVvs vs))
     /\
    (FVa  ATRUE           = {})                                     /\
    (FVa  AFALSE          = {})                                     /\
    (FVa (AEQ v1 v2)      = (FVv v1) UNION (FVv v2))                /\
    (FVa (ALESS v1 v2)    = (FVv v1) UNION (FVv v2))                /\
    (FVa (ALLESS vs1 vs2) = (FVvs vs1) UNION (FVvs vs2))            /\
    (FVa (AAND a1 a2)     = (FVa a1) UNION (FVa a2))                /\
    (FVa (AOR a1 a2)      = (FVa a1) UNION (FVa a2))                /\
    (FVa (ANOT a)         = (FVa a))                                /\
    (FVa (AIMP a1 a2)     = (FVa a1) UNION (FVa a2))                /\
    (FVa (AEQB a1 a2)     = (FVa a1) UNION (FVa a2))                /\
    (FVa (ACOND a1 a2 a3) = (FVa a1) UNION (FVa a2) UNION (FVa a3)) /\
    (FVa (AFORALL x a)    = (FVa a) DELETE x)                       /\
    (FVa (AEXISTS x a)    = (FVa a) DELETE x)`};


(*===========================================================================*)
(* We now prove that each of the sets returned by the above free variable    *)
(* functions is finite.                                                      *)
(* ========================================================================= *)

val FINITE_FVav =
 store_thm
  ("FINITE_FVav",
   Term `(!v.   FINITE (FVv v)) /\
         (!vs.  FINITE (FVvs vs)) /\
         (!a.   FINITE (FVa a))`,
 MUTUAL_INDUCT_THEN (#New_Ty_Induct_Thm def) ASSUME_TAC
   THEN ASM_REWRITE_TAC[FVav,FINITE_EMPTY,FINITE_INSERT,
                        FINITE_UNION,FINITE_DELETE]);

(*---------------------------------------------------------------------------*)
(* We want to define the semantics of ALLESS as a lexicographic ordering.    *)
(* First we define << as a lexicographic ordering between lists of numbers.  *)
(*---------------------------------------------------------------------------*)

val LEXI_DEF =
 Define
    `(<< [] (CONS h t) = T)
 /\  (<< x  []         = F)
 /\  (<< (CONS h1 t1) (CONS h2 t2) = h1 < h2 \/ (h1=h2) /\ << t1 t2)`;

set_fixity "<<" (Infix 500);


(*---------------------------------------------------------------------------

     The semantics of assertions.

 ---------------------------------------------------------------------------*)

val AV_DEF  =  define_mutual_functions
{name = "AV_DEF", rec_axiom = #New_Ty_Existence_Thm def, fixities = NONE,
 def = Term
   `(V (ANUM n)         f s  =  n) /\
    (V (AVAR x)         f s  =  s x) /\
    (V (ASUC v)         f s  =  SUC (V v f s)) /\
    (V (APLUS v1 v2)    f s  =  V v1 f s + V v2 f s) /\
    (V (AMINUS v1 v2)   f s  =  V v1 f s - V v2 f s) /\
    (V (AMULT v1 v2)    f s  =  V v1 f s * V v2 f s) /\
    (V (ACONDV a v1 v2) f s  =  (A a f s => V v1 f s | V v2 f s)) /\
    (V (ACALL fn vs)    f s  =  f fn (VS vs f s))
     /\
    (VS  []             f s  =  []) /\
    (VS (CONS v vs)     f s  =  CONS (V v f s) (VS vs f s))
     /\
    (A  ATRUE           f s  =  T) /\
    (A  AFALSE          f s  =  F) /\
    (A (AEQ v1 v2)      f s  =  (V v1 f s = V v2 f s)) /\
    (A (ALESS v1 v2)    f s  =  V v1 f s < V v2 f s) /\
    (A (ALLESS vs1 vs2) f s  =  VS vs1 f s << VS vs2 f s) /\
    (A (AAND a1 a2)     f s  =  A a1 f s /\ A a2 f s) /\
    (A (AOR a1 a2)      f s  =  A a1 f s \/ A a2 f s) /\
    (A (ANOT a)         f s  =  ~(A a f s)) /\
    (A (AIMP a1 a2)     f s  =  (A a1 f s ==> A a2 f s)) /\
    (A (AEQB a1 a2)     f s  =  (A a1 f s = A a2 f s)) /\
    (A (ACOND a1 a2 a3) f s  =  (A a1 f s => A a2 f s | A a3 f s)) /\
    (A (AFORALL x a)    f s  =  !n. A a f (\y. y=x => n | s y)) /\
    (A (AEXISTS x a)    f s  =  ?n. A a f (\y. y=x => n | s y))`};


val LENGTH_VS =
 store_thm
  ("LENGTH_VS",
   Term `!vs f s. LENGTH (VS vs f s) = LENGTH vs`,
   Induct THEN ASM_REWRITE_TAC[AV_DEF,listTheory.LENGTH]
  );


(* ========================================================================= *)
(* We now prove several independence theorems for assertion language         *)
(* numeric and boolean expressions. These state the essential unchangedness  *)
(* of the semantics of each construct, under modifications of the state      *)
(* which are outside the free variables of the construct.                    *)
(* ========================================================================= *)

val AV_EQUIVALENCE =
 store_thm
 ("AV_EQUIVALENCE",
  Term
  `(!v f s1 s2. 
       (!x. x IN (FVv v) ==> (s1 x = s2 x)) ==> (V v f s1 = V v f s2))     /\
   (!vs f s1 s2. 
     (!x. x IN (FVvs vs) ==> (s1 x = s2 x)) ==> (VS vs f s1 = VS vs f s2)) /\
   (!a f s1 s2. 
       (!x. x IN (FVa a) ==> (s1 x = s2 x)) ==> (A a f s1 = A a f s2))`,
MUTUAL_INDUCT_THEN (#New_Ty_Induct_Thm def) ASSUME_TAC
  THEN RW_TAC bool_ss [AV_DEF,FVav,NOT_IN_EMPTY,IN_INSERT,IN_UNION,IN_DELETE]
  THEN ((AP_TERM_TAC THEN CONV_TAC FUN_EQ_CONV THEN RW_TAC bool_ss [])
         ORELSE PROVE_TAC []));


