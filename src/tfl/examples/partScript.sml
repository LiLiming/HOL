open HolKernel Parse basicHol90Lib;
infixr 3 -->;
infix ## |-> THEN THENL THENC ORELSE ORELSEC THEN_TCL ORELSE_TCL;

open bossLib permTheory listXTheory; 
infix 8 by; infix &&;


val _ = new_theory"part";

(*---------------------------------------------------------------------------
                 Partition a list by a predicate.
 ---------------------------------------------------------------------------*)

val part_def = 
 Define 
     `(part P [] l1 l2 = (l1,l2))
  /\  (part P (CONS h rst) l1 l2 = 
          (P h => part P rst (CONS h l1) l2
               |  part P rst  l1  (CONS h l2)))`;


(*---------------------------------------------------------------------------
              Theorems about "part"
 ---------------------------------------------------------------------------*)

val part_length = Q.store_thm
("part_length",
 `!P L l1 l2 p q.
    ((p,q) = part P L l1 l2)
    ==> (LENGTH L + LENGTH l1 + LENGTH l2 = LENGTH p + LENGTH q)`,
Induct_on `L` 
  THEN RW_TAC list_ss [part_def]
  THEN RES_THEN MP_TAC 
  THEN RW_TAC list_ss []);


val part_length_lem = Q.store_thm
("part_length_lem",
`!P L l1 l2 p q. 
    ((p,q) = part P L l1 l2)
    ==>  LENGTH p <= LENGTH L + LENGTH l1 + LENGTH l2 /\
         LENGTH q <= LENGTH L + LENGTH l1 + LENGTH l2`,
RW_TAC bool_ss []
 THEN IMP_RES_THEN MP_TAC part_length
 THEN CONV_TAC arithLib.ARITH_CONV);


(*---------------------------------------------------------------------------
     Everything in the partitions occurs in the original list, and 
     vice-versa. The goal has been generalized. 
 ---------------------------------------------------------------------------*)

val part_mem = Q.store_thm
("part_mem",
 `!P L a1 a2 l1 l2. 
     ((a1,a2) = part P L l1 l2) 
       ==> 
      !x. mem x (APPEND L (APPEND l1 l2)) = mem x (APPEND a1 a2)`,
Induct_on `L` 
  THEN RW_TAC list_ss [part_def]
  THEN RES_THEN MP_TAC THEN NTAC 2 (DISCH_THEN (K ALL_TAC))
  THEN DISCH_THEN (fn th => REWRITE_TAC [GSYM th])
  THEN ZAP_TAC (list_ss && [mem_def,mem_of_append]) []);


(*---------------------------------------------------------------------------
      Appending the two partitions of the original list is a 
      permutation of the original list.
 ---------------------------------------------------------------------------*)

val part_perm_lem = Q.store_thm
("part_perm_lem",
`!P L a1 a2 l1 l2. 
     ((a1,a2) = part P L l1 l2) 
       ==> 
      perm (APPEND L (APPEND l1 l2)) (APPEND a1 a2)`,
Induct_on `L` 
  THEN RW_TAC list_ss [part_def, perm_refl]
  THEN RES_TAC THEN MATCH_MP_TAC trans_permute THENL
  [Q.EXISTS_TAC `APPEND L (APPEND (CONS h l1) l2)`,
   Q.EXISTS_TAC `APPEND L (APPEND l1 (CONS h l2))`]
  THEN RW_TAC list_ss [] 
  THEN PROVE_TAC [trans_permute, cons_perm, perm_refl,
                  perm_cong, perm_sym, perm_append]);


(*---------------------------------------------------------------------------
       Each element in the positive and negative partitions has 
       the desired property. The simplifier loops on some of the 
       subgoals here, so we have to take round-about measures.
 ---------------------------------------------------------------------------*)

val parts_have_prop = Q.store_thm
("parts_have_prop",
 `!P L A B l1 l2. 
   ((A,B) = part P L l1 l2)
    /\ (!x. mem x l1 ==> P x)
    /\ (!x. mem x l2 ==> ~P x)
    ==> 
      (!z. mem z A ==>  P z) /\
      (!z. mem z B ==> ~P z)`,
Induct_on `L`
 THEN REWRITE_TAC [part_def,pairTheory.CLOSED_PAIR_EQ] THENL
 [PROVE_TAC[],
  POP_ASSUM (fn th => REPEAT GEN_TAC THEN 
     COND_CASES_TAC THEN STRIP_TAC THEN MATCH_MP_TAC th)
   THENL [MAP_EVERY Q.EXISTS_TAC [`CONS h l1`, `l2`],
          MAP_EVERY Q.EXISTS_TAC [`l1`, `CONS h l2`]]
  THEN RW_TAC list_ss [mem_def] THEN RW_TAC bool_ss []]);

(*---------------------------------------------------------------------------
     A packaged version of "part". Most theorems about "partition" 
     will be instances of theorems about "part". 
 ---------------------------------------------------------------------------*)

val partition_def = 
 Define
     `partition P L = part P L [] []`;

val _ = export_theory();
