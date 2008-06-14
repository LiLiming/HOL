
open HolKernel boolLib bossLib Parse;
open pred_setTheory arithmeticTheory whileTheory;

val _ = new_theory "tailrec";

infix \\ 
val op \\ = op THEN;


(* ---- definitions ----- *)

val TAILREC_PRE_def = Define `
  TAILREC_PRE f1 guard precondition (x:'a) = 
    (!k. (!m. m < k ==> guard (FUNPOW f1 m x)) ==> precondition (FUNPOW f1 k x)) /\    
    ?n. ~guard (FUNPOW f1 n x)`;

val TAILREC_def = Define `
  TAILREC f1 (f2:'a->'b) g x = f2 (WHILE g f1 x)`;


(* ---- theorems ---- *)

val TAILREC_PRE_THM = store_thm("TAILREC_PRE_THM",
  ``!f1 g p x. TAILREC_PRE f1 g p (x:'a) = p x /\ (g x ==> TAILREC_PRE f1 g p (f1 x))``,
   REPEAT STRIP_TAC \\ EQ_TAC \\ REWRITE_TAC [TAILREC_PRE_def] \\ STRIP_TAC THENL [
     STRIP_TAC THEN1 METIS_TAC [FUNPOW,DECIDE ``~(n < 0)``]
     \\ REVERSE (REPEAT STRIP_TAC)
     THEN1 (Cases_on `n` \\ FULL_SIMP_TAC std_ss [FUNPOW] \\ METIS_TAC [])
     \\ Q.PAT_ASSUM `!kk. (!m. cc) ==> bb` 
          (MATCH_MP_TAC o REWRITE_RULE [FUNPOW] o Q.SPEC `SUC k`)
     \\ REPEAT STRIP_TAC
     \\ Cases_on `m` \\ FULL_SIMP_TAC bool_ss [FUNPOW,DECIDE ``SUC m < SUC n = m < n``],    
     REVERSE (Cases_on `g x`) THENL [     
       REVERSE (REPEAT STRIP_TAC) 
       THEN1 (Q.EXISTS_TAC `0` \\ ASM_SIMP_TAC std_ss [FUNPOW])
       \\ Cases_on `k` \\ ASM_SIMP_TAC std_ss [FUNPOW]
       \\ METIS_TAC [DECIDE ``0 < SUC n``,FUNPOW],
       RES_TAC \\ REVERSE (REPEAT STRIP_TAC) THEN1 METIS_TAC [FUNPOW]
       \\ Cases_on `k` \\ ASM_SIMP_TAC std_ss [FUNPOW]
       \\ Q.PAT_ASSUM `!k. (!m. cc) ==> bb` MATCH_MP_TAC
       \\ METIS_TAC [FUNPOW,DECIDE ``SUC m < SUC n = m < n``]]]);

val TAILREC_PRE_INDUCT = store_thm("TAILREC_PRE_INDUCT",
  ``!P. (!x. TAILREC_PRE f1 g p x /\ p x /\ g x /\ P (f1 x) ==> P x) /\
        (!x. TAILREC_PRE f1 g p x /\ p x /\ ~g x ==> P x) ==>
        (!x. TAILREC_PRE f1 g p x ==> P (x:'a))``,
  NTAC 4 STRIP_TAC \\ `?n. ~g (FUNPOW f1 n x)` by METIS_TAC [TAILREC_PRE_def]
  \\ Q.PAT_ASSUM `~g (FUNPOW f1 n x)` MP_TAC
  \\ Q.PAT_ASSUM `TAILREC_PRE f1 g p x` MP_TAC 
  \\ Q.SPEC_TAC (`x`,`x`) \\ Induct_on `n`
  THEN1 (REWRITE_TAC [FUNPOW] \\ REPEAT STRIP_TAC \\ METIS_TAC [TAILREC_PRE_THM])
  \\ FULL_SIMP_TAC std_ss [FUNPOW] \\ REPEAT STRIP_TAC \\ METIS_TAC [TAILREC_PRE_THM]);

val TAILREC_THM = store_thm("TAILREC_THM",
  ``!f1 (f2:'a->'b) g x. TAILREC f1 f2 g x = if g x then TAILREC f1 f2 g (f1 x) else f2 x``,
  REPEAT STRIP_TAC \\ CONV_TAC (RATOR_CONV (ONCE_REWRITE_CONV [TAILREC_def]))
  \\ ONCE_REWRITE_TAC [WHILE] \\ REWRITE_TAC [TAILREC_def] \\ METIS_TAC []);


val _ = export_theory();