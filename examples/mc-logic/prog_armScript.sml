
open HolKernel boolLib bossLib Parse;
open pred_setTheory res_quanTheory wordsTheory wordsLib bitTheory arithmeticTheory;
open set_sepTheory progTheory armTheory arm_auxTheory systemTheory;
open listTheory pairTheory combinTheory addressTheory;

val _ = new_theory "prog_arm";


infix \\ 
val op \\ = op THEN;

val RW = REWRITE_RULE;
val RW1 = ONCE_REWRITE_RULE;


(* ----------------------------------------------------------------------------- *)
(* The ARM set                                                                   *)
(* ----------------------------------------------------------------------------- *)

val _ = Hol_datatype `
  arm_el =  aReg of word4 => word32
          | aMem of word30 => word32  
          | aStatus of arm_bit => bool
          | aUndef of bool`;

val arm_el_11 = DB.fetch "-" "arm_el_11";
val arm_el_distinct = DB.fetch "-" "arm_el_distinct";

val _ = Parse.type_abbrev("arm_set",``:arm_el set``);


(* ----------------------------------------------------------------------------- *)
(* Converting from ARM-state record to arm_set                                   *)
(* ----------------------------------------------------------------------------- *)

val arm2set'_def = Define `
  arm2set' (rs,ms,st,ud) (s:unit arm_sys_state) =
    IMAGE (\a. aReg a (ARM_READ_REG a s)) rs UNION
    IMAGE (\a. aMem a (ARM_READ_MEM a s)) ms UNION
    IMAGE (\a. aStatus a (ARM_READ_STATUS a s)) st UNION
    if ud then { aUndef (ARM_READ_UNDEF s) } else {}`;

val arm2set_def   = Define `arm2set s = arm2set' (UNIV,UNIV,UNIV,T) s`;
val arm2set''_def = Define `arm2set'' x s = arm2set s DIFF arm2set' x s`;

(* theorems *)

val arm2set'_SUBSET_arm2set = prove(
  ``!y s. arm2set' y s SUBSET arm2set s``, 
  Cases_on `y` \\ Cases_on `r` \\ Cases_on `r'`
  \\ SIMP_TAC std_ss [SUBSET_DEF,arm2set'_def,arm2set_def,IN_IMAGE,IN_UNION,IN_UNIV]
  \\ METIS_TAC [NOT_IN_EMPTY]);

val SPLIT_arm2set = prove(
  ``!x s. SPLIT (arm2set s) (arm2set' x s, arm2set'' x s)``,
  REPEAT STRIP_TAC 
  \\ ASM_SIMP_TAC std_ss [SPLIT_def,EXTENSION,IN_UNION,IN_DIFF,arm2set''_def]
  \\ `arm2set' x s SUBSET arm2set s` by METIS_TAC [arm2set'_SUBSET_arm2set]
  \\ SIMP_TAC bool_ss [DISJOINT_DEF,EXTENSION,IN_INTER,NOT_IN_EMPTY,IN_DIFF]
  \\ METIS_TAC [SUBSET_DEF]);

val PUSH_IN_INTO_IF = METIS_PROVE []
  ``!g x y z. x IN (if g then y else z) = if g then x IN y else x IN z``;

val SUBSET_arm2set = prove(
  ``!u s. u SUBSET arm2set s = ?y. u = arm2set' y s``,
  REPEAT STRIP_TAC \\ EQ_TAC \\ REPEAT STRIP_TAC
  \\ ASM_REWRITE_TAC [arm2set'_SUBSET_arm2set]
  \\ Q.EXISTS_TAC `({ a |a| ?x. aReg a x IN u },
       { a |a| ?x. aMem a x IN u },{ a |a| ?x. aStatus a x IN u },
       (?y. aUndef y IN u))`
  \\ FULL_SIMP_TAC std_ss [arm2set'_def,arm2set_def,EXTENSION,SUBSET_DEF,IN_IMAGE,
       IN_UNION,GSPECIFICATION,IN_INSERT,NOT_IN_EMPTY,IN_UNIV,PUSH_IN_INTO_IF]  
  \\ STRIP_TAC \\ ASM_REWRITE_TAC [] \\ EQ_TAC \\ REPEAT STRIP_TAC THEN1 METIS_TAC []
  \\ PAT_ASSUM ``!x:'a. b:bool`` (IMP_RES_TAC) \\ FULL_SIMP_TAC std_ss [arm_el_11,arm_el_distinct]);

val SPLIT_arm2set_EXISTS = prove(
  ``!s u v. SPLIT (arm2set s) (u,v) = ?y. (u = arm2set' y s) /\ (v = arm2set'' y s)``,
  REPEAT STRIP_TAC \\ EQ_TAC \\ REPEAT STRIP_TAC \\ ASM_REWRITE_TAC [SPLIT_arm2set] 
  \\ FULL_SIMP_TAC bool_ss [SPLIT_def,arm2set'_def,arm2set''_def]
  \\ `u SUBSET (arm2set s)` by 
       (FULL_SIMP_TAC std_ss [EXTENSION,SUBSET_DEF,IN_UNION] \\ METIS_TAC [])
  \\ FULL_SIMP_TAC std_ss [SUBSET_arm2set] \\ Q.EXISTS_TAC `y` \\ REWRITE_TAC []
  \\ FULL_SIMP_TAC std_ss [EXTENSION,IN_DIFF,IN_UNION,DISJOINT_DEF,NOT_IN_EMPTY,IN_INTER]  
  \\ METIS_TAC []);

val IN_arm2set = prove(``
  (!r x s. aReg r x IN (arm2set s) = (x = ARM_READ_REG r s)) /\
  (!r x s. aReg r x IN (arm2set' (rs,ms,st,ud) s) = (x = ARM_READ_REG r s) /\ r IN rs) /\
  (!r x s. aReg r x IN (arm2set'' (rs,ms,st,ud) s) = (x = ARM_READ_REG r s) /\ ~(r IN rs)) /\
  (!p x s. aMem p x IN (arm2set s) = (x = ARM_READ_MEM p s)) /\
  (!p x s. aMem p x IN (arm2set' (rs,ms,st,ud) s) = (x = ARM_READ_MEM p s) /\ p IN ms) /\
  (!p x s. aMem p x IN (arm2set'' (rs,ms,st,ud) s) = (x = ARM_READ_MEM p s) /\ ~(p IN ms)) /\
  (!a x s. aStatus a x IN (arm2set s) = (x = ARM_READ_STATUS a s)) /\
  (!a x s. aStatus a x IN (arm2set' (rs,ms,st,ud) s) = (x = ARM_READ_STATUS a s) /\ a IN st) /\
  (!a x s. aStatus a x IN (arm2set'' (rs,ms,st,ud) s) = (x = ARM_READ_STATUS a s) /\ ~(a IN st)) /\
  (!x s. aUndef x IN (arm2set s) = (x = ARM_READ_UNDEF s)) /\
  (!x s. aUndef x IN (arm2set' (rs,ms,st,ud) s) = (x = ARM_READ_UNDEF s) /\ ud) /\
  (!x s. aUndef x IN (arm2set'' (rs,ms,st,ud) s) = (x = ARM_READ_UNDEF s) /\ ~ud)``,
  SRW_TAC [] [arm2set'_def,arm2set''_def,arm2set_def,IN_UNION,
     IN_INSERT,NOT_IN_EMPTY,IN_DIFF,PUSH_IN_INTO_IF] \\ METIS_TAC []);

val arm2set''_11 = prove(
  ``!y y' s s'. (arm2set'' y' s' = arm2set'' y s) ==> (y = y')``,
  REPEAT STRIP_TAC \\ CCONTR_TAC
  \\ `?r m st ud. y = (r,m,st,ud)` by METIS_TAC [PAIR]
  \\ `?r' m' st' ud'. y' = (r',m',st',ud')` by METIS_TAC [PAIR]
  \\ FULL_SIMP_TAC bool_ss [PAIR_EQ] THENL [
    `?a. ~(a IN r = a IN r')` by METIS_TAC [EXTENSION]
    \\ `~((?x. aReg a x IN arm2set'' y s) = (?x. aReg a x IN arm2set'' y' s'))` by ALL_TAC,
    `?a. ~(a IN m = a IN m')` by METIS_TAC [EXTENSION]
    \\ `~((?x. aMem a x IN arm2set'' y s) = (?x. aMem a x IN arm2set'' y' s'))` by ALL_TAC,
    `?a. ~(a IN st = a IN st')` by METIS_TAC [EXTENSION]
    \\ `~((?x. aStatus a x IN arm2set'' y s) = (?x. aStatus a x IN arm2set'' y' s'))` by ALL_TAC,
    `~((?x. aUndef x IN arm2set'' y s) = (?x. aUndef x IN arm2set'' y' s'))` by ALL_TAC]
  \\ REPEAT (FULL_SIMP_TAC bool_ss [IN_arm2set] \\ METIS_TAC [])
  \\ Q.PAT_ASSUM `arm2set'' y' s' = arm2set'' y s` (K ALL_TAC)     
  \\ FULL_SIMP_TAC bool_ss [IN_arm2set] \\ METIS_TAC []);

val DELETE_arm2set = prove(``
  (!a s. (arm2set' (rs,ms,st,ud) s) DELETE aReg a (ARM_READ_REG a s) =
         (arm2set' (rs DELETE a,ms,st,ud) s)) /\ 
  (!b s. (arm2set' (rs,ms,st,ud) s) DELETE aMem b (ARM_READ_MEM b s) =
         (arm2set' (rs,ms DELETE b,st,ud) s)) /\ 
  (!c s. (arm2set' (rs,ms,st,ud) s) DELETE aStatus c (ARM_READ_STATUS c s) =
         (arm2set' (rs,ms,st DELETE c,ud) s)) /\ 
  (!s. (arm2set' (rs,ms,st,ud) s) DELETE aUndef (ARM_READ_UNDEF s) =
       (arm2set' (rs,ms,st,F) s))``,
  SRW_TAC [] [arm2set'_def,EXTENSION,IN_UNION,GSPECIFICATION,LEFT_AND_OVER_OR,
    EXISTS_OR_THM,IN_DELETE,IN_INSERT,NOT_IN_EMPTY,PUSH_IN_INTO_IF]
  \\ Cases_on `x` \\ SRW_TAC [] [] \\ METIS_TAC []);

val EMPTY_arm2set = prove(``
  (arm2set' (rs,ms,st,ud) s = {}) = (rs = {}) /\ (ms = {}) /\ (st = {}) /\ ~ud``,
  Cases_on `ud`
  \\ SRW_TAC [] [arm2set'_def,EXTENSION,IN_UNION,GSPECIFICATION,LEFT_AND_OVER_OR,
    EXISTS_OR_THM,IN_DELETE,IN_INSERT,NOT_IN_EMPTY,PUSH_IN_INTO_IF]
  \\ METIS_TAC []);
    

(* ----------------------------------------------------------------------------- *)
(* Defining the ARM_MODEL                                                        *)
(* ----------------------------------------------------------------------------- *)

val aR_def = Define `aR a x = SEP_EQ {aReg a x}`;
val aM_def = Define `aM a x = SEP_EQ {aMem a x}`;
val aS1_def = Define `aS1 a x = SEP_EQ {aStatus a x}`;
val aU1_def = Define `aU1 x = SEP_EQ {aUndef x}`;

val aPC_def = Define `aPC x = aR 15w x * aU1 F`;

val aS_def = Define `aS (n,z,c,v) = aS1 sN n * aS1 sZ z * aS1 sC c * aS1 sV v`;

val ARM_NEXT_REL_def = Define `ARM_NEXT_REL s s' = (NEXT_ARM_MMU NO_CP (s:unit arm_sys_state) = s')`;

val ARM_INSTR_def = Define `ARM_INSTR (a:word32,c:word32) = { aMem (ADDR30 a) c }`;

val ARM_MODEL_def = Define `ARM_MODEL = (arm2set, ARM_NEXT_REL, ARM_INSTR)`;

(* theorems *)

val lemma =
  METIS_PROVE [SPLIT_arm2set]
  ``p (arm2set' y s) ==> (?u v. SPLIT (arm2set s) (u,v) /\ p u /\ (\v. v = arm2set'' y s) v)``;

val ARM_SPEC_SEMANTICS = store_thm("ARM_SPEC_SEMANTICS",
  ``SPEC ARM_MODEL p {} q =
    !y s seq. p (arm2set' y s) /\ rel_sequence ARM_NEXT_REL seq s ==>
              ?k. q (arm2set' y (seq k)) /\ (arm2set'' y s = arm2set'' y (seq k))``,
  SIMP_TAC bool_ss [GSYM RUN_EQ_SPEC,RUN_def,ARM_MODEL_def,STAR_def]
  \\ REPEAT STRIP_TAC \\ REVERSE EQ_TAC \\ REPEAT STRIP_TAC
  THEN1 (FULL_SIMP_TAC bool_ss [SPLIT_arm2set_EXISTS] \\ METIS_TAC [])    
  \\ Q.PAT_ASSUM `!s r. b` (STRIP_ASSUME_TAC o UNDISCH o SPEC_ALL o 
     (fn th => MATCH_MP th (UNDISCH lemma))  o Q.SPECL [`s`,`(\v. v = arm2set'' y s)`])
  \\ FULL_SIMP_TAC bool_ss [SPLIT_arm2set_EXISTS]
  \\ IMP_RES_TAC arm2set''_11 \\ Q.EXISTS_TAC `i` \\ METIS_TAC []);


(* ----------------------------------------------------------------------------- *)
(* Theorems for construction of |- SPEC ARM_MODEL ...                            *)
(* ----------------------------------------------------------------------------- *)

val STAR_arm2set = store_thm("STAR_arm2set",
  ``((aR a x * p) (arm2set' (rs,ms,st,ud) s) =
      (x = ARM_READ_REG a s) /\ a IN rs /\ p (arm2set' (rs DELETE a,ms,st,ud) s)) /\ 
    ((aM b y * p) (arm2set' (rs,ms,st,ud) s) =
      (y = ARM_READ_MEM b s) /\ b IN ms /\ p (arm2set' (rs,ms DELETE b,st,ud) s)) /\ 
    ((aS1 c z * p) (arm2set' (rs,ms,st,ud) s) =
      (z = ARM_READ_STATUS c s) /\ c IN st /\ p (arm2set' (rs,ms,st DELETE c,ud) s)) /\ 
    ((aU1 q * p) (arm2set' (rs,ms,st,ud) s) =
      (q = ARM_READ_UNDEF s) /\ ud /\ p (arm2set' (rs,ms,st,F) s)) /\ 
    ((cond g * p) (arm2set' (rs,ms,st,ud) s) =
      g /\ p (arm2set' (rs,ms,st,ud) s))``,
  SIMP_TAC std_ss [aR_def,aS1_def,aM_def,EQ_STAR,INSERT_SUBSET,cond_STAR,aU1_def,
    EMPTY_SUBSET,IN_arm2set,GSYM DELETE_DEF]
  \\ Cases_on `x = ARM_READ_REG a s` \\ ASM_SIMP_TAC bool_ss [DELETE_arm2set]
  \\ Cases_on `y = ARM_READ_MEM b s` \\ ASM_SIMP_TAC bool_ss [DELETE_arm2set]
  \\ Cases_on `z = ARM_READ_STATUS c s` \\ ASM_SIMP_TAC bool_ss [DELETE_arm2set]
  \\ Cases_on `q = ARM_READ_UNDEF s` \\ ASM_SIMP_TAC bool_ss [DELETE_arm2set]
  \\ ASM_SIMP_TAC std_ss [AC CONJ_COMM CONJ_ASSOC]);  

val CODE_POOL_arm2set_LEMMA = prove(
  ``!x y z. (x = z INSERT y) = (z INSERT y) SUBSET x /\ (x DIFF (z INSERT y) = {})``,
  SIMP_TAC std_ss [EXTENSION,SUBSET_DEF,IN_INSERT,NOT_IN_EMPTY,IN_DIFF] \\ METIS_TAC []);

val CODE_POOL_arm2set = store_thm("CODE_POOL_arm2set",
  ``CODE_POOL ARM_INSTR {(p,c)} (arm2set' (rs,ms,st,ud) s) =
      ({ADDR30 p} = ms) /\ (rs = {}) /\ (st = {}) /\ ~ud /\ (ARM_READ_MEM (ADDR30 p) s = c)``,
  SIMP_TAC bool_ss [CODE_POOL_def,IMAGE_INSERT,IMAGE_EMPTY,BIGUNION_INSERT,
    BIGUNION_EMPTY,UNION_EMPTY,ARM_INSTR_def,CODE_POOL_arm2set_LEMMA,
    GSYM DELETE_DEF, INSERT_SUBSET, EMPTY_SUBSET,IN_arm2set]
  \\ Cases_on `c = ARM_READ_MEM (ADDR30 p) s` 
  \\ ASM_SIMP_TAC std_ss [DELETE_arm2set,EMPTY_arm2set]
  \\ ASM_SIMP_TAC std_ss [AC CONJ_COMM CONJ_ASSOC]);

val UPDATE_arm2set'' = store_thm("UPDATE_arm2set''",
  ``(!a x. a IN rs ==> (arm2set'' (rs,ms,st,ud) (ARM_WRITE_REG a x s) = arm2set'' (rs,ms,st,ud) s)) /\
    (!a x. a IN ms ==> (arm2set'' (rs,ms,st,ud) (ARM_WRITE_MEM a x s) = arm2set'' (rs,ms,st,ud) s)) /\
    (!b. (arm2set'' (rs,ms,st,T) (ARM_WRITE_UNDEF b s) = arm2set'' (rs,ms,st,T) s)) /\
    (!x. sN IN st /\ sZ IN st /\ sC IN st /\ sV IN st ==> 
      (arm2set'' (rs,ms,st,ud) (ARM_WRITE_STATUS x s) = arm2set'' (rs,ms,st,ud) s))``,
  SIMP_TAC std_ss [arm2set_def,arm2set''_def,arm2set'_def,EXTENSION,IN_UNION,
    IN_IMAGE,IN_DIFF,IN_UNIV,NOT_IN_EMPTY,IN_INSERT,ARM_READ_WRITE,PUSH_IN_INTO_IF]
  \\ REPEAT STRIP_TAC \\ EQ_TAC \\ REPEAT STRIP_TAC 
  \\ FULL_SIMP_TAC std_ss [arm_el_distinct,arm_el_11] \\ METIS_TAC []);

val FORMAT_ALIGNED = store_thm("FORMAT_ALIGNED",
  ``ALIGNED a ==> (FORMAT UnsignedWord ((1 >< 0) a) x = x)``,
  REWRITE_TAC [ALIGNED_def] THEN STRIP_TAC THEN IMP_RES_TAC EXISTS_ADDR30
  THEN ASM_SIMP_TAC bool_ss [ADDR32_eq_0] THEN SRW_TAC [] [armTheory.FORMAT_def]);

val ARM_SPEC_CODE = (RW [GSYM ARM_MODEL_def] o SIMP_RULE std_ss [ARM_MODEL_def] o prove)
  (``SPEC ARM_MODEL (CODE_POOL (SND (SND ARM_MODEL)) c * p) {} (CODE_POOL (SND (SND ARM_MODEL)) c * q) =
    SPEC ARM_MODEL p c q``,
  REWRITE_TAC [SPEC_CODE]);

val IMP_ARM_SPEC_LEMMA = prove(
  ``!p q. 
      (!rs ms st ud s. ?s'.  
        (p (arm2set' (rs,ms,st,ud) s) ==> 
        (NEXT_ARM_MMU NO_CP s = s') /\ q (arm2set' (rs,ms,st,ud) s') /\ 
        (arm2set'' (rs,ms,st,ud) s = arm2set'' (rs,ms,st,ud) s'))) ==>
      SPEC ARM_MODEL p {} q``,
  REWRITE_TAC [ARM_SPEC_SEMANTICS] \\ REPEAT STRIP_TAC \\ RES_TAC
  \\ FULL_SIMP_TAC bool_ss [rel_sequence_def,ARM_NEXT_REL_def]
  \\ Q.EXISTS_TAC `SUC 0` \\ METIS_TAC [PAIR]);

val IMP_ARM_SPEC = save_thm("IMP_ARM_SPEC", 
  (RW1 [STAR_COMM] o RW [ARM_SPEC_CODE] o
   SPECL [``CODE_POOL ARM_INSTR {(p,c)} * p'``,
          ``CODE_POOL ARM_INSTR {(p,c)} * q'``]) IMP_ARM_SPEC_LEMMA);

val aS_HIDE = store_thm("aS_HIDE",
  ``~aS = ~aS1 sN * ~aS1 sZ * ~aS1 sC * ~aS1 sV``,
  SIMP_TAC std_ss [SEP_HIDE_def,aS_def,SEP_CLAUSES,FUN_EQ_THM]
  \\ SIMP_TAC std_ss [SEP_EXISTS] \\ METIS_TAC [aS_def,PAIR]);


(* ----------------------------------------------------------------------------- *)
(* Improved memory predicates                                                    *)
(* ----------------------------------------------------------------------------- *)

val aMEMORY_SET_def = Define `
  aMEMORY_SET df f = { aMem (ADDR30 a) (f a) | a | a IN df /\ ALIGNED a }`;

val aMEMORY_def = Define `aMEMORY df f = SEP_EQ (aMEMORY_SET df f)`;

val ADDR30_11 = prove(
  ``!a a'. ALIGNED a /\ ALIGNED a' /\ (ADDR30 a = ADDR30 a') ==> (a = a')``,
  METIS_TAC [EXISTS_ADDR30,ALIGNED_def,ADDR30_ADDR32]);

val aMEMORY_INSERT = prove(
  ``!s. ALIGNED a /\ ~(a IN s) ==>
        (aM (ADDR30 a) w * aMEMORY s f = aMEMORY (a INSERT s) ((a =+ w) f))``,
  SIMP_TAC bool_ss [FUN_EQ_THM,cond_STAR,aMEMORY_def,APPLY_UPDATE_THM,aM_def]  
  \\ SIMP_TAC std_ss [STAR_def,SEP_EQ_def,SPLIT_def]
  \\ REPEAT STRIP_TAC
  \\ `DISJOINT {aMem (ADDR30 a) w} (aMEMORY_SET s f)` by 
   (SIMP_TAC std_ss [DISJOINT_DEF,EXTENSION,NOT_IN_EMPTY,IN_INTER,
      aMEMORY_SET_def,IN_BIGUNION,GSPECIFICATION,IN_INSERT,arm_el_11]   
    \\ STRIP_TAC \\ CCONTR_TAC \\ FULL_SIMP_TAC std_ss []
    \\ `~(a = a')` by METIS_TAC []
    \\ METIS_TAC [ADDR30_11,ADDR30_def])
  \\ `{aMem (ADDR30 a) w} UNION aMEMORY_SET s f =
      aMEMORY_SET (a INSERT s) ((a =+ w) f)` by 
   (SIMP_TAC std_ss [IN_UNION,EXTENSION,NOT_IN_EMPTY,IN_INTER,IN_INSERT,
                     aMEMORY_SET_def,IN_BIGUNION,GSPECIFICATION]
    \\ METIS_TAC [APPLY_UPDATE_THM])
  \\ ASM_SIMP_TAC bool_ss [] \\ METIS_TAC []);
    
val aMEMORY_INTRO = store_thm("aMEMORY_INTRO",
  ``SPEC ARM_MODEL (aM (ADDR30 a) v * P) c (aM (ADDR30 a) w * Q) ==>
    ALIGNED a /\ a IN df ==>
    SPEC ARM_MODEL (aMEMORY df ((a =+ v) f) * P) c (aMEMORY df ((a =+ w) f) * Q)``,
  REPEAT STRIP_TAC
  \\ (IMP_RES_TAC o GEN_ALL o REWRITE_RULE [AND_IMP_INTRO] o 
     SIMP_RULE std_ss [INSERT_DELETE,IN_DELETE] o
     DISCH ``a:word32 IN df`` o Q.SPEC `df DELETE a` o GSYM) aMEMORY_INSERT
  \\ ASM_REWRITE_TAC []
  \\ ONCE_REWRITE_TAC [STAR_COMM] \\ REWRITE_TAC [STAR_ASSOC]
  \\ MATCH_MP_TAC SPEC_FRAME
  \\ FULL_SIMP_TAC bool_ss [AC STAR_COMM STAR_ASSOC]);


val _ = export_theory();