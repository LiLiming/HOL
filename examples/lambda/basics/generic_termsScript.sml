(* this is an -*- sml -*- file *)
open HolKernel Parse boolLib

open bossLib binderLib
open basic_swapTheory nomsetTheory
open pred_setTheory
open BasicProvers

open lcsymtacs

fun Store_Thm(s, t, tac) = (store_thm(s,t,tac) before export_rewrites [s])
fun Save_Thm(s, th) = (save_thm(s, th) before export_rewrites [s])

val _ = new_theory "generic_terms"
(* could perform quotient now *)

val _ = Hol_datatype `
  pregterm = var of string => 'v
           | app of 'nb => pregterm list
           | lam of string => 'b => pregterm list => pregterm list
`;

val fv_def = Define `
  (fv (var s vv) = {s}) ∧
  (fv (app nbv ts) = fvl ts) ∧
  (fv (lam v bv bndts unbndts) = (fvl bndts DELETE v) ∪ fvl unbndts) ∧
  (fvl [] = ∅) ∧
  (fvl (h::ts) = fv h ∪ fvl ts)`
val _ = export_rewrites ["fv_def"]

val oldind = TypeBase.induction_of ``:(α,β,γ)pregterm``

val pind = prove(
  ``∀P.
      (∀s vv. P (var s vv)) ∧
      (∀nbv ts. (∀e. MEM e ts ⇒ P e) ⇒ P (app nbv ts)) ∧
      (∀v bv bndts unbndts.
         (∀e. MEM e bndts ⇒ P e) ∧ (∀e. MEM e unbndts ⇒ P e) ⇒
         P (lam v bv bndts unbndts))
    ⇒
      ∀t. P t``,
  gen_tac >> strip_tac >>
  Q_TAC suff_tac `(∀t. P t) ∧ (∀ts. EVERY P ts)` >- metis_tac [] >>
  ho_match_mp_tac oldind >> srw_tac [][] >> first_x_assum match_mp_tac >>
  full_simp_tac (srw_ss()) [listTheory.EVERY_MEM])

val finite_fv = Store_Thm(
  "finite_fv",
  ``∀t. FINITE (fv t)``,
  Q_TAC suff_tac `(∀t:(α,β,γ)pregterm. FINITE (fv t)) ∧
                  (∀l:(α,β,γ)pregterm list. FINITE (fvl l))` >- srw_tac [][] >>
  ho_match_mp_tac oldind >> srw_tac [][]);

val ptpm_def = Define`
  (ptpm p (var s vv) = var (perm_of p s) vv) ∧
  (ptpm p (app nbv ts) = app nbv (ptpml p ts)) ∧
  (ptpm p (lam v bv bndts unbndts) = lam (perm_of p v)
                                         bv
                                         (ptpml p bndts)
                                         (ptpml p unbndts)) ∧
  (ptpml p [] = []) ∧
  (ptpml p (h::t) = ptpm p h :: ptpml p t)
`;

val ptpml_listpm = store_thm(
  "ptpml_listpm",
  ``∀l. ptpml p l = listpm ptpm p l``,
  Induct >> srw_tac[][ptpm_def]);

val ptpm_thm = Save_Thm(
  "ptpm_thm",
  ptpm_def |> CONJUNCTS |> (fn l => List.take(l, 3)) |> LIST_CONJ
           |> REWRITE_RULE [ptpml_listpm])

val ptpm_nil0 = prove(
  ``(∀t:(α,β,γ)pregterm. ptpm [] t = t) ∧
    (∀l:(α,β,γ)pregterm list. ptpml [] l = l)``,
  ho_match_mp_tac oldind >> srw_tac [][ptpml_listpm])

val ptpm_NIL = Save_Thm(
  "ptpm_NIL",
  CONJUNCT1 ptpm_nil0);

val ptpm_compose0 = prove(
  ``(∀t:(α,β,γ)pregterm. ptpm p1 (ptpm p2 t) = ptpm (p1 ++ p2) t) ∧
    (∀l:(α,β,γ)pregterm list.
        ptpml p1 (ptpml p2 l) = ptpml (p1 ++ p2) l)``,
  ho_match_mp_tac oldind >> srw_tac [][ptpml_listpm, lswapstr_APPEND]);

val permeq_ptpm = prove(
  ``(∀x. lswapstr p1 x = lswapstr p2 x) ⇒
    (∀t:(α,β,γ)pregterm. ptpm p1 t = ptpm p2 t) ∧
    (∀l:(α,β,γ)pregterm list. ptpml p1 l = ptpml p2 l)``,
  strip_tac >> ho_match_mp_tac oldind >> srw_tac [][ptpml_listpm]);

val ptpm_is_perm = Store_Thm(
  "ptpm_is_perm",
  ``is_perm ptpm``,
  srw_tac [][is_perm_def, ptpm_compose0, permeq_def, FUN_EQ_THM,
             permeq_ptpm]);

val ptpm_INVERSE = Store_Thm(
  "ptpm_INVERSE",
  ``(ptpm p (ptpm (REVERSE p) t) = t) /\
    (ptpm (REVERSE p) (ptpm p t) = t)``,
  srw_tac [][is_perm_inverse]);

val ptpm_id_front = Store_Thm(
  "ptpm_id_front",
  ``!x t. ptpm ((x,x)::t) M = ptpm t M``,
  srw_tac [][is_perm_id])

val ptpm_sing_inv = Store_Thm(
  "ptpm_sing_inv",
  ``ptpm [h] (ptpm [h] t) = t``,
  srw_tac [][is_perm_sing_inv]);

val ptpml_sing_inv = prove(
  ``ptpml [h] (ptpml [h] l) = l``,
  srw_tac [boolSimps.ETA_ss][ptpml_listpm, is_perm_sing_inv, is_perm_nil]);

val ptpml_id_front = prove(
  ``ptpml ((x,x)::t) l = ptpml t l``,
  srw_tac [boolSimps.ETA_ss][ptpml_listpm, is_perm_id]);


val ptpm_fv = Store_Thm(
  "ptpm_fv",
  ``(∀t:(α,β,γ)pregterm. fv (ptpm p t) = ssetpm p (fv t)) ∧
    (∀l:(α,β,γ)pregterm list. fvl (listpm ptpm p l) = ssetpm p (fvl l))``,
  ho_match_mp_tac oldind >> srw_tac[][perm_INSERT, perm_DELETE, perm_UNION]);

val allatoms_def = Define`
  (allatoms (var s vv) = {s}) ∧
  (allatoms (app nbv ts) = allatomsl ts) ∧
  (allatoms (lam v bv bndts unbndts) =
     v INSERT allatomsl bndts ∪ allatomsl unbndts) ∧
  (allatomsl [] = ∅) ∧
  (allatomsl (t::ts) = allatoms t ∪ allatomsl ts)
`;

val allatoms_finite = Store_Thm(
  "allatoms_finite",
  ``(∀t:(α,β,γ)pregterm. FINITE (allatoms t)) ∧
    (∀l:(α,β,γ)pregterm list. FINITE (allatomsl l))``,
  ho_match_mp_tac oldind >> srw_tac [][allatoms_def]);

val allatoms_supports = store_thm(
  "allatoms_supports",
  ``(∀t:(α,β,γ)pregterm. support ptpm t (allatoms t)) ∧
    (∀l:(α,β,γ)pregterm list. support (listpm ptpm) l (allatomsl l))``,
  simp_tac (srw_ss())[support_def] >>
  ho_match_mp_tac oldind >> srw_tac [][allatoms_def]);

val allatoms_fresh = store_thm(
  "allatoms_fresh",
  ``x ∉ allatoms t ∧ y ∉ allatoms t ==> (ptpm [(x,y)] t = t)``,
  METIS_TAC [allatoms_supports, support_def]);

val allatoms_apart = store_thm(
  "allatoms_apart",
  ``(∀t:(α,β,γ)pregterm a b.
       a ∉ allatoms t /\ b ∈ allatoms t ⇒ ptpm [(a,b)] t ≠ t) ∧
    (∀l:(α,β,γ)pregterm list a b.
       a ∉ allatomsl l ∧ b ∈ allatomsl l ⇒ listpm ptpm [(a,b)] l ≠ l)``,
  ho_match_mp_tac oldind >> srw_tac [][allatoms_def] >>
  srw_tac [][swapstr_def]);

val allatoms_supp = store_thm(
  "allatoms_supp",
  ``supp ptpm t = allatoms t``,
  MATCH_MP_TAC supp_unique THEN
  SRW_TAC [][allatoms_supports, SUBSET_DEF] THEN
  FULL_SIMP_TAC (srw_ss()) [support_def] THEN
  SPOSE_NOT_THEN ASSUME_TAC THEN
  `?y. ~(y IN allatoms t) /\ ~(y IN s')`
     by (Q.SPEC_THEN `allatoms t UNION s'` MP_TAC NEW_def THEN
         SRW_TAC [][] THEN METIS_TAC []) THEN
  METIS_TAC [allatoms_apart]);

val allatoms_perm = store_thm(
  "allatoms_perm",
  ``(∀t:(α,β,γ)pregterm. allatoms (ptpm p t) = ssetpm p (allatoms t)) ∧
    (∀l:(α,β,γ)pregterm list.
      allatomsl (listpm ptpm p l) = ssetpm p (allatomsl l))``,
  ho_match_mp_tac oldind >>
  srw_tac [][allatoms_def, perm_INSERT, perm_UNION]);

val (aeq_rules, aeq_ind, aeq_cases) = Hol_reln`
  (!s vv. aeq (var s vv) (var s vv)) /\
  (!nbv ts us. aeql ts us ==> aeq (app nbv ts) (app nbv us)) /\
  (!u v bv z bndts1 bndts2 us1 us2.
      aeql us1 us2 ∧
      aeql (ptpml [(u,z)] bndts1) (ptpml [(v,z)] bndts2) ∧
      z ∉ allatomsl bndts1 ∧ z ∉  allatomsl bndts2 ∧ z ≠ u ∧ z ≠ v ⇒
      aeq (lam u bv bndts1 us1) (lam v bv bndts2 us2)) ∧
  aeql [] [] ∧
  (∀h1 h2 t1 t2. aeq h1 h2 ∧ aeql t1 t2 ⇒ aeql (h1::t1) (h2::t2))
`;

val aeq_app = List.nth(CONJUNCTS aeq_rules, 1)
val aeq_lam = List.nth(CONJUNCTS aeq_rules, 2)

val aeq_distinct = store_thm(
  "aeq_distinct",
  ``~(aeq (var s vv) (app nbv ts)) /\ ~(aeq (var s vv) (lam v bv ts us)) /\
    ~(aeq (app nbv ts) (lam v bv ts us))``,
  ONCE_REWRITE_TAC [aeq_cases] THEN SRW_TAC [][]);

val ptpm_sing_to_back = store_thm(
  "ptpm_sing_to_back",
  ``ptpm [(perm_of p u, perm_of p v)] (ptpm p t) = ptpm p (ptpm [(u,v)] t)``,
  srw_tac [][is_perm_sing_to_back]);

val ptpml_sing_to_back = store_thm(
  "ptpml_sing_to_back",
  ``ptpml [(perm_of p u, perm_of p v)] (ptpml p l) =
    ptpml p (ptpml [(u,v)] l)``,
  srw_tac [][ptpml_listpm, is_perm_sing_to_back])

val aeq_ptpm_lemma = store_thm(
  "aeq_ptpm_lemma",
  ``(!t:(α,β,γ)pregterm u. aeq t u ==> !p. aeq (ptpm p t) (ptpm p u)) ∧
    (∀ts:(α,β,γ)pregterm list us.
      aeql ts us ⇒ ∀π. aeql (listpm ptpm π ts) (listpm ptpm π us)) ``,
  ho_match_mp_tac aeq_ind >> srw_tac [][aeq_rules, ptpml_listpm] >>
  match_mp_tac aeq_lam >>
  Q.EXISTS_TAC `lswapstr p z` THEN
  srw_tac [][allatoms_perm, ptpm_sing_to_back, perm_IN,
             ptpml_listpm, is_perm_sing_to_back]);

val aeq_ptpm_eqn = store_thm(
  "aeq_ptpm_eqn",
  ``aeq (ptpm p t) u = aeq t (ptpm (REVERSE p) u)``,
  METIS_TAC [aeq_ptpm_lemma, ptpm_INVERSE]);

val aeql_ptpm_eqn = store_thm(
  "aeql_ptpm_eqn",
  ``aeql (listpm ptpm p l1) l2 = aeql l1 (listpm ptpm p⁻¹ l2)``,
  METIS_TAC [aeq_ptpm_lemma, is_perm_inverse, ptpm_is_perm, listpm_is_perm]);

val IN_fvl = prove(
  ``x ∈ fvl tl ⇔ ∃e. MEM e tl ∧ x ∈ fv e``,
  Induct_on `tl` >> srw_tac [boolSimps.DNF_ss][AC DISJ_ASSOC DISJ_COMM]);

val IN_allatomsl = prove(
  ``x ∈ allatomsl tl ⇔ ∃t. MEM t tl ∧ x ∈ allatoms t``,
  Induct_on `tl` >> srw_tac [boolSimps.DNF_ss][allatoms_def]);

val fv_SUBSET_allatoms = store_thm(
  "fv_SUBSET_allatoms",
  ``(∀t:(α,β,γ)pregterm. fv t SUBSET allatoms t) ∧
    (∀l:(α,β,γ)pregterm list. fvl l ⊆ allatomsl l)``,
  SIMP_TAC (srw_ss()) [SUBSET_DEF] >> ho_match_mp_tac oldind>>
  srw_tac [][allatoms_def] >> metis_tac []);

val aeq_fv = store_thm(
  "aeq_fv",
  ``(!t:(α,β,γ)pregterm u. aeq t u ==> (fv t = fv u)) ∧
    (∀ts:(α,β,γ)pregterm list us. aeql ts us ⇒ (fvl ts = fvl us))``,
  ho_match_mp_tac aeq_ind >>
  srw_tac [][EXTENSION, ptpm_fv, perm_IN, ptpml_listpm] THEN
  Cases_on `x ∈ fvl us` >> srw_tac [][] >>
  Cases_on `x = u` >> srw_tac [][] THENL [
    Cases_on `u = v` THEN SRW_TAC [][] THEN
    FIRST_X_ASSUM (Q.SPEC_THEN `swapstr v z u` (MP_TAC o SYM)) THEN
    SRW_TAC [][] THEN SRW_TAC [][swapstr_def] THEN
    METIS_TAC [fv_SUBSET_allatoms, SUBSET_DEF],
    Cases_on `x = v` THEN SRW_TAC [][] THENL [
      FIRST_X_ASSUM (Q.SPEC_THEN `swapstr u z v` MP_TAC) THEN
      SRW_TAC [][] THEN SRW_TAC [][swapstr_def] THEN
      METIS_TAC [fv_SUBSET_allatoms, SUBSET_DEF],
      Cases_on `z = x` THEN SRW_TAC [][] THENL [
        METIS_TAC [fv_SUBSET_allatoms, SUBSET_DEF],
        FIRST_X_ASSUM (Q.SPEC_THEN `x` MP_TAC) THEN
        SRW_TAC [][swapstr_def]
      ]
    ]
  ]);

val aeq_refl = Store_Thm(
  "aeq_refl",
  ``(∀t:(α,β,γ)pregterm. aeq t t) ∧ (∀l:(α,β,γ)pregterm list. aeql l l)``,
  ho_match_mp_tac oldind >> asm_simp_tac (srw_ss())[aeq_rules] >>
  REPEAT gen_tac >> strip_tac >>
  MAP_EVERY Q.X_GEN_TAC [`b`, `s`] >>
  MATCH_MP_TAC aeq_lam >>
  SRW_TAC [][aeql_ptpm_eqn, ptpml_listpm] THEN
  srw_tac [][ptpm_nil0, GSYM ptpml_listpm] >>
  Q.SPEC_THEN `s INSERT allatomsl l` MP_TAC NEW_def THEN SRW_TAC [][] THEN
  METIS_TAC []);

val ptpm_flip_args = store_thm(
  "ptpm_flip_args",
  ``!x y t. ptpm ((y,x)::t) M = ptpm ((x,y)::t) M``,
  srw_tac [][is_perm_flip_args]);

val ptpml_flip_args = prove(
  ``ptpml ((y,x)::t) l = ptpml ((x,y)::t) l``,
  srw_tac [][is_perm_flip_args, ptpml_listpm]);

val aeq_sym = store_thm(
  "aeq_sym",
  ``(∀t:(α,β,γ)pregterm u. aeq t u ==> aeq u t) ∧
    (∀l1:(α,β,γ)pregterm list l2. aeql l1 l2 ==> aeql l2 l1)``,
  ho_match_mp_tac aeq_ind >> srw_tac [][aeq_rules] >>
  metis_tac [aeq_lam]);

val aeq_var_inversion = store_thm(
  "aeq_var_inversion",
  ``aeq (var vv s) t = (t = var vv s)``,
  srw_tac [][Once aeq_cases]);

val aeq_app_inversion = store_thm(
  "aeq_app_inversion",
  ``aeq (app nbv ts) v = ?ts'. (v = app nbv ts') /\ aeql ts ts'``,
  simp_tac (srw_ss()) [Once aeq_cases, SimpLHS])

val aeq_lam_inversion = store_thm(
  "aeq_lam_inversion",
  ``aeq (lam v bv bndts unbndts) N =
      ∃z v' bndts' unbndts'.
        (N = lam v' bv bndts' unbndts') ∧ z ≠ v' ∧ z ≠ v ∧
        z ∉ allatomsl bndts ∧ z ∉ allatomsl bndts' ∧
        aeql (ptpml [(v,z)] bndts) (ptpml [(v',z)] bndts') ∧
        aeql unbndts unbndts'``,
  srw_tac [][Once aeq_cases, SimpLHS] >> metis_tac []);

val aeq_ptm_11 = store_thm(
  "aeq_ptm_11",
  ``(aeq (var s1 vv1) (var s2 vv2) = (s1 = s2) ∧ (vv1 = vv2)) /\
    (aeq (app nbv1 ts1) (app nbv2 ts2) = (nbv1 = nbv2) ∧ aeql ts1 ts2) ∧
    (aeq (lam v bv1 bndts1 unbndts1) (lam v bv2 bndts2 unbndts2) =
      (bv1 = bv2) ∧ aeql bndts1 bndts2 ∧ aeql unbndts1 unbndts2)``,
  SRW_TAC [][aeq_app_inversion, aeq_lam_inversion, aeq_ptpm_eqn,
             aeq_var_inversion, EQ_IMP_THM]
  THENL [
    full_simp_tac (srw_ss() ++ boolSimps.ETA_ss) [aeql_ptpm_eqn, ptpml_listpm,
                                                  is_perm_nil],
    srw_tac [][],
    Q_TAC (NEW_TAC "z") `v INSERT allatomsl bndts1 ∪ allatomsl bndts2` THEN
    Q.EXISTS_TAC `z` >>
    srw_tac [boolSimps.ETA_ss][aeql_ptpm_eqn, ptpml_listpm, is_perm_nil]
  ]);

val aeq_strong_ind = theorem "aeq_strongind"

val ptpml_sing_to_back' = prove(
  ``ptpml p (ptpml [(u,v)] tl) =
       ptpml [(lswapstr p u, lswapstr p v)] (ptpml p tl)``,
  simp_tac (srw_ss()) [ptpml_listpm, is_perm_sing_to_back]);

val ptpml_fresh =
  allatoms_supports |> CONJUNCT2 |>
  SIMP_RULE (srw_ss()) [support_def, GSYM ptpml_listpm]

(* proof follows that on p169 of Andy Pitts, Information and Computation 186
   article: Nominal logic, a first order theory of names and binding *)
val aeq_trans = store_thm(
  "aeq_trans",
  ``(∀t:(α,β,γ)pregterm u. aeq t u ⇒ ∀v. aeq u v ==> aeq t v) ∧
    (∀l1:(α,β,γ)pregterm list l2. aeql l1 l2 ⇒ ∀l3. aeql l2 l3 ⇒ aeql l1 l3)``,
  ho_match_mp_tac aeq_ind >> REPEAT conj_tac >|[
    srw_tac [][],
    srw_tac [][aeq_app_inversion],
    Q_TAC SUFF_TAC
      `∀u v bv z bt1 bt2 ut1 (ut2:(α,β,γ)pregterm list).
         (∀l3. aeql (ptpml [(v,z)] bt2) l3 ⇒ aeql (ptpml [(u,z)] bt1) l3) ∧
         (∀ut3. aeql ut2 ut3 ⇒ aeql ut1 ut3) ∧
         z ∉ allatomsl bt1 ∧ z ∉ allatomsl bt2 ∧ z ≠ u ∧ z ≠ v ⇒
         ∀t3. aeq (lam v bv bt2 ut2) t3 ⇒ aeq (lam u bv bt1 ut1) t3`
          >- metis_tac [] >>
    rpt gen_tac >> strip_tac >> gen_tac >>
    simp_tac (srw_ss()) [SimpL ``$==>``, aeq_lam_inversion] >>
    DISCH_THEN
      (Q.X_CHOOSE_THEN `z2`
         (Q.X_CHOOSE_THEN `w`
              (Q.X_CHOOSE_THEN `bt3`
                  (Q.X_CHOOSE_THEN `ut3` STRIP_ASSUME_TAC)))) >>
    Q_TAC (NEW_TAC "d")
       `{z;z2;u;v;w} ∪ allatomsl bt1 ∪ allatomsl bt2 ∪ allatomsl bt3` >>
    `∀bt3.
       aeql (ptpml [(z,d)] (ptpml [(v,z)] bt2)) (ptpml [(z,d)] bt3) ==>
       aeql (ptpml [(z,d)] (ptpml [(u,z)] bt1)) (ptpml [(z,d)] bt3)`
       by FULL_SIMP_TAC (srw_ss()) [aeql_ptpm_eqn, ptpml_listpm] THEN
    POP_ASSUM
       (Q.SPEC_THEN `ptpml [(z,d)] bt3`
           (ASSUME_TAC o Q.GEN `bt3` o
            SIMP_RULE (srw_ss()) [GSYM ptpml_listpm] o
            SIMP_RULE (srw_ss() ++ boolSimps.ETA_ss)
                      [ptpml_listpm, is_perm_sing_inv, is_perm_nil])) THEN
    POP_ASSUM (MP_TAC o ONCE_REWRITE_RULE [ptpml_sing_to_back']) THEN
    SRW_TAC [][swapstr_def, ptpml_fresh] THEN
    `aeql (ptpml [(z2,d)] (ptpml [(v,z2)] bt2))
          (ptpml [(z2,d)] (ptpml [(w,z2)] bt3))`
       by (srw_tac [boolSimps.ETA_ss]
                   [Once aeql_ptpm_eqn, ptpml_listpm, is_perm_nil] >>
           srw_tac [][GSYM ptpml_listpm]) >>
    POP_ASSUM (MP_TAC o ONCE_REWRITE_RULE [ptpml_sing_to_back']) THEN
    SRW_TAC [][swapstr_def, ptpml_fresh] THEN
    `aeql (ptpml [(u,d)] bt1) (ptpml [(w,d)] bt3)` by METIS_TAC [] THEN
    METIS_TAC [aeq_lam],

    srw_tac [][],
    rpt gen_tac >> strip_tac >> gen_tac >>
    srw_tac [][Once aeq_cases, SimpL ``$==>``] >>
    metis_tac [aeq_rules]
  ]);

open relationTheory
val aeq_equiv = store_thm(
  "aeq_equiv",
  ``!t1 t2. aeq t1 t2 = (aeq t1 = aeq t2)``,
  SIMP_TAC (srw_ss()) [GSYM ALT_equivalence, equivalence_def, reflexive_def,
                       symmetric_def, transitive_def] THEN
  METIS_TAC [aeq_trans, aeq_sym]);

val alt_aeq_lam = store_thm(
  "alt_aeq_lam",
  ``(∀z. z ∉ allatomsl t1 ∧ z ∉ allatomsl t2 ∧ z ≠ u ∧ z ≠ v ⇒
         aeql (ptpml [(u,z)] t1) (ptpml [(v,z)] t2)) ∧
    aeql u1 u2 ⇒
    aeq (lam u bv t1 u1) (lam v bv t2 u2)``,
  strip_tac >> MATCH_MP_TAC aeq_lam >>
  Q_TAC (NEW_TAC "z")
     `allatomsl t1 ∪ allatomsl t2 ∪ {u;v}` >>
  METIS_TAC []);

val aeql_ptpm_eqn' = REWRITE_RULE [GSYM ptpml_listpm] aeql_ptpm_eqn

val fresh_swap = store_thm(
  "fresh_swap",
  ``(∀t:(α,β,γ)pregterm x y. x ∉ fv t ∧ y ∉ fv t ⇒ aeq t (ptpm [(x, y)] t)) ∧
    (∀l:(α,β,γ)pregterm list x y.
       x ∉ fvl l ∧ y ∉ fvl l ⇒ aeql l (ptpml [(x,y)] l))``,
  ho_match_mp_tac oldind >>
  asm_simp_tac (srw_ss()) [aeq_rules, ptpm_nil0, ptpm_def] >>
  map_every qx_gen_tac [`bt`, `ut`] >> strip_tac >>
  map_every qx_gen_tac [`b`, `s`,`x`,`y`] >>
  strip_tac >> srw_tac [][] >>
  match_mp_tac alt_aeq_lam >> rpt strip_tac >>
  srw_tac [][ptpml_id_front, ptpm_nil0] >>
  `z ∉ fvl bt` by METIS_TAC [SUBSET_DEF, fv_SUBSET_allatoms] >| [
    Cases_on `s = x` THEN FULL_SIMP_TAC (srw_ss()) [] THENL [
      ONCE_REWRITE_TAC [GSYM ptpml_sing_to_back] THEN
      SRW_TAC [][swapstr_def, aeql_ptpm_eqn', ptpml_sing_inv,
                 ptpml_id_front, ptpm_nil0],
      ALL_TAC
    ] THEN Cases_on `s = y` THENL [
      FULL_SIMP_TAC (srw_ss()) [] THEN
      ONCE_REWRITE_TAC [GSYM ptpml_sing_to_back] THEN
      SRW_TAC [][swapstr_def, ptpml_flip_args, aeql_ptpm_eqn',
                 ptpml_sing_inv],
      SRW_TAC [][swapstr_def, aeql_ptpm_eqn', ptpml_sing_inv]
    ],
    Cases_on `s = x` THEN1 SRW_TAC [][ptpml_id_front, ptpm_nil0] THEN
    ONCE_REWRITE_TAC [GSYM ptpml_sing_to_back] THEN
    SRW_TAC [][swapstr_def, ptpml_flip_args, aeql_ptpm_eqn', ptpml_sing_inv],
    Cases_on `s = y` THEN1 SRW_TAC [][ptpml_id_front, ptpm_nil0] THEN
    ONCE_REWRITE_TAC [GSYM ptpml_sing_to_back] THEN
    SRW_TAC [][swapstr_def, aeql_ptpm_eqn', ptpml_sing_inv]
  ]);

(*
val lam_aeq_thm = store_thm(
  "lam_aeq_thm",
  ``aeq (lam u t1) (lam v t2) =
       (u = v) /\ aeq t1 t2 \/
       ~(u = v) /\ ~(u IN fv t2) /\ aeq t1 (ptpm [(u,v)] t2)``,
  SIMP_TAC (srw_ss()) [EQ_IMP_THM, DISJ_IMP_THM] THEN REPEAT CONJ_TAC THENL [
    SRW_TAC [][aeq_lam_inversion] THEN
    `~(z IN fv t1) /\ ~(z IN fv t2)`
       by METIS_TAC [SUBSET_DEF, fv_SUBSET_allatoms] THEN
    Cases_on `u = v` THEN1 FULL_SIMP_TAC (srw_ss()) [aeq_ptpm_eqn] THEN
    `~(u IN fv t2)`
        by (STRIP_TAC THEN
            `u IN fv (ptpm [(v,z)] t2)`
               by SRW_TAC [][ptpm_fv, perm_IN, swapstr_def] THEN
            `u IN fv (ptpm [(u,z)] t1)` by METIS_TAC [aeq_fv] THEN
            FULL_SIMP_TAC (srw_ss()) [ptpm_fv, perm_IN, swapstr_def]) THEN
    FULL_SIMP_TAC (srw_ss()) [aeq_ptpm_eqn] THEN
    Q.PAT_ASSUM `aeq X Y` MP_TAC THEN
    ONCE_REWRITE_TAC [GSYM ptpm_sing_to_back] THEN
    SRW_TAC [][swapstr_def] THEN
    MATCH_MP_TAC aeq_trans THEN
    Q.EXISTS_TAC `ptpm [(u,v)] (ptpm [(u,z)] t2)`  THEN
    FULL_SIMP_TAC (srw_ss()) [ptpm_flip_args, aeq_ptpm_eqn, fresh_swap],

    SRW_TAC [][] THEN MATCH_MP_TAC alt_aeq_lam THEN SRW_TAC [][aeq_ptpm_eqn],

    SRW_TAC [][] THEN MATCH_MP_TAC alt_aeq_lam THEN
    SRW_TAC [][aeq_ptpm_eqn] THEN
    `~(z IN fv t2)` by METIS_TAC [SUBSET_DEF, fv_SUBSET_allatoms] THEN
    ONCE_REWRITE_TAC [GSYM ptpm_sing_to_back] THEN
    SRW_TAC [][swapstr_def, ptpm_flip_args] THEN
    MATCH_MP_TAC aeq_trans THEN Q.EXISTS_TAC `ptpm [(u,v)] t2` THEN
    SRW_TAC [][aeq_ptpm_eqn, fresh_swap]
  ]);

val lam_respects_aeq = store_thm(
  "lam_respects_aeq",
  ``!v t1 t2. aeq t1 t2 ==> aeq (lam v t1) (lam v t2)``,
  SRW_TAC [][] THEN MATCH_MP_TAC aeq_lam THEN SRW_TAC [][aeq_ptpm_eqn] THEN
  Q.SPEC_THEN `v INSERT allatoms t1 UNION allatoms t2` MP_TAC NEW_def THEN
  SRW_TAC [][] THEN METIS_TAC []);

val app_respects_aeq = aeq_app

val var_respects_aeq = store_thm(
  "var_respects_aeq",
  ``!s1 s2. (s1 = s2) ==> aeq (var s1) (var s2)``,
  SRW_TAC [][]);

val _ = export_theory ();



(* show connection of with nomset concepts *)

val lamf = ``lm : string -> 'a -> 'a``
val h = ``\a:string. ^lamf a ((s:(string # string) list->'a)
                                 (pi ++ [(a,v)]))``

val lamf_supp_t = ``supp (fnpm perm_of (fnpm apm apm)) ^lamf``

val perm_fnapp = prove(
  ``is_perm pm1 /\ is_perm pm2 ==>
    (fnpm pm1 pm2 pi f (pm1 pi x) = pm2 pi (f x))``,
  SRW_TAC [][fnpm_def, is_perm_inverse]);

val support_freshf = prove(
  ``is_perm pm1 /\ is_perm pm2 /\ ~(x IN A) /\ ~(y IN A) /\
    support (fnpm pm1 pm2) f A ==>
    !a. pm2 [(x,y)] (f a) = f (pm1 [(x,y)] a)``,
  SRW_TAC [][support_def] THEN
  `pm2 [(x,y)] (f a) = fnpm pm1 pm2 [(x,y)] f (pm1 [(x,y)] a)`
     by SRW_TAC [][perm_fnapp] THEN
  SRW_TAC [][]);

val lamf_support_t = ``support (fnpm perm_of (fnpm apm apm)) ^lamf A``
val app_support_t = ``support (fnpm apm (fnpm apm apm)) ap A``
val var_support_t = ``support (fnpm perm_of apm) vr A``

val lamf_support_fresh = UNDISCH (UNDISCH (prove(
  ``^lamf_support_t ==> is_perm apm ==>
    !x y v a.
      ~(x IN A) /\ ~(y IN A) ==>
        (apm [(x,y)] (lm v a) = lm (swapstr x y v) (apm [(x,y)] a))``,
  REPEAT STRIP_TAC THEN
  `apm [(x,y)] (lm v a) =
       fnpm apm apm [(x,y)] (lm v) (apm [(x,y)] a)`
     by SRW_TAC [][fnpm_def, is_perm_sing_inv] THEN
  SRW_TAC [][] THEN AP_THM_TAC THEN
  `swapstr x y v = perm_of [(x,y)] v` by SRW_TAC [][] THEN
  POP_ASSUM SUBST1_TAC THEN MATCH_MP_TAC support_freshf THEN
  SRW_TAC [][])))

val h_supp_t = ``supp (fnpm perm_of apm) ^h``

val ctxt00 = ``^lamf_support_t /\ FINITE A /\ is_perm apm``
val ctxt0 =
  ``^ctxt00 /\ support (fnpm cpmpm apm) s sS /\ FINITE sS``

val ssupport_fresh = UNDISCH (UNDISCH (prove(
  ``support (fnpm cpmpm apm) s sS ==>
    is_perm apm ==>
    !x y p.
      ~(x IN sS) /\ ~(y IN sS) ==> (apm [(x,y)] (s p) = s (cpmpm [(x,y)] p))``,
  REPEAT STRIP_TAC THEN
  MATCH_MP_TAC (Q.GEN `A` support_freshf) THEN Q.EXISTS_TAC `sS` THEN
  SRW_TAC [][])));

val h_supported_by = prove(
  ``!v s sS pi.
       ^ctxt0 ==>
       support (fnpm perm_of apm) ^h (v INSERT (A UNION patoms pi UNION sS))``,
  REPEAT STRIP_TAC THEN
  MAP_EVERY ASSUME_TAC [lamf_support_fresh, ssupport_fresh] THEN
  SRW_TAC [][support_def, FUN_EQ_THM, fnpm_def, listpm_APPENDlist]);

val cond16 = ``?a. ~(a IN A) /\ !x. ~(a IN supp apm (^lamf a x))``

val cond16_implies_freshness_ok = prove(
  ``!v s A sS.
       ^ctxt0 /\ ^cond16 ==>
       ?a. ~(a IN ^h_supp_t) /\ ~(a IN supp apm (^h a))``,
  REPEAT STRIP_TAC THEN
  Q.ABBREV_TAC `h = ^h` THEN
  `!b x. ~(b IN A) /\ ~(a = b) ==>
           ~(b IN supp apm (lm b (apm [(a,b)] x)))`
      by (REPEAT GEN_TAC THEN STRIP_TAC THEN
          `lm b = fnpm apm apm [(a,b)] (lm a)`
              by SRW_TAC [][fnpm_def, FUN_EQ_THM, is_perm_sing_inv,
                            lamf_support_fresh] THEN
          SRW_TAC [][fnpm_def, is_perm_sing_inv, perm_supp, perm_IN]) THEN
  Q_TAC (NEW_TAC "z") `{v;a} UNION A UNION sS UNION patoms pi` THEN
  `support (fnpm perm_of apm) h (v INSERT A UNION patoms pi UNION sS)`
     by (UNABBREV_ALL_TAC THEN MATCH_MP_TAC h_supported_by THEN
         SRW_TAC [][]) THEN
  Q.EXISTS_TAC `z` THEN SRW_TAC [][] THENL [
    `~(z IN v INSERT A UNION patoms pi UNION sS)` by SRW_TAC [][] THEN
    `FINITE (v INSERT A UNION patoms pi UNION sS)` by SRW_TAC [][] THEN
    METIS_TAC [supp_smallest, SUBSET_DEF, fnpm_is_perm, perm_of_is_perm],
    Q.UNABBREV_TAC `h` THEN
    FIRST_X_ASSUM
      (Q.SPECL_THEN [`z`, `apm [(a,z)] (s (pi ++ [(z,v)]))`]
         MP_TAC) THEN
    SRW_TAC [][is_perm_sing_inv]
  ]);

val base =
    SPECL [``\(s:string) p. vr (perm_of p s) : 'a``]
          (INST_TYPE [alpha |-> ``:(string # string) list -> 'a``]
                     (TypeBase.axiom_of ``:preterm$preterm``))
val full0 = Q.SPECL [`\t u r1 r2 p. ap (r1 p) (r2 p)`,
                    `\v t s pi. fresh apm ^h`] base

val full = SIMP_RULE (srw_ss()) [FUN_EQ_THM] full0


val fndefn = #2 (dest_exists (concl full))

val swapstr_perm_of = prove(
  ``swapstr x y (perm_of pi s) =
    perm_of (cpmpm [(x,y)] pi) (swapstr x y s)``,
  Induct_on `pi` THEN
  SIMP_TAC (srw_ss()) [pairTheory.FORALL_PROD] THEN
  POP_ASSUM (SUBST1_TAC o SYM) THEN SRW_TAC [][]);

val rawfinite_support = prove(
  ``^fndefn /\ ^ctxt00 /\ ^cond16 /\ ^var_support_t /\ ^app_support_t ==>
    support (fnpm ptpm (fnpm cpmpm apm)) fn A``,
  STRIP_TAC THEN SIMP_TAC (srw_ss()) [support_def, FUN_EQ_THM, fnpm_def] THEN
  Q_TAC SUFF_TAC
        `!t pi x y.  ~(x IN A) /\ ~(y IN A) ==>
                     (apm [(x,y)] (fn (ptpm [(x,y)] t)
                                      (cpmpm [(x,y)] pi)) =
                      fn t pi)`
        THEN1 PROVE_TAC [] THEN
  Induct THENL [
    Q.X_GEN_TAC `s` THEN SRW_TAC [][fnpm_def] THEN
    `(!s. apm [(x,y)] (vr s) = vr (perm_of [(x,y)] s))`
        by (MATCH_MP_TAC support_freshf THEN SRW_TAC [][]) THEN
    SRW_TAC [][swapstr_perm_of, is_perm_sing_inv],

    `!a b pi. apm pi (ap a b) =
              fnpm apm apm pi (ap a) (apm pi b)`
        by SRW_TAC [][fnpm_def, is_perm_inverse] THEN
    SRW_TAC [][] THEN
    `!t. fnpm apm apm [(x,y)] (ap t) = ap (apm [(x,y)] t)`
        by (MATCH_MP_TAC support_freshf THEN SRW_TAC [][]) THEN
    SRW_TAC [][],

    MAP_EVERY Q.X_GEN_TAC [`s`, `pi`, `x`, `y`] THEN SRW_TAC [][fnpm_def] THEN
    Q.MATCH_ABBREV_TAC `apm [(x,y)] (fresh apm g) = fresh apm h` THEN
    `h = fnpm perm_of apm [(x,y)] g`
       by (MAP_EVERY Q.UNABBREV_TAC [`g`, `h`] THEN
           SIMP_TAC (srw_ss()) [FUN_EQ_THM] THEN Q.X_GEN_TAC `b` THEN
           SRW_TAC [][fnpm_def, lamf_support_fresh] THEN
           `cpmpm [(x,y)] pi ++ [(swapstr x y b, swapstr x y s)] =
                cpmpm [(x,y)] (pi ++ [(b,s)])`
              by SRW_TAC [][listpm_APPENDlist] THEN
           SRW_TAC [][]) THEN
    POP_ASSUM (fn th =>
                  Q_TAC SUFF_TAC `fcond apm h` THEN1
                        SRW_TAC [][fresh_equivariant, is_perm_eql,
                                   is_perm_sing_inv, th]) THEN
    UNABBREV_ALL_TAC THEN
    `support (fnpm cpmpm apm) (fn t) (A UNION allatoms t)`
       by (SIMP_TAC (srw_ss()) [support_def, FUN_EQ_THM] THEN
           MAP_EVERY Q.X_GEN_TAC [`c`, `d`] THEN REPEAT STRIP_TAC THEN
           `fnpm cpmpm apm [(c,d)] (fn t) =
            fnpm ptpm (fnpm cpmpm apm) [(c,d)] fn (ptpm [(c,d)] t)`
             by SRW_TAC [][fnpm_def] THEN
           `ptpm [(c,d)] t = t`
             by PROVE_TAC [allatoms_supports, support_def] THEN
           SRW_TAC [][] THEN
           NTAC 2 (POP_ASSUM (K ALL_TAC)) THEN SRW_TAC [][fnpm_def]) THEN
    Q.ABBREV_TAC `bigA = A UNION allatoms t UNION patoms pi` THEN
    `support (fnpm perm_of (fnpm apm apm)) lm bigA /\
     support (fnpm cpmpm apm) (fn t) bigA /\
     support cpmpm pi bigA`
       by FULL_SIMP_TAC (srw_ss()) [support_def, Abbr`bigA`] THEN
    SRW_TAC [][fcond_def] THENL [
      Q.MATCH_ABBREV_TAC `FINITE (supp pm h)` THEN
      Q_TAC SUFF_TAC `?X. FINITE X /\ support pm h X`
            THEN1 METIS_TAC [SUBSET_FINITE, supp_smallest, fnpm_is_perm,
                             perm_of_is_perm] THEN
      Q.EXISTS_TAC `s INSERT A UNION patoms pi UNION (A UNION allatoms t)` THEN
      SRW_TAC [][Abbr`bigA`, Abbr`h`, Abbr`pm`] THEN
      MATCH_MP_TAC h_supported_by THEN
      SRW_TAC [][],

      MATCH_MP_TAC (BETA_RULE cond16_implies_freshness_ok) THEN
      MAP_EVERY Q.EXISTS_TAC [`A`, `A UNION allatoms t`] THEN
      SRW_TAC [][] THEN METIS_TAC []
    ]
  ]);

val eqperms_ok = prove(
  ``^fndefn ==>
    !t p1 p2. (p1 == p2) ==> (fn t p1 = fn t p2)``,
  STRIP_TAC THEN Induct THENL [
    FULL_SIMP_TAC (srw_ss()) [permeq_def],
    METIS_TAC [],
    MAP_EVERY Q.X_GEN_TAC [`s`, `p1`, `p2`] THEN SRW_TAC [][] THEN
    Q_TAC SUFF_TAC `!a. fn t (p1 ++ [(a,s)]) = fn t (p2 ++ [(a,s)])` THEN1
          SRW_TAC [][] THEN
    GEN_TAC THEN FIRST_X_ASSUM MATCH_MP_TAC THEN
    MATCH_MP_TAC app_permeq_monotone THEN
    SRW_TAC [][permeq_refl]
  ]);

val fn_support_fresh = UNDISCH (UNDISCH (prove(
  ``support (fnpm ptpm (fnpm cpmpm apm)) fn A ==>
    is_perm apm ==>
    !x y M p.
       ~(x IN A) /\ ~(y IN A) ==>
       (apm [(x,y)] (fn M p) = fn (ptpm [(x,y)] M) (cpmpm [(x,y)] p))``,
  REPEAT STRIP_TAC THEN
  `apm [(x,y)] (fn M p) =
       fnpm cpmpm apm [(x,y)] (fn M) (cpmpm [(x,y)] p)`
     by SRW_TAC [][fnpm_def, is_perm_sing_inv] THEN
  SRW_TAC [][] THEN AP_THM_TAC THEN
  MATCH_MP_TAC support_freshf THEN SRW_TAC [][])))

val perms_move = prove(
  ``^fndefn /\ ^var_support_t /\ ^app_support_t /\ ^cond16 /\ ^ctxt00 ==>
    !t p1 p2. fn (ptpm p2 t) p1 = fn t (p1 ++ p2)``,
  STRIP_TAC THEN Induct THEN
  TRY (SRW_TAC [][lswapstr_APPEND] THEN
       SRW_TAC [][GSYM lswapstr_APPEND] THEN NO_TAC) THEN
  MAP_EVERY Q.X_GEN_TAC [`s`, `p1`, `p2`] THEN SRW_TAC [][] THEN
  Q.MATCH_ABBREV_TAC `fresh apm f = fresh apm g` THEN
  `support (fnpm ptpm (fnpm cpmpm apm)) fn A`
     by (MATCH_MP_TAC rawfinite_support THEN SRW_TAC [][] THEN
         METIS_TAC []) THEN
  ASSUME_TAC fn_support_fresh THEN
  Q.ABBREV_TAC
    `bigS = s INSERT A UNION allatoms t UNION patoms p1 UNION patoms p2` THEN
  ASSUME_TAC allatoms_fresh THEN
  ASSUME_TAC lamf_support_fresh THEN
  Q.PAT_ASSUM `!p1 p2. fn (ptpm p2 t) p1 = fn t (p1 ++ p2)` (K ALL_TAC) THEN
  `support (fnpm perm_of apm) f bigS /\ support (fnpm perm_of apm) g bigS`
     by (SRW_TAC [][support_def, FUN_EQ_THM, fnpm_def, Abbr`f`, Abbr`g`,
                    Abbr`bigS`, listpm_APPENDlist] THEN
         SRW_TAC [][swapstr_perm_of, swapstr_def]) THEN
  `FINITE bigS` by SRW_TAC [][Abbr`bigS`] THEN
  Q_TAC (NEW_TAC "b") `bigS` THEN
  `~(b IN supp (fnpm perm_of apm) f) /\ ~(b IN supp (fnpm perm_of apm) g)`
      by METIS_TAC [supp_smallest, SUBSET_DEF, fnpm_is_perm,
                    perm_of_is_perm] THEN
  `FINITE (supp (fnpm perm_of apm) f) /\ FINITE (supp (fnpm perm_of apm) g)`
      by METIS_TAC [supp_smallest, SUBSET_FINITE, fnpm_is_perm,
                    perm_of_is_perm] THEN
  `fcond apm f /\ fcond apm g`
      by (SRW_TAC [][fcond_def] THENL [
            `f = \c. lm c ((\p. fn t (p ++ p2)) (p1 ++ [(c, perm_of p2 s)]))`
               by SRW_TAC [][Abbr`f`] THEN
            POP_ASSUM SUBST1_TAC THEN
            MATCH_MP_TAC cond16_implies_freshness_ok THEN
            MAP_EVERY Q.EXISTS_TAC
                      [`A`, `A UNION allatoms t UNION patoms p2`] THEN
            SRW_TAC [][] THENL [
              SRW_TAC [][support_def, fnpm_def, FUN_EQ_THM, listpm_APPENDlist,
                         is_perm_sing_inv],
              METIS_TAC []
            ],
            Q.UNABBREV_TAC `g` THEN
            MATCH_MP_TAC cond16_implies_freshness_ok THEN
            MAP_EVERY Q.EXISTS_TAC [`A`, `A UNION allatoms t`] THEN
            SRW_TAC [][] THENL [
              SRW_TAC [][support_def, FUN_EQ_THM, fnpm_def,
                         is_perm_sing_inv],
              METIS_TAC []
            ]
          ]) THEN
  `(fresh apm f = f b) /\ (fresh apm g = g b)` by METIS_TAC [fresh_thm] THEN
  SRW_TAC [][Abbr`f`, Abbr`g`] THEN
  Q_TAC SUFF_TAC `p1 ++ [(b,perm_of p2 s)] ++ p2 == p1 ++ p2 ++ [(b,s)]`
        THEN1 (STRIP_TAC THEN
               Q_TAC SUFF_TAC
                     `fn t (p1 ++ [(b,perm_of p2 s)] ++ p2) =
                      fn t (p1 ++ p2 ++ [(b,s)])` THEN1 SRW_TAC [][] THEN
               MP_TAC eqperms_ok THEN SRW_TAC [][]) THEN
  REWRITE_TAC [GSYM listTheory.APPEND_ASSOC] THEN
  MATCH_MP_TAC app_permeq_monotone THEN
  SRW_TAC [][permeq_refl] THEN
  `(perm_of p2 b, perm_of p2 s) :: p2 == p2 ++ [(b,s)]`
      by METIS_TAC [permeq_swap_ends, permeq_sym] THEN
  Q_TAC SUFF_TAC `perm_of p2 b = b` THEN1 METIS_TAC [] THEN
  `~(b IN patoms p2)` by FULL_SIMP_TAC (srw_ss()) [Abbr`bigS`] THEN
  SRW_TAC [][perm_of_unchanged]);

val alt_aeq_ind = store_thm(
  "alt_aeq_ind",
  ``(!s. P (var s) (var s)) /\
    (!t1 t2 u1 u2.
         P t1 t2 /\ P u1 u2 ==> P (app t1 u1) (app t2 u2)) /\
    (!u v t1 t2.
         (!z. ~(z IN allatoms t1) /\ ~(z IN allatoms t2) /\ ~(z = u) /\
              ~(z = v) ==> P (ptpm [(u,z)] t1) (ptpm [(v,z)] t2)) ==>
         P (lam u t1) (lam v t2)) ==>
    !t1 t2. aeq t1 t2 ==> P t1 t2``,
  STRIP_TAC THEN
  Q_TAC SUFF_TAC `!t1 t2. aeq t1 t2 ==> !pi. P (ptpm pi t1) (ptpm pi t2)`
        THEN1 METIS_TAC [ptpm_NIL] THEN
  HO_MATCH_MP_TAC aeq_ind THEN SRW_TAC [][] THEN
  FIRST_X_ASSUM MATCH_MP_TAC THEN REPEAT STRIP_TAC THEN
  Q.ABBREV_TAC `zz = perm_of (REVERSE pi) z'` THEN
  `z' = perm_of pi zz` by SRW_TAC [][Abbr`zz`] THEN
  Q_TAC SUFF_TAC `P (ptpm pi (ptpm [(u,zz)] t1)) (ptpm pi (ptpm [(v,zz)] t2))`
        THEN1 SRW_TAC [][ptpm_sing_to_back] THEN
  `~(zz IN allatoms t1) /\ ~(zz IN allatoms t2) /\ ~(zz = u) /\ ~(zz = v)`
        by FULL_SIMP_TAC (srw_ss()) [Abbr`zz`, allatoms_perm, perm_IN,
                                     is_perm_eql] THEN
  REPEAT (FIRST_X_ASSUM
            (K ALL_TAC o assert (free_in ``z':string`` o concl))) THEN
  `(ptpm [(u,zz)] t1 = ptpm [(z,zz)] (ptpm [(u,z)] t1)) /\
   (ptpm [(v,zz)] t2 = ptpm [(z,zz)] (ptpm [(v,z)] t2))`
      by (ONCE_REWRITE_TAC [GSYM ptpm_sing_to_back] THEN
          SRW_TAC [][swapstr_def, allatoms_fresh]) THEN
  METIS_TAC [is_perm_decompose, ptpm_is_perm]);

val fn_respectful = prove(
  ``^fndefn /\ ^var_support_t /\ ^app_support_t /\ ^cond16 /\ ^ctxt00 /\
    aeq t1 t2 ==> !p. fn t1 p = fn t2 p``,
  STRIP_TAC THEN
  Q.UNDISCH_THEN `aeq t1 t2` MP_TAC THEN
  MAP_EVERY Q.ID_SPEC_TAC [`t2`, `t1`] THEN
  HO_MATCH_MP_TAC alt_aeq_ind THEN SRW_TAC [][] THEN
  `!t p1 p2. fn (ptpm p1 t) p2 = fn t (p2 ++ p1)`
      by (MATCH_MP_TAC perms_move THEN SRW_TAC [][] THEN METIS_TAC []) THEN
  POP_ASSUM (ASSUME_TAC o GSYM) THEN SRW_TAC [][] THEN
  Q.MATCH_ABBREV_TAC `fresh apm f = fresh apm g` THEN
  `support (fnpm ptpm (fnpm cpmpm apm)) fn A`
     by (MATCH_MP_TAC rawfinite_support THEN SRW_TAC [][] THEN
         METIS_TAC []) THEN
  Q.ABBREV_TAC
    `bigS = {u;v} UNION A UNION patoms p UNION allatoms t1 UNION
            allatoms t2` THEN
  `support (fnpm perm_of apm) f bigS /\ support (fnpm perm_of apm) g bigS`
     by (SRW_TAC [][support_def, fnpm_def, FUN_EQ_THM, Abbr`f`, Abbr`bigS`,
                    lamf_support_fresh, fn_support_fresh, Abbr`g`] THEN
         ONCE_REWRITE_TAC [GSYM ptpm_sing_to_back] THEN
         SRW_TAC [][] THEN SRW_TAC [][swapstr_def, allatoms_fresh]) THEN
  `FINITE bigS` by SRW_TAC [][Abbr`bigS`] THEN
  `FINITE (supp (fnpm perm_of apm) f) /\ FINITE (supp (fnpm perm_of apm) g)`
     by METIS_TAC [SUBSET_FINITE, supp_smallest, fnpm_is_perm,
                   perm_of_is_perm] THEN
  `fcond apm f /\ fcond apm g`
     by (SRW_TAC [][fcond_def] THENL [
           Q.UNABBREV_TAC `f`,
           Q.UNABBREV_TAC `g`
         ] THEN
         FIRST_X_ASSUM (ASSUME_TAC o GSYM o assert (is_forall o concl)) THEN
         POP_ASSUM (fn th => REWRITE_TAC [th]) THEN
         MATCH_MP_TAC cond16_implies_freshness_ok THENL [
           MAP_EVERY Q.EXISTS_TAC [`A`, `A UNION allatoms t1`],
           MAP_EVERY Q.EXISTS_TAC [`A`, `A UNION allatoms t2`]
         ] THEN SRW_TAC [][] THEN
         SRW_TAC [][support_def, fnpm_def, FUN_EQ_THM, fn_support_fresh,
                    allatoms_fresh, is_perm_sing_inv] THEN
         METIS_TAC []) THEN
  Q_TAC (NEW_TAC "z") `bigS` THEN
  `~(z IN supp (fnpm perm_of apm) f) /\ ~(z IN supp (fnpm perm_of apm) g)`
      by METIS_TAC [supp_smallest, SUBSET_DEF, fnpm_is_perm,
                    perm_of_is_perm] THEN
  `(fresh apm f = f z) /\ (fresh apm g = g z)` by METIS_TAC [fresh_thm] THEN
  SRW_TAC [][Abbr`f`, Abbr`g`, is_perm_flip_args, Abbr`bigS`] THEN
  FULL_SIMP_TAC (srw_ss()) []);

val better_lam_clause0 = prove(
  ``^fndefn /\ ^ctxt00 /\ ^var_support_t /\ ^app_support_t /\ ^cond16 /\
    ~(z = v) /\ ~(z IN A) /\ ~(z IN allatoms t) ==>
    (fn (lam z (ptpm [(z,v)] t)) [] = lm z (fn (ptpm [(z,v)] t) []))``,
  REPEAT STRIP_TAC THEN
  `~(z IN fv t)` by METIS_TAC [SUBSET_DEF, fv_SUBSET_allatoms] THEN
  `aeq (lam z (ptpm [(z,v)] t)) (lam v t)` by SRW_TAC [][lam_aeq_thm] THEN
  `fn (lam z (ptpm [(z,v)] t)) [] = fn (lam v t) []`
     by (MATCH_MP_TAC fn_respectful THEN SRW_TAC [][] THEN METIS_TAC []) THEN
  POP_ASSUM SUBST1_TAC THEN SRW_TAC [][] THEN
  `!t p1 p2. fn (ptpm p2 t) p1 = fn t (p1 ++ p2)`
     by (MATCH_MP_TAC perms_move THEN SRW_TAC [][] THEN METIS_TAC []) THEN
  POP_ASSUM (fn th => SIMP_TAC (srw_ss()) [th]) THEN
  Q.MATCH_ABBREV_TAC `fresh apm f = lm z (fn t [(z,v)])` THEN
  `support (fnpm ptpm (fnpm cpmpm apm)) fn A`
     by (MATCH_MP_TAC rawfinite_support THEN SRW_TAC [][] THEN
         METIS_TAC []) THEN
  Q.ABBREV_TAC `bigS = v INSERT A UNION allatoms t` THEN
  `support (fnpm perm_of apm) f bigS`
     by (SRW_TAC [][lamf_support_fresh, fn_support_fresh, support_def,
                    fnpm_def, FUN_EQ_THM, Abbr`f`, listpm_def, pairpm_def,
                    allatoms_fresh, Abbr`bigS`] THEN
         SRW_TAC [][swapstr_def]) THEN
  `FINITE bigS /\ ~(z IN bigS)` by SRW_TAC [][Abbr`bigS`] THEN
  `~(z IN supp (fnpm perm_of apm) f) /\ FINITE (supp (fnpm perm_of apm) f)`
      by METIS_TAC [supp_smallest, SUBSET_FINITE, SUBSET_DEF, fnpm_is_perm,
                    perm_of_is_perm] THEN
  Q_TAC SUFF_TAC `fcond apm f`
        THEN1 (STRIP_TAC THEN
               `fresh apm f = f z` by METIS_TAC [fresh_thm] THEN
               SRW_TAC [][Abbr`f`]) THEN
  SRW_TAC [][fcond_def] THEN
  Q.UNABBREV_TAC `f` THEN
  MATCH_MP_TAC ((REWRITE_RULE [listTheory.APPEND] o
                 Q.INST [`pi` |-> `[]`]) cond16_implies_freshness_ok) THEN
  MAP_EVERY Q.EXISTS_TAC [`A`, `A UNION allatoms t`] THEN
  SRW_TAC [][] THENL [
    SRW_TAC [][support_def, FUN_EQ_THM, fnpm_def, fn_support_fresh,
               allatoms_fresh, is_perm_sing_inv],
    METIS_TAC []
  ]);

val silly_new_lemma = prove(
  ``~(x = NEW (x INSERT allatoms t)) /\
    ~(NEW (x INSERT allatoms t) IN allatoms t)``,
  Q.SPEC_THEN `x INSERT allatoms t` MP_TAC NEW_def THEN
  SRW_TAC [][]);

val better_lam_clause =
    (REWRITE_RULE [silly_new_lemma] o
     Q.INST [`v` |-> `NEW (z INSERT allatoms t)`] o
     REWRITE_RULE [] o
     SIMP_RULE pure_ss [ptpm_sing_inv, allatoms_perm, perm_IN,
                        perm_of_is_perm, listTheory.REVERSE_DEF,
                        listTheory.APPEND, lswapstr_def, pairTheory.FST,
                        pairTheory.SND, swapstr_def] o
     Q.INST [`t` |-> `ptpm [(z,v)] t`]) better_lam_clause0

val recursion0 = prove(
  ``^cond16 /\ ^ctxt00 /\ ^var_support_t /\ ^app_support_t ==>
    ?f :: respects (aeq ===> (=)).
        ((!s. f (var s) = vr s) /\
         (!t1 t2. f (app t1 t2) = ap (f t1) (f t2)) /\
         (!v t. ~(v IN A) ==> (f (lam v t) = lm v (f t)))) /\
        (!x y t. ~(x IN A) /\ ~(y IN A) ==>
                 (f (ptpm [(x,y)] t) = apm [(x,y)] (f t)))``,
  REPEAT STRIP_TAC THEN
  STRIP_ASSUME_TAC full THEN
  SRW_TAC [][RES_EXISTS_THM, quotientTheory.IN_RESPECTS,
             quotientTheory.FUN_REL] THEN
  Q.EXISTS_TAC `\t. fn t []` THEN REPEAT CONJ_TAC THENL [
    SRW_TAC [][] THEN MATCH_MP_TAC fn_respectful THEN
    SRW_TAC [][] THEN METIS_TAC [],
    SRW_TAC [][],
    SRW_TAC [][],
    REPEAT STRIP_TAC THEN BETA_TAC THEN
    MATCH_MP_TAC better_lam_clause THEN SRW_TAC [][] THEN METIS_TAC [],
    `support (fnpm ptpm (fnpm cpmpm apm)) fn A`
       by (MATCH_MP_TAC rawfinite_support THEN SRW_TAC [][] THEN
           METIS_TAC []) THEN
    ASSUME_TAC fn_support_fresh THEN
    SRW_TAC [][listpm_def]
  ]);

fun mk_def(s,t) =
    {def_name = s ^ "_def", fixity = Prefix, fname = s, func = t};
val app_respects_aeq = List.nth(CONJUNCTS aeq_rules, 1)

val ptpm_fv' = (CONV_RULE (BINDER_CONV
                             (RAND_CONV (SIMP_CONV (srw_ss()) [perm_IN]))) o
                REWRITE_RULE [EXTENSION]) ptpm_fv

val [FV_thm, FV_tpm, simple_induction, tpm_thm, term_distinct, term_11,
     LAM_eq_thm, FRESH_swap0,
     (* tpm_is_perm,*) tm_recursion, FINITE_FV,
     tpm_sing_inv, tpm_NIL, tpm_inverse, tpm_flip_args, tpm_id_front] =
    quotient.define_equivalence_type
    {
     name = "term", equiv = aeq_equiv,
     defs = map mk_def [("LAM", ``lam``), ("@@", ``app``),
                        ("VAR", ``var``), ("FV", ``fv``),
                        ("tpm", ``ptpm``)],
     welldefs = [lam_respects_aeq, app_respects_aeq, var_respects_aeq, aeq_fv,
                 SIMP_RULE bool_ss [GSYM RIGHT_FORALL_IMP_THM] aeq_ptpm_lemma
                 ],
     old_thms = [fv_def, ptpm_fv',
                 TypeBase.induction_of ``:preterm$preterm``, ptpm_def,
                 aeq_distinct, aeq_ptm_11,
                 lam_aeq_thm, fresh_swap, (* ptpm_is_perm,*)
                 Q.INST [`lamf` |-> `lm`] recursion0, finite_fv,
                 ptpm_sing_inv, ptpm_NIL, ptpm_INVERSE, ptpm_flip_args,
                 ptpm_id_front]}
val _ = set_fixity "@@" (Infixl 901);
val _ = set_MLname "@@_def" "APP_def"

(* hide all of preterm's constants *)
val _ = List.app (fn s => remove_ovl_mapping s {Name = s, Thy = "preterm"})
                 ["fv", "var", "app", "lam", "ptpm", "aeq"]

val _ = Save_Thm("FINITE_FV", FINITE_FV);
val _ = Save_Thm("FV_thm", FV_thm);
val _ = Save_Thm("FV_tpm", FV_tpm)
val _ = Save_Thm("term_11", term_11);
val _ = Save_Thm("term_distinct", term_distinct);
val _ = Save_Thm("tpm_NIL", tpm_NIL)
val _ = Save_Thm("tpm_id_front", tpm_id_front)
val _ = Save_Thm("tpm_inverse", tpm_inverse);
val _ = Save_Thm("tpm_sing_inv", tpm_sing_inv);
val _ = Save_Thm("tpm_thm", tpm_thm);

val tpm_fresh = save_thm("tpm_fresh", GSYM FRESH_swap0)

val FRESH_APP = Store_Thm(
  "FRESH_APP",
  ``v NOTIN FV (M @@ N) <=> v NOTIN FV M /\ v NOTIN FV N``,
  SRW_TAC [][]);
val FRESH_LAM = Store_Thm(
  "FRESH_LAM",
  ``u NOTIN FV (LAM v M) <=> (u <> v ==> u NOTIN FV M)``,
  SRW_TAC [][] THEN METIS_TAC []);
val FV_EMPTY = store_thm(
  "FV_EMPTY",
  ``(FV t = {}) <=> !v. v NOTIN FV t``,
  SIMP_TAC (srw_ss()) [EXTENSION]);

(* quote the term in order to get the variable names specified *)
val simple_induction = store_thm(
  "simple_induction",
  ``!P. (!s. P (VAR s)) /\
        (!M N. P M /\ P N ==> P (M @@ N)) /\
        (!v M. P M ==> P (LAM v M)) ==>
        !M. P M``,
  METIS_TAC [simple_induction])

val _ = save_thm("LAM_eq_thm", LAM_eq_thm);
val _ = save_thm("tm_recursion", tm_recursion)
val _ = save_thm("tpm_flip_args", tpm_flip_args)

(* this result doesn't seem liftable through the quotienting mechanism *)
val tpm_is_perm = Store_Thm(
  "tpm_is_perm",
  ``is_perm tpm``,
  SRW_TAC [][is_perm_def, FUN_EQ_THM, permeq_def] THEN
  Q.ID_SPEC_TAC `x` THEN HO_MATCH_MP_TAC simple_induction THEN
  SRW_TAC [][lswapstr_APPEND]);

(* immediate consequence *)
val tpm_APPEND = store_thm(
  "tpm_APPEND",
  ``tpm (p1 ++ p2) t = tpm p1 (tpm p2 t)``,
  METIS_TAC [is_perm_def, tpm_is_perm]);

(* more minor results about tpm *)
val tpm_eql = store_thm(
  "tpm_eql",
  ``(tpm pi t = u) = (t = tpm (REVERSE pi) u)``,
  METIS_TAC [tpm_inverse]);
val tpm_eqr = store_thm(
  "tpm_eqr",
  ``(t = tpm pi u) = (tpm (REVERSE pi) t = u)``,
  METIS_TAC [tpm_inverse]);

val tpm_sing_to_back = store_thm(
  "tpm_sing_to_back",
  ``!t. tpm [(lswapstr p u, lswapstr p v)] (tpm p t) = tpm p (tpm [(u,v)] t)``,
  HO_MATCH_MP_TAC simple_induction THEN
  SRW_TAC [][basic_swapTheory.lswapstr_sing_to_back]);

val tpm_CONS = store_thm(
  "tpm_CONS",
  ``tpm ((x,y)::pi) t = tpm [(x,y)] (tpm pi t)``,
  SRW_TAC [][GSYM tpm_APPEND]);

(* ----------------------------------------------------------------------
    BVC-compatible structural induction (fixed context)
   ---------------------------------------------------------------------- *)

val nc_INDUCTION2 = store_thm(
  "nc_INDUCTION2",
  ``!P X.
      (!x. P (VAR x)) /\ (!t u. P t /\ P u ==> P (t @@ u)) /\
      (!y u. ~(y IN X) /\ P u ==> P (LAM y u)) /\ FINITE X ==>
      !u. P u``,
  REPEAT GEN_TAC THEN STRIP_TAC THEN
  Q_TAC SUFF_TAC `!u pi. P (tpm pi u)` THEN1 METIS_TAC [tpm_NIL] THEN
  HO_MATCH_MP_TAC simple_induction THEN SRW_TAC [][] THEN
  Q_TAC (NEW_TAC "z") `lswapstr pi v INSERT FV (tpm pi u) UNION X` THEN
  Q_TAC SUFF_TAC `LAM (lswapstr pi v) (tpm pi u) =
                  LAM z (tpm ((z,lswapstr pi v)::pi) u)`
        THEN1 SRW_TAC [][] THEN
  SRW_TAC [][LAM_eq_thm, lswapstr_APPEND] THENL [
    FULL_SIMP_TAC (srw_ss()) [],
    SRW_TAC [][tpm_eqr, tpm_flip_args, tpm_APPEND]
  ]);

(* cases theorem *)
val term_CASES = store_thm(
  "term_CASES",
  ``!t. (?s. t = VAR s) \/ (?t1 t2. t = t1 @@ t2) \/ (?v t0. t = LAM v t0)``,
  HO_MATCH_MP_TAC simple_induction THEN SRW_TAC [][] THEN METIS_TAC []);

(* "acyclicity" *)
val APP_acyclic = store_thm(
  "APP_acyclic",
  ``!t1 t2. t1 <> t1 @@ t2 /\ t1 <> t2 @@ t1``,
  HO_MATCH_MP_TAC simple_induction THEN SRW_TAC [][]);

(* ----------------------------------------------------------------------
    Establish substitution function
   ---------------------------------------------------------------------- *)

val subst_lemma = prove(
  ``~(y = v) /\ ~(x = v) /\ ~(x IN FV N) /\ ~(y IN FV N) ==>
    (tpm [(x,y)] (if swapstr x y s = v then N else VAR (swapstr x y s)) =
     (if s = v then N else VAR s))``,
  SRW_TAC [][swapstr_eq_left] THEN SRW_TAC [][tpm_fresh]);

val tpm_apart = store_thm(
  "tpm_apart",
  ``!t. ~(x IN FV t) /\ (y IN FV t) ==> ~(tpm [(x,y)] t = t)``,
  HO_MATCH_MP_TAC simple_induction THEN SRW_TAC [][] THENL [
    METIS_TAC [],
    METIS_TAC [],
    SRW_TAC [][LAM_eq_thm] THEN
    Cases_on `x = v` THEN SRW_TAC [][]
  ]);

val supp_tpm = Store_Thm(
  "supp_tpm",
  ``supp tpm = FV``,
  ONCE_REWRITE_TAC [FUN_EQ_THM] THEN GEN_TAC THEN
  MATCH_MP_TAC supp_unique_apart THEN SRW_TAC [][support_def, tpm_fresh] THEN
  METIS_TAC [tpm_apart, tpm_flip_args]);

val silly_lemma = prove(``?x. ~(x = y) /\ ~(x IN FV M)``,
                        Q_TAC (NEW_TAC "z") `y INSERT FV M` THEN
                        METIS_TAC [])

val subst_exists =
    (SIMP_RULE (srw_ss()) [SKOLEM_THM, FORALL_AND_THM] o
     Q.GEN `N` o Q.GEN `x` o
     SIMP_RULE (srw_ss()) [support_def, FUN_EQ_THM, fnpm_def, subst_lemma,
                           silly_lemma] o
     Q.INST [`A` |-> `x INSERT FV N`, `apm` |-> `tpm`,
             `vr` |-> `\s. if s = x then N else VAR s`,
             `ap` |-> `(@@)`,
             `lm` |-> `LAM`] o
     SPEC_ALL o
     INST_TYPE [alpha |-> ``:term``]) tm_recursion

val SUB_DEF = new_specification("SUB_DEF", ["SUB"], subst_exists)

val _ = add_rule {term_name = "SUB", fixity = Closefix,
                  pp_elements = [TOK "[", TM, TOK "/", TM, TOK "]"],
                  paren_style = OnlyIfNecessary,
                  block_style = (AroundEachPhrase, (PP.INCONSISTENT, 2))};

(* Give substitution theorems names compatible with historical usage *)

val SUB_THMv = prove(
  ``([N/x](VAR x) = N) /\ (~(x = y) ==> ([N/y](VAR x) = VAR x))``,
  SRW_TAC [][SUB_DEF]);
val SUB_THM = save_thm(
  "SUB_THM",
  REWRITE_RULE [GSYM CONJ_ASSOC]
               (LIST_CONJ (SUB_THMv :: tl (CONJUNCTS SUB_DEF))))
val _ = export_rewrites ["SUB_THM"]
val SUB_VAR = save_thm("SUB_VAR", hd (CONJUNCTS SUB_DEF))

(* ----------------------------------------------------------------------
    Results about substitution
   ---------------------------------------------------------------------- *)

val fresh_tpm_subst = store_thm(
  "fresh_tpm_subst",
  ``!t. ~(u IN FV t) ==> (tpm [(u,v)] t = [VAR u/v] t)``,
  HO_MATCH_MP_TAC nc_INDUCTION2 THEN Q.EXISTS_TAC `{u;v}` THEN
  SRW_TAC [][SUB_THM, SUB_VAR]);

val tpm_subst = store_thm(
  "tpm_subst",
  ``!N. tpm pi ([M/v] N) = [tpm pi M/lswapstr pi v] (tpm pi N)``,
  HO_MATCH_MP_TAC nc_INDUCTION2 THEN
  Q.EXISTS_TAC `v INSERT FV M` THEN
  SRW_TAC [][SUB_THM, SUB_VAR]);

val tpm_subst_out = store_thm(
  "tpm_subst_out",
  ``[M/v] (tpm pi N) =
       tpm pi ([tpm (REVERSE pi) M/lswapstr (REVERSE pi) v] N)``,
  SRW_TAC [][tpm_subst])

val lemma14a = Store_Thm(
  "lemma14a",
  ``!t. [VAR v/v] t = t``,
  HO_MATCH_MP_TAC nc_INDUCTION2 THEN Q.EXISTS_TAC `{v}` THEN
  SRW_TAC [][SUB_THM, SUB_VAR])
val lemma14b = store_thm(
  "lemma14b",
  ``!M. ~(v IN FV M) ==> ([N/v] M = M)``,
  HO_MATCH_MP_TAC nc_INDUCTION2 THEN Q.EXISTS_TAC `v INSERT FV N` THEN
  SRW_TAC [][SUB_THM, SUB_VAR]);
val lemma14c = store_thm(
  "lemma14c",
  ``!t x u. x IN FV u ==> (FV ([t/x]u) = FV t UNION (FV u DELETE x))``,
  NTAC 2 GEN_TAC THEN HO_MATCH_MP_TAC nc_INDUCTION2 THEN
  Q.EXISTS_TAC `x INSERT FV t` THEN
  SRW_TAC [][SUB_THM, SUB_VAR, EXTENSION] THENL [
    Cases_on `x IN FV u'` THEN SRW_TAC [][lemma14b] THEN METIS_TAC [],
    Cases_on `x IN FV u` THEN SRW_TAC [][lemma14b] THEN METIS_TAC [],
    METIS_TAC []
  ]);

val FV_SUB = store_thm(
  "FV_SUB",
  ``!t u v. FV ([t/v] u) = if v IN FV u then FV t UNION (FV u DELETE v)
                           else FV u``,
  PROVE_TAC [lemma14b, lemma14c]);

val lemma15a = store_thm(
  "lemma15a",
  ``!M. ~(v IN FV M) ==> ([N/v]([VAR v/x]M) = [N/x]M)``,
  HO_MATCH_MP_TAC nc_INDUCTION2 THEN Q.EXISTS_TAC `{x;v} UNION FV N` THEN
  SRW_TAC [][SUB_THM, SUB_VAR]);

val lemma15b = store_thm(
  "lemma15b",
  ``~(v IN FV M) ==> ([VAR u/v]([VAR v/u] M) = M)``,
  SRW_TAC [][lemma15a]);

(* ----------------------------------------------------------------------
    alpha-convertibility results
   ---------------------------------------------------------------------- *)

val SIMPLE_ALPHA = store_thm(
  "SIMPLE_ALPHA",
  ``~(y IN FV u) ==> !x. LAM x u = LAM y ([VAR y/x] u)``,
  SRW_TAC [][GSYM fresh_tpm_subst] THEN
  SRW_TAC [boolSimps.CONJ_ss][LAM_eq_thm, tpm_flip_args]);

val tpm_ALPHA = store_thm(
  "tpm_ALPHA",
  ``v NOTIN FV u ==> (LAM x u = LAM v (tpm [(v,x)] u))``,
  SRW_TAC [][fresh_tpm_subst, SIMPLE_ALPHA]);

(* ----------------------------------------------------------------------
    size function
   ---------------------------------------------------------------------- *)

val size_exists =
    (SIMP_RULE (srw_ss()) [] o
     REWRITE_RULE [fnpm_def] o
     SIMP_RULE (srw_ss()) [support_def, FUN_EQ_THM] o
     Q.INST [`A` |-> `{}`, `apm` |-> `K I`,
             `vr` |-> `\s. 1`, `ap` |-> `\m n. m + n + 1`,
             `lm` |-> `\v m. m + 1`] o
     SPEC_ALL o
     INST_TYPE [alpha |-> ``:num``]) tm_recursion

val size_thm = new_specification("size_thm", ["size"], size_exists)
val _ = export_rewrites ["size_thm"]

val size_tpm = Store_Thm(
  "size_tpm",
  ``!t. size (tpm pi t) = size t``,
  HO_MATCH_MP_TAC simple_induction THEN SRW_TAC [][]);

(* ----------------------------------------------------------------------
    iterated substitutions (ugh)
   ---------------------------------------------------------------------- *)

val ISUB_def =
 Define
     `($ISUB t [] = t)
  /\  ($ISUB t ((s,x)::rst) = $ISUB ([s/x]t) rst)`;

val _ = set_fixity "ISUB" (Infixr 501);

val DOM_DEF =
 Define
     `(DOM [] = {})
  /\  (DOM ((x,y)::rst) = {y} UNION DOM rst)`;

val FVS_DEF =
 Define
    `(FVS [] = {})
 /\  (FVS ((t,x)::rst) = FV t UNION FVS rst)`;


val FINITE_DOM = Q.store_thm("FINITE_DOM",
 `!ss. FINITE (DOM ss)`,
Induct THENL [ALL_TAC, Cases]
   THEN RW_TAC std_ss [DOM_DEF, FINITE_EMPTY, FINITE_UNION, FINITE_SING]);
val _ = export_rewrites ["FINITE_DOM"]


val FINITE_FVS = Q.store_thm("FINITE_FVS",
`!ss. FINITE (FVS ss)`,
Induct THENL [ALL_TAC, Cases]
   THEN RW_TAC std_ss [FVS_DEF, FINITE_EMPTY, FINITE_UNION, FINITE_FV]);
val _ = export_rewrites ["FINITE_FVS"]

val ISUB_LAM = store_thm(
  "ISUB_LAM",
  ``!R x. ~(x IN (DOM R UNION FVS R)) ==>
          !t. (LAM x t) ISUB R = LAM x (t ISUB R)``,
  Induct THEN
  ASM_SIMP_TAC (srw_ss()) [ISUB_def, pairTheory.FORALL_PROD,
                           DOM_DEF, FVS_DEF, SUB_THM]);

(* ----------------------------------------------------------------------
    Simultaneous substitution (using a finite map) - much more interesting
   ---------------------------------------------------------------------- *)

val strterm_fmap_supp = store_thm(
  "strterm_fmap_supp",
  ``supp (fmpm lswapstr tpm) fmap =
      FDOM fmap ∪
      supp (setpm tpm) (FRANGE fmap)``,
  SRW_TAC [][fmap_supp]);

val FINITE_strterm_fmap_supp = store_thm(
  "FINITE_strterm_fmap_supp",
  ``FINITE (supp (fmpm lswapstr tpm) fmap)``,
  SRW_TAC [][strterm_fmap_supp, supp_setpm] THEN SRW_TAC [][]);
val _ = export_rewrites ["FINITE_strterm_fmap_supp"]

val lem1 = prove(
  ``∃a. ~(a ∈ supp (fmpm lswapstr tpm) fm)``,
  Q_TAC (NEW_TAC "z") `supp (fmpm lswapstr tpm) fm` THEN
  METIS_TAC []);

val var_case = prove(
  ``∀x y. ~(x ∈ supp (fmpm lswapstr tpm) fm) ∧
          ~(y ∈ supp (fmpm lswapstr tpm) fm)
        ==>
          ∀s. tpm [(x,y)]
                 (if swapstr x y s ∈ FDOM fm then fm ' (swapstr x y s)
                  else VAR (swapstr x y s)) =
              (if s ∈ FDOM fm then fm ' s else VAR s)``,
  SRW_TAC [][] THEN SRW_TAC [][FAPPLY_eqv_lswapstr, supp_fresh] THENL [
    `~(s ∈ FDOM (fmpm lswapstr tpm [(x,y)] fm))`
        by SRW_TAC [][supp_fresh] THEN
    FULL_SIMP_TAC (srw_ss()) [fmpm_FDOM],
    `s ∈ FDOM (fmpm lswapstr tpm [(x,y)] fm)`
        by SRW_TAC [][supp_fresh] THEN
    FULL_SIMP_TAC (srw_ss()) [fmpm_FDOM]
  ]);

val supp_FRANGE = prove(
  ``~(x ∈ supp (setpm tpm) (FRANGE fm)) =
   ∀y. y ∈ FDOM fm ==> ~(x ∈ FV (fm ' y))``,
  SRW_TAC [][supp_setpm, finite_mapTheory.FRANGE_DEF] THEN METIS_TAC []);

fun ex_conj1 thm = let
  val (v,c) = dest_exists (concl thm)
  val c1 = CONJUNCT1 (ASSUME c)
  val fm = mk_exists(v,concl c1)
in
  CHOOSE (v, thm) (EXISTS(fm,v) c1)
end

val ssub_exists =
    (ex_conj1 o SIMP_RULE (srw_ss()) [supp_FRANGE] o
     SIMP_RULE (srw_ss()) [SKOLEM_THM, FORALL_AND_THM, strterm_fmap_supp] o
     Q.GEN `fm` o
     (fn th => MP th var_case) o
     CONV_RULE (LAND_CONV (SIMP_CONV (srw_ss()) [FUN_EQ_THM, fnpm_def])) o
     SIMP_RULE (srw_ss()) [support_def, lem1] o
     SIMP_RULE (srw_ss()) [] o
     Q.SPECL [`\s. if s ∈ FDOM fm then fm ' s else VAR s`,
              `LAM`, `tpm`, `$@@`, `supp (fmpm lswapstr tpm) fm`] o
     INST_TYPE [alpha |-> ``:term``]) tm_recursion

val ssub_def = new_specification ("ssub_def", ["ssub"], ssub_exists)
val _ = export_rewrites ["ssub_def"]

val _ = overload_on ("'", ``ssub``)

val tpm_ssub = store_thm(
  "tpm_ssub",
  ``∀t. tpm pi (fm ' t) = fmpm lswapstr tpm pi fm ' (tpm pi t)``,
  HO_MATCH_MP_TAC nc_INDUCTION2 THEN
  Q.EXISTS_TAC `supp (fmpm lswapstr tpm) fm` THEN
  SRW_TAC [][fmpm_FDOM, strterm_fmap_supp, supp_FRANGE] THENL [
    SRW_TAC [][fmpm_applied],
    SRW_TAC [][fmpm_FDOM, fmpm_applied]
  ]);

val single_ssub = store_thm(
  "single_ssub",
  ``∀N. (FEMPTY |+ (s,M)) ' N = [M/s]N``,
  HO_MATCH_MP_TAC nc_INDUCTION2 THEN Q.EXISTS_TAC `s INSERT FV M` THEN
  SRW_TAC [][SUB_VAR, SUB_THM]);

val in_fmap_supp = store_thm(
  "in_fmap_supp",
  ``x ∈ supp (fmpm lswapstr tpm) fm =
      x ∈ FDOM fm ∨
      ∃y. y ∈ FDOM fm ∧ x ∈ FV (fm ' y)``,
  SRW_TAC [][strterm_fmap_supp, nomsetTheory.supp_setpm] THEN
  SRW_TAC [boolSimps.DNF_ss][finite_mapTheory.FRANGE_DEF] THEN METIS_TAC []);

val not_in_fmap_supp = store_thm(
  "not_in_fmap_supp",
  ``~(x ∈ supp (fmpm lswapstr tpm) fm) =
      ~(x ∈ FDOM fm) ∧ ∀y. y ∈ FDOM fm ==> ~(x ∈ FV (fm ' y))``,
  METIS_TAC [in_fmap_supp]);
val _ = export_rewrites ["not_in_fmap_supp"]

val ssub_14b = store_thm(
  "ssub_14b",
  ``∀t. (FV t ∩ FDOM phi = EMPTY) ==> ((phi : string |-> term) ' t = t)``,
  HO_MATCH_MP_TAC nc_INDUCTION2 THEN
  Q.EXISTS_TAC `supp (fmpm lswapstr tpm) phi` THEN
  SRW_TAC [][SUB_THM, SUB_VAR, pred_setTheory.EXTENSION] THEN METIS_TAC []);

val ssub_value = store_thm(
  "ssub_value",
  ``(FV t = EMPTY) ==> ((phi : string |-> term) ' t = t)``,
  SRW_TAC [][ssub_14b]);

val ssub_FEMPTY = store_thm(
  "ssub_FEMPTY",
  ``∀t. FEMPTY ' t = t``,
  HO_MATCH_MP_TAC simple_induction THEN SRW_TAC [][]);
val _ = export_rewrites ["ssub_FEMPTY"]


(* ----------------------------------------------------------------------
    Set up the recursion functionality in binderLib
   ---------------------------------------------------------------------- *)

val tm_precursion_ex =
    (UNDISCH o
     Q.INST [`VR` |-> `vr`, `AP` |-> `ap`, `LM` |-> `lm`, `APM` |-> `apm`] o
     SIMP_RULE (srw_ss()) [nomsetTheory.support_def, FUN_EQ_THM,
                           nomsetTheory.fnpm_def, pairpm_def,
                           pairTheory.FORALL_PROD,
                           ASSUME ``is_perm (APM: 'a pm)``] o
     Q.INST [`vr` |-> `\s. (VR s, VAR s)`,
             `ap` |-> `\t u. (AP (FST t) (FST u) (SND t) (SND u),
                              SND t @@ SND u)`,
             `lm` |-> `\v t. (LM (FST t) v (SND t), LAM v (SND t))`,
             `apm` |-> `pairpm APM tpm`] o
     SPEC_ALL o
     INST_TYPE [alpha |-> ``:'a # term``]) tm_recursion

val bod = #2 (dest_exists (concl tm_precursion_ex))

val tm_snd_res = prove(
  ``FINITE A ==> ^bod ==> !M. SND (f M) = M``,
  NTAC 2 STRIP_TAC THEN HO_MATCH_MP_TAC nc_INDUCTION2 THEN
  Q.EXISTS_TAC `A` THEN SRW_TAC [][]);

val tm_precursion_ex2 = prove(
  ``FINITE A ==> ^bod ==>
             ?f. ((!s. f (VAR s) = vr s) /\
                  (!M N. f (M @@ N) = ap (f M) (f N) M N) /\
                  (!v M. ~(v IN A) ==> (f (LAM v M) = lm (f M) v M))) /\
                 (!x y t. ~(x IN A) /\ ~(y IN A) ==>
                          (f (tpm [(x,y)] t) = apm [(x,y)] (f t)))``,
  REPEAT STRIP_TAC THEN Q.EXISTS_TAC `FST o f` THEN SRW_TAC [][] THEN
  IMP_RES_TAC tm_snd_res THEN SRW_TAC [][])

val supp_lemma = prove(
  ``is_perm apm ==> ((!x y t. f (tpm [(x,y)] t) = apm [(x,y)] (f t)) =
                     (!pi t. f (tpm pi t) = apm pi (f t)))``,
  SRW_TAC [][EQ_IMP_THM] THEN
  Q.ID_SPEC_TAC `t`  THEN Induct_on `pi` THEN
  ASM_SIMP_TAC (srw_ss()) [pairTheory.FORALL_PROD, is_perm_nil] THEN
  MAP_EVERY Q.X_GEN_TAC [`a`,`b`,`M`] THEN
  `tpm ((a,b)::pi) M = tpm [(a,b)] (tpm pi M)`
     by SRW_TAC [][GSYM tpm_APPEND] THEN SRW_TAC [][] THEN
  SRW_TAC [][GSYM is_perm_decompose]);

val tm_recursion_nosideset = save_thm(
  "tm_recursion_nosideset",
  (SIMP_RULE (srw_ss()) [AND_IMP_INTRO, supp_lemma] o
   Q.INST [`A` |-> `{}`] o
   DISCH_ALL o
   CHOOSE(``f:term -> 'a # term``, tm_precursion_ex) o UNDISCH o
   UNDISCH) tm_precursion_ex2);

val term_info_string =
    "local\n\
    \fun k |-> v = {redex = k, residue = v}\n\
    \open binderLib\n\
    \val term_info = \n\
    \   NTI {nullfv = ``LAM \"\" (VAR \"\")``,\n\
    \        pm_rewrites = [],\n\
    \        pm_constant = ``term$tpm``,\n\
    \        fv_constant = ``term$FV``,\n\
    \        fv_rewrites = [],\n\
    \        recursion_thm = SOME tm_recursion_nosideset,\n\
    \        binders = [(``term$LAM``, 0, tpm_ALPHA)]}\n\
    \val _ = binderLib.type_db :=\n\
    \          Binarymap.insert(!binderLib.type_db,\n\
    \                           {Name = \"term\",Thy=\"term\"},\n\
    \                           term_info)\n\
    \in end;\n"

val _ = adjoin_to_theory
        { sig_ps = NONE,
          struct_ps =
          SOME (fn pps => PP.add_string pps term_info_string)}

*)
val _ = export_theory()


