
open HolKernel boolLib bossLib Parse pred_setTheory; 
val _ = new_theory "set_sep";


infix \\
val op \\ = op THEN;


(* ---- definitions ---- *)

val one_def    = Define `one x = \s. (s = {x})`;
val emp_def    = Define `emp = \s. (s = {})`;
val cond_def   = Define `cond c = \s. (s = {}) /\ c`;
val SEP_F_def  = Define `SEP_F s = F`;
val SPLIT_def  = Define `SPLIT (s:'a set) (u,v) = (u UNION v = s) /\ DISJOINT u v`;
val STAR_def   = Define `STAR p q = (\s. ?u v. SPLIT s (u,v) /\ p u /\ q v)`;
val SEP_EQ_def = Define `SEP_EQ x = \s. s = x`;

val SEP_EXISTS = new_binder_definition("SEP_EXISTS",
  ``($SEP_EXISTS) = \f s:'a set. $? (\y. f y s)``);

val SEP_HIDE_def = Define `SEP_HIDE p = SEP_EXISTS x. p x`;
val SEP_DISJ_def = Define `SEP_DISJ p q = (\s. p s \/ q s)`;

val _ = overload_on ("*",Term`STAR`);
val _ = overload_on ("~",Term`SEP_HIDE`);
val _ = overload_on ("\\/",Term`SEP_DISJ`);

val sidecond_def = Define `sidecond = cond`;
val precond_def  = Define `precond = cond`;

val SEP_IMP_def  = Define `SEP_IMP p q = !s. p s ==> q s`;


(* ---- theorems ---- *)

val SPLIT_ss = rewrites [SPLIT_def,SUBSET_DEF,DISJOINT_DEF,DELETE_DEF,IN_INSERT,SEP_EQ_def,
                         EXTENSION,NOT_IN_EMPTY,IN_DEF,IN_UNION,IN_INTER,IN_DIFF];

val SPLIT_TAC = FULL_SIMP_TAC (pure_ss++SPLIT_ss) [] \\ METIS_TAC [];

val STAR_SYM = store_thm("STAR_COMM",
  ``!p:'a set->bool q. p * q = q * p``,
  REWRITE_TAC [STAR_def,SPLIT_def,DISJOINT_DEF]
  \\ METIS_TAC [UNION_COMM,INTER_COMM,CONJ_SYM,CONJ_ASSOC]);

val STAR_ASSOC_LEMMA = prove(
  ``!x p:'a set->bool q r. (p * (q * r)) x ==> ((p * q) * r) x``,
  SIMP_TAC std_ss [STAR_def] \\ REPEAT STRIP_TAC
  \\ Q.EXISTS_TAC `u UNION u'` \\ Q.EXISTS_TAC `v'`
  \\ STRIP_TAC THEN1 SPLIT_TAC
  \\ ASM_SIMP_TAC bool_ss []
  \\ Q.EXISTS_TAC `u` \\ Q.EXISTS_TAC `u'` \\ SPLIT_TAC);

val STAR_ASSOC = store_thm("STAR_ASSOC",
  ``!p:'a set->bool q r. p * (q * r) = (p * q) * r``,
  ONCE_REWRITE_TAC [FUN_EQ_THM] \\ METIS_TAC [STAR_ASSOC_LEMMA,STAR_SYM]);

val SEP_CLAUSES = store_thm("SEP_CLAUSES",
  ``!p q t c c'. 
       (((SEP_EXISTS v. p v) * q)  = SEP_EXISTS v. p v * q) /\ 
       ((q * (SEP_EXISTS v. p v))  = SEP_EXISTS v. q * p v) /\ 
       (((SEP_EXISTS v. p v) \/ q) = SEP_EXISTS v. p v \/ q) /\ 
       ((q \/ (SEP_EXISTS v. p v)) = SEP_EXISTS v. q \/ p v) /\ 
       ((SEP_EXISTS v. q) = q) /\  ((SEP_EXISTS v. p v * cond (v = x)) = p x) /\
       (q \/ SEP_F = q) /\ (SEP_F \/ q = q) /\ (SEP_F * q = SEP_F) /\ (q * SEP_F = SEP_F) /\
       (r \/ r = r) /\ (q * (r \/ t) = q * r \/ q * t) /\ ((r \/ t) * q = r * q \/ t * q) /\ 
       (cond c \/ cond c' = cond (c \/ c')) /\ (cond c * cond c' = cond (c /\ c')) /\
       (cond T = emp) /\ (cond F = SEP_F) /\  (emp * q = q) /\ (q * emp = q)``,
  ONCE_REWRITE_TAC [FUN_EQ_THM]
  \\ SIMP_TAC std_ss [SEP_EXISTS,STAR_def,SEP_DISJ_def,cond_def,SEP_F_def,emp_def] 
  \\ SPLIT_TAC);

val SPLIT_LEMMA = prove(
  ``!s t v. SPLIT s (t,v) = (v = s DIFF t) /\ t SUBSET s``,SPLIT_TAC);  

val cond_STAR = store_thm("cond_STAR",
  ``!c s p. ((cond c * p) s = c /\ p s) /\ ((p * cond c) s = c /\ p s)``,
  Cases \\ SIMP_TAC std_ss [SEP_CLAUSES] \\ SIMP_TAC std_ss [SEP_F_def]);

val one_STAR = store_thm("one_STAR",
  ``!x s p. (one x * p) s = x IN s /\ p (s DELETE x)``,
  SIMP_TAC std_ss [STAR_def,one_def,SPLIT_LEMMA,DELETE_DEF,INSERT_SUBSET,EMPTY_SUBSET]); 
  
val EQ_STAR = store_thm("EQ_STAR",
  ``!p s t. (SEP_EQ t * p) s = p (s DIFF t) /\ t SUBSET s``,
  SIMP_TAC std_ss [SEP_EQ_def,STAR_def,SPLIT_LEMMA] \\ METIS_TAC []);

val SEP_IMP_REFL = store_thm("SEP_IMP_REFL",
  ``!p. SEP_IMP p p``,
  SIMP_TAC std_ss [SEP_IMP_def]);

val SEP_IMP_TRANS = store_thm("SEP_IMP_TRANS",
  ``!p q r. SEP_IMP p q /\ SEP_IMP q r ==> SEP_IMP p r``,
  SIMP_TAC std_ss [SEP_IMP_def] \\ METIS_TAC []);

val SEP_IMP_FRAME = store_thm("SEP_IMP_FRAME",
  ``!p q. SEP_IMP p q ==> !r. SEP_IMP (p * r) (q * r)``,
  SIMP_TAC std_ss [SEP_IMP_def,STAR_def] \\ REPEAT STRIP_TAC
  \\ Q.EXISTS_TAC `u` \\ Q.EXISTS_TAC `v` \\ METIS_TAC []);

val SEP_IMP_MOVE_COND = store_thm("SEP_IMP_MOVE_COND",
  ``!c p q. SEP_IMP (p * cond c) q = c ==> SEP_IMP p q``,
  Cases \\ SIMP_TAC bool_ss [SEP_CLAUSES] \\ SIMP_TAC std_ss [SEP_IMP_def,SEP_F_def]);

val SEP_IMP_emp = store_thm("SEP_IMP_emp",
  ``!p. SEP_IMP emp p = p {}``,SIMP_TAC std_ss [SEP_IMP_def,emp_def]);

val SEP_IMP_cond = store_thm("SEP_IMP_cond",
  ``!g h. SEP_IMP (cond g) (cond h) = g ==> h``,
  SIMP_TAC std_ss [SEP_IMP_def,cond_def]);

val SEP_IMP_STAR = store_thm("SEP_IMP_STAR",
  ``!p p' q q'. SEP_IMP p p' /\ SEP_IMP q q' ==> SEP_IMP (p * q) (p' * q')``,
  SIMP_TAC std_ss [SEP_IMP_def,STAR_def] \\ METIS_TAC []);

val SEP_IMP_EQ = store_thm("SEP_IMP_EQ",
  ``!p q. (p = q) = SEP_IMP p q /\ SEP_IMP q p``,
  FULL_SIMP_TAC bool_ss [SEP_IMP_def,FUN_EQ_THM] \\ METIS_TAC []);

val _ = export_theory();
