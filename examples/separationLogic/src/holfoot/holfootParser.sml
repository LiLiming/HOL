structure holfootParser :> holfootParser =
struct

(*
quietdec := true;
loadPath := 
            (concat [Globals.HOLDIR, "/examples/separationLogic/src"]) :: 
            (concat [Globals.HOLDIR, "/examples/separationLogic/src/holfoot"]) :: 
            !loadPath;

map load ["finite_mapTheory", "holfootTheory",
     "Parsetree", "AssembleHolfootParser"];
show_assums := true;
*)


open HolKernel Parse boolLib finite_mapTheory 
open Parsetree;
open separationLogicSyntax
open vars_as_resourceSyntax
open holfootSyntax

(*
quietdec := false;
*)

val parse = AssembleHolfootParser.raw_read_file;

fun hol_parse contextOpt ex_vars default tyL s =
   if (not (isSome contextOpt)) then
      (default, empty_tmset, ex_vars)
   else
      (let
         val s_ty = if (tyL = []) then s else "("^s^"):"^(hd tyL);
         val s_term = Parse.parse_in_context [valOf contextOpt] [QUOTE s_ty];

         val fvL = free_vars s_term;
         val ex_fvL = filter (fn v => 
                   String.sub (fst (dest_var v),0) = #"_")
                   fvL;

         val new_ex_fvL = map (fn v =>
               let
                  val (v_string, v_ty) = dest_var v;
                  val v_string' = String.substring(v_string, 1, (String.size v_string) - 1);
                  val v' = mk_var (v_string', v_ty);
               in
                  v'
               end) ex_fvL;

         val substL = map (fn X => (fst X |-> snd X)) (zip ex_fvL new_ex_fvL);

    val t = Term.subst substL s_term;
         val new_ex_fvL' = filter (fn t => not (mem t ex_vars)) new_ex_fvL;
      in
         (t, empty_tmset, append new_ex_fvL' ex_vars)
      end) handle HOL_ERR _ =>
        if (length tyL <= 1) then
           (print ("Could not parse "^s^"!\n");
           (default, empty_tmset,ex_vars))
        else
           hol_parse contextOpt ex_vars default (tl tyL) s



(*
val file = "/home/tuerk/Downloads/holfoot/EXAMPLES/business2.sf";
val file = "/home/tt291/Downloads/holfoot/EXAMPLES/business2.sf";

val prog = parse file;
*)


exception holfoot_unsupported_feature_exn of string;

fun holfoot_p_expression2term (Pexp_ident x) =
   if (String.sub (x, 0) = #"#") then  
      let
         val var_term = mk_var (String.substring(x, 1, (String.size x) - 1),
            numLib.num);
         val term = mk_comb(holfoot_exp_const_term, var_term) 
      in 
         (term, empty_tmset)
      end
   else
      let
         val var_term = string2holfoot_var x;
         val term = mk_comb(holfoot_exp_var_term, var_term) 
      in 
         (term, HOLset.add (empty_tmset, var_term))
      end
| holfoot_p_expression2term (Pexp_num n) =
     (mk_icomb(holfoot_exp_const_term, numLib.term_of_int n), empty_tmset)
| holfoot_p_expression2term (Pexp_prefix _) =
   Raise (holfoot_unsupported_feature_exn "Pexp_prefix") 
| holfoot_p_expression2term (Pexp_infix (opstring, e1, e2)) =
   let
      val opterm = if (opstring = "-") then holfoot_exp_sub_term else
                             if (opstring = "+") then holfoot_exp_add_term else
                             if (opstring = "*") then holfoot_exp_mult_term else
                             if (opstring = "/") then holfoot_exp_div_term else
                             if (opstring = "%") then holfoot_exp_mod_term else
                             if (opstring = "^") then holfoot_exp_exp_term else
                                Raise (holfoot_unsupported_feature_exn ("Pexp_infix "^opstring));
      val (t1,vs1) = holfoot_p_expression2term e1;
      val (t2,vs2) = holfoot_p_expression2term e2;
   in
      (list_mk_comb (opterm, [t1, t2]), HOLset.union (vs1, vs2))
   end;


fun holfoot_p_condition2term Pcond_false =
   (holfoot_pred_false_term, empty_tmset)
| holfoot_p_condition2term Pcond_true =
   (holfoot_pred_true_term, empty_tmset)
| holfoot_p_condition2term (Pcond_neg c1) =
   let
      val (t1,vs1) = holfoot_p_condition2term c1
   in
      (mk_comb (holfoot_pred_neg_term, t1), vs1)
   end
| holfoot_p_condition2term (Pcond_and (c1,c2)) =
   let
      val (t1,vs1) = holfoot_p_condition2term c1
      val (t2,vs2) = holfoot_p_condition2term c1
   in
      (list_mk_comb (holfoot_pred_and_term, [t1, t2]), HOLset.union (vs1, vs2))
   end
| holfoot_p_condition2term (Pcond_or (c1,c2)) =
   let
      val (t1,vs1) = holfoot_p_condition2term c1
      val (t2,vs2) = holfoot_p_condition2term c1
   in
      (list_mk_comb (holfoot_pred_or_term, [t1, t2]), HOLset.union (vs1, vs2))
   end
| holfoot_p_condition2term (Pcond_compare (opstring, e1, e2)) =
   let
      val opterm = if (opstring = "==") then holfoot_pred_eq_term else
                   if (opstring = "!=") then holfoot_pred_neq_term else
                   if (opstring = "<")  then holfoot_pred_lt_term else
                   if (opstring = "<=") then holfoot_pred_le_term else
                   if (opstring = ">")  then holfoot_pred_gt_term else
                   if (opstring = ">=") then holfoot_pred_ge_term else
                      Raise (holfoot_unsupported_feature_exn ("Pcond_compare "^opstring));
      val (t1,vs1) = holfoot_p_expression2term e1;
      val (t2,vs2) = holfoot_p_expression2term e2;
   in
      (list_mk_comb (opterm, [t1, t2]), HOLset.union (vs1, vs2))
   end;


fun holfoot_a_expression2term ex_vars (Aexp_ident x) =
   if (String.sub (x, 0) = #"#") then  
      let
         val var_term = mk_var (String.substring(x, 1, (String.size x) - 1),
            numLib.num);
         val term = mk_comb(holfoot_exp_const_term, var_term) 
      in 
         (term, empty_tmset, ex_vars)
      end
   else if (String.sub (x, 0) = #"_") then  
      let
         val var_name = String.substring(x, 1, (String.size x) - 1);
         val (var_name, needs_variant) =
        if (var_name = "") then ("c", true) else (var_name, false);
        
         val var_term = mk_var (var_name, numLib.num);         
         val var_term = if (needs_variant) then variant ex_vars var_term else
            var_term;

         val term = mk_comb(holfoot_exp_const_term, var_term) 
      in 
         (term, empty_tmset, if (mem var_term ex_vars) then ex_vars else var_term::ex_vars)
      end
   else
      let
         val var_term = string2holfoot_var x;
         val term = mk_comb(holfoot_exp_var_term, var_term) 
      in 
         (term, HOLset.add (empty_tmset, var_term), ex_vars)
      end
| holfoot_a_expression2term ex_vars (Aexp_num n) =
     (mk_comb(holfoot_exp_const_term, numLib.term_of_int n),
    empty_tmset, ex_vars)
| holfoot_a_expression2term ex_vars (Aexp_hol h) =
      let
        val (hol_term,var_set,ex_vars2) = 
             hol_parse (SOME T) ex_vars (``ARB:num``) ["num","holfoot_a_expression"] h
        val hol_term2 = if (type_of hol_term = numLib.num) then
            mk_comb (holfoot_exp_const_term, hol_term) else
         hol_term;
      in
        (hol_term2,var_set, ex_vars2)
      end       
| holfoot_a_expression2term _ _ =
   Raise (holfoot_unsupported_feature_exn "Aexp");




(*
val aexp1 = Aexp_ident "test";
val aexp2 = Aexp_num 0;
val aexp3 = Aexp_num 5;
val tag = "tl";
val tagL = "l";
val tagR = "r";

val ap1 = Aprop_equal(aexp1, aexp2);
val ap2 = Aprop_false;
val ap3 = Aprop_infix ("<", aexp2, aexp1);


val pl = [(tagL, aexp1), (tagR, aexp2)]
*)


val tag_a_expression_fmap_emp_term = ``FEMPTY:(holfoot_tag |-> holfoot_a_expression)``;
val tag_a_expression_fmap_update_term = ``FUPDATE:(holfoot_tag |-> holfoot_a_expression)->
(holfoot_tag # holfoot_a_expression)->(holfoot_tag |-> holfoot_a_expression)``;


fun tag_a_expression_list2term ex_vars [] = (tag_a_expression_fmap_emp_term,empty_tmset, ex_vars) |
      tag_a_expression_list2term ex_vars ((tag,aexp1)::l) =
      let
         val tag_term = string2holfoot_tag tag;
         val (exp_term,new_var_set, new_ex_var_list) = holfoot_a_expression2term ex_vars aexp1;
         val p = pairLib.mk_pair (tag_term,exp_term);
         val (rest,rest_var_set, ex_var_list) = tag_a_expression_list2term new_ex_var_list l;
         val comb_term = list_mk_comb (tag_a_expression_fmap_update_term, [rest, p]);
         val comb_var_set = HOLset.union (new_var_set, rest_var_set);
      in
                        (comb_term, comb_var_set, ex_var_list)
      end;



val holfoot_data_list___EMPTY_tm = ``[]:(holfoot_tag # num list) list``;

fun holfoot_a_space_pred2term contextOpt ex_vars (Aspred_list (tag,aexp1)) =
        let
       val (exp_term, var_set, ex_var_list) = holfoot_a_expression2term ex_vars aexp1;
            val list_term = list_mk_icomb(holfoot_ap_data_list_term, [string2holfoot_tag tag, 
              exp_term, holfoot_data_list___EMPTY_tm]);
        in
            (list_term, var_set, ex_var_list)
        end
|     holfoot_a_space_pred2term contextOpt ex_vars (Aspred_listseg (tag,aexp1,aexp2)) =
        let
       val (exp_term1, var_set1, ex_vars2) = holfoot_a_expression2term ex_vars aexp1;
       val (exp_term2, var_set2, ex_vars3) = holfoot_a_expression2term ex_vars2 aexp2;
       val comb_term = list_mk_comb(holfoot_ap_data_list_seg_term, [string2holfoot_tag tag,
              exp_term1, holfoot_data_list___EMPTY_tm, exp_term2]);
        in
            (comb_term, HOLset.union (var_set1, var_set2), ex_vars3)
        end
|     holfoot_a_space_pred2term contextOpt ex_vars (Aspred_data_list (tag,aexp1,data_tag,data)) =
        let
       val (exp_term, var_set1, ex_vars2) = holfoot_a_expression2term ex_vars aexp1;
            val (data_term, var_set2, ex_vars3) =
               hol_parse contextOpt ex_vars2 (``[]:num list``) ["num list"] data;
            val data_tag_term = string2holfoot_tag data_tag;
            val data2_term = ``[(^data_tag_term, ^data_term)]``;
       val comb_term = list_mk_comb(holfoot_ap_data_list_term, [string2holfoot_tag tag,
              exp_term, data2_term]);
        in
            (comb_term, HOLset.union (var_set1, var_set2), ex_vars3)
        end
|     holfoot_a_space_pred2term contextOpt ex_vars (Aspred_data_listseg (tag,aexp1,data_tag,data,aexp2)) =
        let
       val (exp_term1, var_set1, ex_vars2) = holfoot_a_expression2term ex_vars aexp1;
       val (exp_term2, var_set2, ex_vars3) = holfoot_a_expression2term ex_vars2 aexp2;
            val (data_term, var_set3, ex_vars4) =
               hol_parse contextOpt ex_vars3 (``[]:num list``) ["num list"] data;
            val data_tag_term = string2holfoot_tag data_tag;
            val data2_term = ``[(^data_tag_term, ^data_term)]``;
       val comb_term = list_mk_comb(holfoot_ap_data_list_seg_term, [string2holfoot_tag tag,
              exp_term1, data2_term, exp_term2]);
        in
            (comb_term, HOLset.union (var_set1, HOLset.union (var_set2, var_set3)), ex_vars4)
        end
|     holfoot_a_space_pred2term contextOpt ex_vars (Aspred_data_tree (tagL,aexp,dtagL,data)) =
        let
            val (exp_term1, var_set1, ex_vars2) = holfoot_a_expression2term ex_vars aexp;
            val (data_term, var_set2, ex_vars3) =
               hol_parse contextOpt ex_vars2 (``leaf:num list tree``) ["num list tree"] data;
            val tree_dtag_t = listSyntax.mk_list (
                 (map string2holfoot_tag dtagL), Type `:holfoot_tag`)
            val data2_term = pairSyntax.mk_pair (tree_dtag_t, data_term)
            val tree_tag_t = listSyntax.mk_list (
                 (map string2holfoot_tag tagL), Type `:holfoot_tag`)
            val comb_term = list_mk_icomb(holfoot_ap_data_tree_term, [
                tree_tag_t, exp_term1, data2_term]);
        in
            (comb_term, HOLset.union (var_set1, var_set2), ex_vars3)
        end
|     holfoot_a_space_pred2term contextOpt ex_vars (Aspred_dlseg _) =
     Raise (holfoot_unsupported_feature_exn ("Aspred_dl_seg"))
   
|     holfoot_a_space_pred2term contextOpt ex_vars (Aspred_tree (tagL,tagR,aexp1)) =
        let
            val (exp_term, var_set, ex_vars2) = holfoot_a_expression2term ex_vars aexp1;
            val comb_term = list_mk_comb(holfoot_ap_bintree_term, [
                   pairLib.mk_pair(string2holfoot_tag tagL, string2holfoot_tag tagR), 
              exp_term])
        in
            (comb_term, var_set, ex_vars2)
        end
|     holfoot_a_space_pred2term contextOpt ex_vars (Aspred_empty) =
   (holfoot_stack_true_term, empty_tmset, ex_vars)
|     holfoot_a_space_pred2term contextOpt ex_vars (Aspred_hol s) =
      let
        val (hol_term,var_set,ex_vars2) = hol_parse contextOpt ex_vars (holfoot_stack_true_term)
                         ["bool", "holfoot_a_proposition"] s;
        val hol_term2 = if (type_of hol_term = bool) then
            mk_comb (holfoot_bool_proposition_term, hol_term) else
         hol_term;
      in
        (hol_term2,var_set, ex_vars2)
      end
|     holfoot_a_space_pred2term contextOpt ex_vars (Aspred_pointsto (aexp1, pl)) =
        let
       val (term1, var_set1, ex_vars2) = holfoot_a_expression2term ex_vars aexp1;
       val (term2, var_set2, ex_vars3) = tag_a_expression_list2term ex_vars2 pl;
       val comb_term = list_mk_comb(holfoot_ap_points_to_term, [term1, term2]); 
        in
            (comb_term, HOLset.union (var_set1,var_set2), ex_vars3)
        end;



fun unzip3 [] = ([],[],[])
  | unzip3 ((a,b,c)::L) =
    let
   val (aL,bL,cL) = unzip3 L;
    in 
       (a::aL, b::bL, c::cL)
    end;


(*
fun list_mk_comb___with_vars op_term sub_fun l =
    let
   val term_var_l = map sub_fun l;
        val (termL, setL, ex_varsL) = unzip3 term_var_l;
        val set_union = foldr HOLset.union empty_tmset setL;
        val term = list_mk_comb (op_term, termL);
        val ex_vars = flatten ex_varsL;
    in
        (term, set_union, ex_vars)
    end;
*)

fun mk_comb2___with_vars op_term sub_fun ex_vars a1 a2 =
    let
   val (term1,set1,ex_vars1) = sub_fun ex_vars a1;
   val (term2,set2,ex_vars2) = sub_fun ex_vars1 a2;

        val set_union = HOLset.union (set1,set2);
        val term = list_mk_comb (op_term, [term1,term2]);
    in
        (term, set_union, ex_vars2)
    end;


(*
val t = 
Aprop_ifthenelse(Aprop_equal(Aexp_ident "y", Aexp_ident "x"),
                 Aprop_spred(Aspred_list("tl", Aexp_ident "x")),
                 Aprop_spred(Aspred_list("tl", Aexp_ident "x")))

fun dest_ifthenelse (Aprop_ifthenelse (Aprop_equal (aexp1, aexp2), ap1,ap2)) =
  (aexp1, aexp2, ap1, ap2)


val (aexp1, aexp2, ap1, ap2) = dest_ifthenelse t

val contextOpt = NONE
val ex_vars = []

val Aprop_star (ap1, ap2) = x

*)


fun holfoot_a_proposition2term_context contextOpt ex_vars (Aprop_infix (opString, aexp1, aexp2)) =
  let
    val op_term = if (opString = "<") then holfoot_ap_lt_term else
                  if (opString = "<=") then holfoot_ap_le_term else
                  if (opString = ">") then holfoot_ap_gt_term else
                  if (opString = ">=") then holfoot_ap_ge_term else
                  if (opString = "==") then holfoot_ap_equal_term else
                  if (opString = "!=") then holfoot_ap_unequal_term else
                     Raise (holfoot_unsupported_feature_exn ("Aexp_infix "^opString))
   in
      mk_comb2___with_vars op_term holfoot_a_expression2term ex_vars aexp1 aexp2
   end
| holfoot_a_proposition2term_context contextOpt ex_vars (Aprop_false) =
   (holfoot_ap_false_term, empty_tmset, ex_vars)
| holfoot_a_proposition2term_context contextOpt ex_vars (Aprop_ifthenelse (Aprop_infix (opString,aexp1, aexp2), ap1,ap2)) =
   let
      val (ap1,ap2) = if opString = "==" then (ap1,ap2) else 
                      if opString = "!=" then (ap2,ap1) else
                      Raise (holfoot_unsupported_feature_exn "Currently only equality checks are allowed as conditions in propositions")
      val (exp1_term, exp1_set, ex_vars2) = holfoot_a_expression2term ex_vars aexp1;
      val (exp2_term, exp2_set, ex_vars3) = holfoot_a_expression2term ex_vars2 aexp2;
      val (prop1_term, prop1_set, ex_vars4) = holfoot_a_proposition2term_context contextOpt ex_vars3 ap1;
      val (prop2_term, prop2_set, ex_vars5) = holfoot_a_proposition2term_context contextOpt ex_vars4 ap2;
      val t = list_mk_comb (holfoot_ap_eq_cond_term, [exp1_term, exp2_term, prop1_term, prop2_term])
           val set_union = foldr HOLset.union exp1_set [exp2_set, prop1_set, prop2_set];
   in
      (t, set_union, ex_vars5) 
   end
| holfoot_a_proposition2term_context contextOpt ex_vars (Aprop_ifthenelse _) =
   Raise (holfoot_unsupported_feature_exn "Currently only equality checks are allowed as conditions in propositions")
| holfoot_a_proposition2term_context contextOpt ex_vars (Aprop_star (ap1, ap2)) =
   mk_comb2___with_vars holfoot_ap_star_term (holfoot_a_proposition2term_context contextOpt) ex_vars ap1 ap2
| holfoot_a_proposition2term_context contextOpt ex_vars (Aprop_spred sp) =
   holfoot_a_space_pred2term contextOpt ex_vars sp;


fun holfoot_a_proposition2term x =
let
   val (t1,_, _) = holfoot_a_proposition2term_context NONE [] x;
   val (t2,ts, ex_vars) = holfoot_a_proposition2term_context (SOME t1) [] x;

   val t3 = foldr (fn (v,t) => 
       let
               val t_abs = pairLib.mk_pabs (v, t);
               val t' = mk_icomb (asl_exists_term, t_abs);
            in
          t'
       end) t2 ex_vars
in
   (t3,ts)
end;

(*
val x = 
 Aprop_spred(Aspred_pointsto(Aexp_ident "r",
                                                                              [("tl",
                                                                                Aexp_ident "_b")])
)


val x = 
 Aprop_star(Aprop_star(Aprop_spred(Aspred_pointsto(Aexp_ident "r",
                                                                              [("tl",
                                                                                Aexp_ident "_b")])),
                                                  Aprop_spred(Aspred_pointsto(Aexp_ident "_b",
                                                                              [("tl",
                                                                                Aexp_ident "_tf")]))),
                                       Aprop_spred(Aspred_listseg("tl",
                                                                  Aexp_ident "_tf",
                                                                  Aexp_ident "r")))
*)


fun unzip4 [] = ([],[],[],[])
  | unzip4 ((a,b,c,d)::L) =
  let
    val (aL,bL,cL,dL) = unzip4 L;
  in 
    (a::aL, b::bL, c::cL, d::dL)
  end;

    


(*
  val (wp,rp,d_opt,Pterm) = (write_var_set,read_var_set,SOME arg_refL,preCond);
*)

fun mk_holfoot_prop_input wp rp d_opt Pterm =
 let
   val (d_list,rp) = 
      if isSome d_opt then
         let
            val d_list = valOf d_opt;
            val rp = HOLset.addList(rp,d_list);
            val rp = HOLset.difference (rp, wp);
         in
            (d_list,rp)
         end
      else
         let
            val rp = HOLset.difference (rp, wp);
            val d_list = append (HOLset.listItems wp) (HOLset.listItems rp);
         in
            (d_list, rp)
         end;
   val d = listSyntax.mk_list(d_list,Type `:holfoot_var`);
   val rp_term = pred_setSyntax.prim_mk_set (HOLset.listItems rp, Type `:holfoot_var`);
   val wp_term = pred_setSyntax.prim_mk_set (HOLset.listItems wp, Type `:holfoot_var`);
   val wp_rp_pair_term = pairLib.mk_pair (wp_term, rp_term);
 in
   if length d_list < 2 then
      list_mk_comb (holfoot_prop_input_ap_term, [wp_rp_pair_term, Pterm])
   else
      list_mk_comb (holfoot_prop_input_ap_distinct_term, [wp_rp_pair_term, d, Pterm])
 end;


fun prune_funcall_args_el prune_vset NONE = (NONE:term option)
  | prune_funcall_args_el prune_vset (SOME v) = 
    if (HOLset.member (prune_vset,v)) then 
       NONE
    else
       SOME v;


fun prune_funcall_args prune_vset (name:string, argL) =
    (name, map (prune_funcall_args_el prune_vset) argL);




fun funcall_subsume_args ([]:term option list) [] = true
  | funcall_subsume_args [] (arg2::argL2) = false
  | funcall_subsume_args (arg1::argL1) [] = false
  | funcall_subsume_args (arg1::argL1) (arg2::argL2) = 
    ((arg2 = NONE) orelse (arg1 = arg2)) andalso 
    (funcall_subsume_args argL1 argL2);


fun funcall_subsume (name1,argL1) (name2,argL2) =
    ((name1:string)=name2) andalso (funcall_subsume_args argL1 argL2);

fun funcalls_prune prune_vset done_funcalls funcalls =
let
   val funcalls2 = map (prune_funcall_args prune_vset) funcalls;
   val funcalls3 = filter (fn fc => (not (exists (funcall_subsume fc) done_funcalls))) funcalls2
in
   funcalls3
end;




(*
val   (funname:string, 
         (ref_args, write_var_set, read_var_set, local_var_set,
    (funname2,funArgs2)::funcalls, done_funcalls), rest) =
(el 3 fun_decl_parse_read_writeL);

val envL = fun_decl_parse_read_writeL;
*)

fun fun_decl_parse_read_write___subst_fun ((ref_arg:term, ref_argOpt),
    (write_var_set, read_var_set, funcalls)) =
let
   val in_write_set = HOLset.member (write_var_set, ref_arg);
   val write_var_set1 = if in_write_set then
             HOLset.delete (write_var_set, ref_arg)
         else write_var_set;
   val write_var_set2 = if isSome ref_argOpt then
             HOLset.add (write_var_set1, valOf ref_argOpt)
         else write_var_set1;


   val in_read_set = HOLset.member (read_var_set, ref_arg);
   val read_var_set1 = if in_read_set then
             HOLset.delete (read_var_set, ref_arg)
         else read_var_set;
   val read_var_set2 = if isSome ref_argOpt then
             HOLset.add (read_var_set1, valOf ref_argOpt)
         else read_var_set1;

   

   fun funcalls_arg_update NONE = NONE
     | funcalls_arg_update (SOME arg) =
       if (arg = ref_arg) then ref_argOpt else SOME arg;

   val funcalls2 = map (fn (n:string, L) => (n, map funcalls_arg_update L)) funcalls;
in
   (write_var_set2, read_var_set2, funcalls2)
end;




fun fun_decl_parse_read_write___step_fun 
   (funname:string, 
         (ref_args, write_var_set, read_var_set, local_var_set,
    (funname2,funArgs2)::funcalls, done_funcalls), rest) envL =
let
  val (_, (ref_args', write_var_set', read_var_set', _,
       funcalls', _),_) = first (fn (n, _,_) => (n = funname2)) envL
      handle HOL_ERR e =>
        (print "fun_decl_parse_read_write___step_fun: Unknown function '";print funname2;print "' detected!\n";Raise (HOL_ERR e))

  val (write_var_set2, read_var_set2, funcalls2) =
     foldl fun_decl_parse_read_write___subst_fun (write_var_set', read_var_set', funcalls')
        (zip (map string2holfoot_var ref_args') funArgs2)


  val write_var_set3 = let
           val set1 =  HOLset.union (write_var_set, write_var_set2);
                val set2 = HOLset.difference (set1, local_var_set);
                in set2 end;
  val read_var_set3 = let
           val set1 =  HOLset.union (read_var_set, read_var_set2);
                val set2 = HOLset.difference (set1, write_var_set);
                val set3 = HOLset.difference (set2, local_var_set);
                in set3 end;


  val done_funcalls3 = (funname2,funArgs2)::done_funcalls;
  val funcalls3 = funcalls_prune local_var_set done_funcalls3 (append funcalls funcalls2);
in
  (funname, 
   (ref_args, write_var_set3, read_var_set3, local_var_set,
    funcalls3, done_funcalls3), rest)
end |
 fun_decl_parse_read_write___step_fun _ _ = Raise (holfoot_unsupported_feature_exn ("-"));

 

fun fun_decl_parse_read_write___has_unresolved_funcalls 
    (funname, 
         (ref_args, write_var_set, read_var_set, local_var_set,
    funcalls, done_funcalls), rest) =
    not(funcalls = []);



fun fun_decl_update_read_write [] solvedL = rev solvedL
  | fun_decl_update_read_write (h::L) solvedL =
    if not (fun_decl_parse_read_write___has_unresolved_funcalls h) then
       fun_decl_update_read_write L (h::solvedL)
    else
       let
     val h' = fun_decl_parse_read_write___step_fun h
         (append solvedL (h::L))
       in
          fun_decl_update_read_write (h'::L) solvedL
       end;






fun mk_el_list n v = 
List.tabulate (n, (fn n => list_mk_icomb (listSyntax.el_tm, [numLib.term_of_int n, v])))

fun mk_dest_pair_list 0 v = [v]
  | mk_dest_pair_list n v =
    (pairLib.mk_fst v) :: mk_dest_pair_list (n-1) (pairLib.mk_snd v);




fun list_variant l [] = [] |
      list_variant l (v::vL) =
   let
      val v' = variant l v;
   in
      v'::(list_variant (v'::l) vL)
   end;


(*

val v = "var_name";
val n = 33;
val expr = Pexp_num 3;
val expr1 = Pexp_num 1;
val expr2 = Pexp_num 2;
val tag = "tag";
val cond = Pexp_infix("<", Pexp_num 2, Pexp_ident v)

val stm1 = Pstm_new v;
val stm2 = Pstm_dispose (Pexp_ident v);

val stmL = [Pstm_fldlookup (v, expr, tag), Pstm_assign (v, expr), Pstm_new v]

val name = "proc_name";
val rp = ["x", "y", "z"];
val vp = [expr1, expr2];

val envL = fun_decl_parse_read_writeL2;
val funname = "cas"

val write_var_set = write_var_set'
*)


fun holfoot_fcall_get_read_write_var_sets envL funname args =
let
  val (_, (ref_args', write_var_set', read_var_set', _,
       funcalls', _),_) = first (fn (n, _,_) => ((n:string) = funname)) envL;

  val (write_var_set2, read_var_set2, _) =
     foldl fun_decl_parse_read_write___subst_fun (write_var_set', read_var_set', funcalls')
        (zip (map string2holfoot_var ref_args') args)
in
  (read_var_set2, write_var_set2)
end handle HOL_ERR _ => (empty_tmset, empty_tmset);




fun holfoot_fcall2term_internal funL (name, (rp,vp)) =
let
   val name_term = stringLib.fromMLstring name;

   val var_list = map string2holfoot_var rp;
   val rp_term = listSyntax.mk_list (var_list, Type `:holfoot_var`);

   val (exp_list, exp_varset_list) = unzip (map holfoot_p_expression2term vp);
   val vp_term = listSyntax.mk_list (exp_list, Type `:holfoot_a_expression`)

   val arg_term = pairLib.mk_pair (rp_term, vp_term);
   val arg_varset = HOLset.addList (foldr HOLset.union empty_tmset exp_varset_list,
                   var_list);

   val (read_var_set0,write_var_set) = holfoot_fcall_get_read_write_var_sets funL name (map SOME var_list);
   val read_var_set = HOLset.union (arg_varset, read_var_set0);
   val funcalls = [(name, map SOME var_list)];
in
   (name_term, arg_term, read_var_set, write_var_set, funcalls)
end;




fun holfoot_fcall2term funL (name, (rp, vp)) =
let
   val (name_term, arg_term, read_var_set, write_var_set, funcalls) =
       holfoot_fcall2term_internal funL (name, (rp,vp));
in
   (list_mk_comb(holfoot_prog_procedure_call_term, [name_term, arg_term]),
    read_var_set, write_var_set, funcalls)
end;


(*
val t =
 Pstm_parallel_fcall("proc",
                                            ([], [Pexp_ident "x", Pexp_num 4]),
                                            "proc",
                                            ([],
                                             [Pexp_ident "z", Pexp_num 5]));

fun dest_Pstm_parallel_fcall (Pstm_parallel_fcall(name1,(rp1,vp1),name2,(rp2,vp2))) =
(name1,(rp1,vp1),name2,(rp2,vp2));

val (name1,(rp1,vp1),name2,(rp2,vp2)) = dest_Pstm_parallel_fcall t;

*)

fun holfoot_parallel_fcall2term funL (name1, (rp1, vp1), name2, (rp2,vp2)) =
let
   val (name_term1, arg_term1, read_var_set1, write_var_set1, funcalls1) =
       holfoot_fcall2term_internal funL (name1, (rp1,vp1));
   val (name_term2, arg_term2, read_var_set2, write_var_set2, funcalls2) =
       holfoot_fcall2term_internal funL (name2, (rp2,vp2));

   val read_var_set = HOLset.union (read_var_set1, read_var_set2)
   val write_var_set = HOLset.union (write_var_set1, write_var_set2)
   val funcalls = append funcalls1 funcalls2;
in
   (list_mk_comb(holfoot_prog_parallel_procedure_call_term, [name_term1, arg_term1,name_term2, arg_term2]),
       read_var_set, write_var_set, funcalls)
end;


val unit_var_term = mk_var("uv", Type `:unit`);

fun mk_list_pabs l = 
  let
    val pairTerm = if null l then unit_var_term else
                   (pairLib.list_mk_pair l);
  in
     fn t => pairLib.mk_pabs (pairTerm,t) 
  end;


fun decode_rwOpt rwOpt = if isSome rwOpt then
       (let val (force, wL, rL) = valOf rwOpt in
       (force, HOLset.addList (empty_tmset, map string2holfoot_var wL),
               HOLset.addList (empty_tmset, map string2holfoot_var rL)) end) else
       (false, empty_tmset, empty_tmset);


(*returns the term, the set of read variables and a set of written variables*)
fun holfoot_p_statement2term resL funL (Pstm_assign (v, expr)) =
  let
     val var_term = string2holfoot_var v;
     val (exp_term, read_var_set) = holfoot_p_expression2term expr;
     val comb_term = list_mk_comb (holfoot_prog_assign_term, [var_term, exp_term]);
     val write_var_set = HOLset.add (empty_tmset, var_term);
  in
     (comb_term, read_var_set, write_var_set, [])
  end
| holfoot_p_statement2term resL funL (Pstm_fldlookup (v, expr, tag)) =
  let
     val var_term = string2holfoot_var v;
     val (exp_term, read_var_set) = holfoot_p_expression2term expr;
     val comb_term = list_mk_comb (holfoot_prog_field_lookup_term, [var_term, exp_term, string2holfoot_tag tag]);
     val write_var_set = HOLset.add (empty_tmset, var_term);
  in
     (comb_term, read_var_set, write_var_set, [])
  end
| holfoot_p_statement2term resL funL (Pstm_fldassign (expr1, tag, expr2)) =
  let
     val (exp_term1, read_var_set1) = holfoot_p_expression2term expr1;
     val (exp_term2, read_var_set2) = holfoot_p_expression2term expr2;
     val comb_term = list_mk_comb (holfoot_prog_field_assign_term, [exp_term1, string2holfoot_tag tag, exp_term2]);
     val read_var_set = HOLset.union (read_var_set1, read_var_set2);
     val write_var_set = empty_tmset;
  in
     (comb_term, read_var_set, write_var_set, [])
  end
| holfoot_p_statement2term resL funL (Pstm_new v) =
  let
     val var_term = string2holfoot_var v;
     val comb_term = mk_comb (holfoot_prog_new_term, var_term);
     val write_var_set = HOLset.add (empty_tmset, var_term);
     val read_var_set = empty_tmset;
  in
     (comb_term, read_var_set, write_var_set, [])
  end  
| holfoot_p_statement2term resL funL (Pstm_dispose expr) =
  let
     val (exp_term, read_var_set) = holfoot_p_expression2term expr;
     val comb_term = mk_comb (holfoot_prog_dispose_term, exp_term);
     val write_var_set = empty_tmset;
  in
     (comb_term, read_var_set, write_var_set, [])
  end  
| holfoot_p_statement2term resL funL (Pstm_block stmL) =
  let
     val (termL, read_var_setL, write_var_setL,funcallsL) = unzip4 (map (holfoot_p_statement2term resL funL) stmL);      
     val list_term = listSyntax.mk_list (termL, Type `:holfoot_program`);
     val comb_term = mk_comb (holfoot_prog_block_term, list_term);
     val read_var_set = foldr HOLset.union empty_tmset read_var_setL;
     val write_var_set = foldr HOLset.union empty_tmset write_var_setL;
     val funcalls = flatten funcallsL;
   in
     (comb_term, read_var_set, write_var_set,funcalls)
   end
| holfoot_p_statement2term resL funL (Pstm_if (cond, stm1, stm2)) =
   let
      val (c_term, c_read_var_set) = holfoot_p_condition2term cond;
      val (stm1_term,read_var_set1,write_var_set1,funcalls1) = holfoot_p_statement2term resL funL stm1;
      val (stm2_term,read_var_set2,write_var_set2,funcalls2) = holfoot_p_statement2term resL funL stm2;
      val comb_term = list_mk_comb (holfoot_prog_cond_term, [c_term, stm1_term, stm2_term]);
      val read_var_set = HOLset.union (c_read_var_set, HOLset.union (read_var_set1, read_var_set2));
      val write_var_set = HOLset.union (write_var_set1, write_var_set2);
   in
      (comb_term, read_var_set, write_var_set, append funcalls1 funcalls2)
   end
| holfoot_p_statement2term resL funL (Pstm_while (rwOpt, i, cond, stm1)) =
   let
      val (i_opt,i_read_var_set) = if isSome i then
          let
             val (prop_term, prop_varset) = holfoot_a_proposition2term (valOf i);
          in
             (SOME prop_term, prop_varset)
          end else (NONE, empty_tmset);

      val (stm1_term, stm_read_var_set, stm_write_var_set, funcalls) = holfoot_p_statement2term resL funL stm1;
      val (c_term, c_read_var_set) = holfoot_p_condition2term cond;


      val (force_user_wr, write_var_set_user, read_var_set_user) = decode_rwOpt rwOpt;
      val write_var_set = HOLset.union (stm_write_var_set, write_var_set_user);
      val read_var_set = HOLset.union (c_read_var_set, HOLset.union (i_read_var_set, 
                            HOLset.union (stm_read_var_set, read_var_set_user)));
      val read_var_set = HOLset.difference (read_var_set, write_var_set);
      val (write_var_set, read_var_set) = if force_user_wr then
          (write_var_set_user, read_var_set_user) else (write_var_set, read_var_set); 

      val while_term = list_mk_comb (holfoot_prog_while_term, [c_term,stm1_term]); 
      val i_term = if not (isSome i_opt) then while_term else
         let
            val prop_term = mk_holfoot_prop_input write_var_set read_var_set NONE (valOf i_opt);
            val cond_free_var_list = 
               let
                  val set1 = HOLset.addList(empty_tmset, free_vars prop_term);
                  val set2 = HOLset.addList(empty_tmset, free_vars stm1_term);
                  val set3 = HOLset.difference (set1, set2);
               in
                  HOLset.listItems set3
               end;
            val abs_prop_term = mk_list_pabs cond_free_var_list prop_term
         in
            list_mk_icomb (fasl_comment_loop_invariant_term, [abs_prop_term, while_term])
         end
   in
      (i_term, read_var_set, write_var_set, funcalls)
   end
| holfoot_p_statement2term resL funL (Pstm_block_spec (loop, rwOpt, pre, stm1, post)) =
   let
      val (pre_term,pre_read_var_set) = holfoot_a_proposition2term pre;
      val (post_term,post_read_var_set) = holfoot_a_proposition2term post;
      val (force_user_wr, write_var_set_user, read_var_set_user) = decode_rwOpt rwOpt;

      val (stm1_term, stm_read_var_set, stm_write_var_set, funcalls) = holfoot_p_statement2term resL funL stm1;

      val write_var_set = HOLset.union (stm_write_var_set, write_var_set_user);
      val read_var_set = HOLset.union (pre_read_var_set, HOLset.union (post_read_var_set, 
                            HOLset.union (stm_read_var_set, read_var_set_user)));
      val read_var_set = HOLset.difference (read_var_set, write_var_set);
      val (write_var_set, read_var_set) = if force_user_wr then
          (write_var_set_user, read_var_set_user) else (write_var_set, read_var_set); 

      val (pre_term2, post_term2) = 
         let
            val pre_t = mk_holfoot_prop_input write_var_set read_var_set NONE pre_term
            val post_t = mk_holfoot_prop_input write_var_set read_var_set NONE post_term
            val cond_free_var_list = 
               let
                  val set1 = FVL [pre_t, post_t] empty_tmset;
                  val set2 = FVL [stm1_term] empty_tmset;
                  val set3 = HOLset.difference (set1, set2);
               in
                  HOLset.listItems set3
               end;
            val pre_t' = mk_list_pabs cond_free_var_list pre_t
            val post_t' = mk_list_pabs cond_free_var_list post_t
         in
            (pre_t', post_t')
         end
      val stm1_term = if not loop then stm1_term else
          let
             val stm1_term' = if is_fasl_prog_block stm1_term then stm1_term else 
                 (mk_comb (holfoot_prog_block_term, listSyntax.mk_list ([stm1_term], Type `:holfoot_program`)));
          in
             stm1_term'
          end;
      val spec_term = list_mk_icomb (
          (if loop then fasl_comment_loop_spec_term else fasl_comment_block_spec_term),
          [pairSyntax.mk_pair (pre_term2, post_term2), stm1_term]);
   in
      (spec_term, read_var_set, write_var_set, funcalls)
   end
| holfoot_p_statement2term resL funL (Pstm_withres (res, cond, stm1)) =
   let
      val (c_term, c_read_var_set) = holfoot_p_condition2term cond;
      val (stm1_term,read_var_set1,write_var_set1, funcalls1) = holfoot_p_statement2term resL funL stm1;
      val res_term = stringLib.fromMLstring res;
      val res_decl_opt = List.find (fn (a, _) => (a = res)) resL;
      val _ = if isSome (res_decl_opt) then () else raise 
                    Raise (holfoot_unsupported_feature_exn (
                        "Undefined resource '"^res^"'!"));
      val (_, (_,res_var_set))  = valOf res_decl_opt

      val comb_term = list_mk_comb (holfoot_prog_with_resource_term, [res_term, c_term, stm1_term]);
      val read_var_set = HOLset.difference (HOLset.union (c_read_var_set, read_var_set1), res_var_set);
      val write_var_set = HOLset.difference (write_var_set1, res_var_set);
      val funcalls = map (prune_funcall_args res_var_set) funcalls1;
   in
      (comb_term, read_var_set, write_var_set, funcalls)
   end
| holfoot_p_statement2term resL funL (Pstm_fcall(name,args)) =
       holfoot_fcall2term funL (name, args)
| holfoot_p_statement2term resL funL (Pstm_parallel_fcall(name1,args1,name2,args2)) =
       holfoot_parallel_fcall2term funL (name1, args1, name2, args2);



(*
val dummy_fundecl =
Pfundecl("proc", ([], ["x", "y"]),
                       SOME(Aprop_spred(Aspred_pointsto(Aexp_ident "x", []))),
                       [],
                       [Pstm_fldassign(Pexp_ident "x", "tl", Pexp_ident "y")],
                       SOME(Aprop_spred(Aspred_pointsto(Aexp_ident "x",
                                                        [("tl",
                                                          Aexp_ident "y")]))))


fun destPfundecl (Pfundecl(funname, (ref_args, val_args), preCond, localV, 
   fun_body, postCond)) =
   (funname, (ref_args, val_args), preCond, localV, 
   fun_body, postCond);

val (funname, (ref_args, val_args), preCondOpt, localV, 
   fun_body, postCondOpt) = destPfundecl dummy_fundecl;

val var = "y";
val term = fun_body_term; 
*)







(*
   fun dest_Presource (Presource(resname, varL, invariant)) =
        (resname, varL, invariant);


   val (resname, varL, invariant) = dest_Presource ((el 2 (program_item_decl)));

*)


fun Presource2hol (Presource(resname, varL, invariant)) =
let
   val write_varL = map string2holfoot_var varL;
   val write_var_set = HOLset.addList (empty_tmset, write_varL);
   val (i_term, i_read_var_set) = holfoot_a_proposition2term invariant;

   val _ = if HOLset.isSubset (i_read_var_set, write_var_set) then () else
              Raise (holfoot_unsupported_feature_exn (
                "All variables used in an resource invariant must be bound to the resource!"));
in
   (resname, (i_term, write_var_set))
end |
 Presource2hol _ = Raise (holfoot_unsupported_feature_exn ("-"));




(*
   fun dest_Pfundecl (Pfundecl(funname, (ref_args, val_args), preCondOpt, localV, 
   fun_body, postCondOpt)) = (funname, (ref_args, val_args), preCondOpt, localV, 
   fun_body, postCondOpt);


   val (funname, (ref_args, val_args), preCondOpt, localV, 
   fun_body, postCondOpt) = dest_Pfundecl ((el 2 (program_item_decl)));

   val resL = resource_parseL
   val resL = []
   val funL = []
*)


fun Pfundecl2hol funL resL (Pfundecl(assume_opt, funname, (ref_args, val_args), rwOpt, preCondOpt, localV, 
   fun_body, postCondOpt)) = 
let
   val (fun_body_term, read_var_set_body, write_var_set_body, funcalls) = holfoot_p_statement2term resL funL (Pstm_block fun_body)
   val (preCond, read_var_set_preCond, postCond, read_var_set_postCond) = 
       if not (funname = "init") then
          let
             val (preCond, read_var_set_preCond) = if isSome preCondOpt then holfoot_a_proposition2term (valOf preCondOpt) else (holfoot_stack_true_term,empty_tmset);
             val (postCond, read_var_set_postCond) = if isSome postCondOpt then holfoot_a_proposition2term (valOf postCondOpt) else (holfoot_stack_true_term, empty_tmset);
          in
             (preCond, read_var_set_preCond, postCond, read_var_set_postCond)
          end
       else
          let
             val _ = if isSome preCondOpt orelse isSome postCondOpt orelse
                        not (ref_args = []) orelse not (val_args = []) then
                           raise holfoot_unsupported_feature_exn ("init function must not have parameters or pre- / postconditions") else ();                   
             val (preCond, read_var_set_preCond) = (holfoot_stack_true_term,empty_tmset);
             val postCondL = listSyntax.mk_list (map (fn (a,(b,c)) => b) resL, Type `:holfoot_a_proposition`);
             val postCond = mk_comb (holfoot_ap_bigstar_list_term, postCondL);
             val read_var_set_postCond = foldr HOLset.union empty_tmset (map (fn (a,(b,c)) => c) resL)
          in
             (preCond, read_var_set_preCond, postCond, read_var_set_postCond)                  
          end;

   val localV_set = HOLset.addList (empty_tmset, map string2holfoot_var (append localV val_args));
   val (force_user_wr, write_var_set_user, read_var_set_user) = decode_rwOpt rwOpt;

   val write_var_set = HOLset.difference (HOLset.union (write_var_set_body, write_var_set_user), localV_set);
   val read_var_set = let
        val set1 =  HOLset.union (read_var_set_preCond, HOLset.union (read_var_set_postCond, 
                                  HOLset.union (read_var_set_body, read_var_set_user)));
        val set2 = HOLset.difference (set1, write_var_set);
        val set3 = HOLset.difference (set2, localV_set);
     in set3 end;

   val (write_var_set, read_var_set) = 
       if force_user_wr then 
          (write_var_set_user, read_var_set_user) else
          (write_var_set,      read_var_set);                              

   val done_funcalls = [(funname, map (fn s => (SOME (string2holfoot_var s))) ref_args)] 
   val funcalls2 = funcalls_prune localV_set done_funcalls funcalls;
in
  (funname, (ref_args, write_var_set, read_var_set, localV_set,
        funcalls2, done_funcalls),
        (assume_opt, fun_body_term, val_args, localV, preCond, postCond))
end |
 Pfundecl2hol _ _ _ = Raise (holfoot_unsupported_feature_exn ("-"));







(*

val (funname, (ref_args, write_var_set, read_var_set, local_var_set,
        funcalls, done_funcalls),
        (fun_body_term, val_args, localV, preCond, postCond)) = 
 hd fun_decl_parse_read_writeL3;
*)


fun string_to_label s = mk_var (s, markerSyntax.label_ty)

fun Pfundecl2hol_final (funname, (ref_args, write_var_set, read_var_set, local_var_set,
        funcalls, done_funcalls),
        (assume_opt, fun_body_term, val_args, localV, preCond, postCond)) = 
   let
   val fun_body_local_var_term = foldr holfoot_mk_local_var fun_body_term localV;

   val used_vars = ref (free_vars fun_body_local_var_term);
        fun mk_new_var x = let
                         val v = variant (!used_vars) (mk_var x);
                    val _ = used_vars := v::(!used_vars);
                 in v end;
   val arg_ref_term = mk_new_var ("arg_refL", Type `:holfoot_var list`);
   val arg_val_term = mk_new_var ("arg_valL", Type `:num list`);
   val arg_valL = mk_el_list (length val_args) arg_val_term;

   val fun_body_val_args_term = foldr holfoot_mk_call_by_value_arg fun_body_local_var_term (zip val_args arg_valL);

   val arg_refL = mk_el_list (length ref_args) arg_ref_term;
   val arg_ref_varL = map string2holfoot_var ref_args;
   val arg_ref_subst = map (fn (vt, s) => (vt |-> s)) (zip arg_ref_varL arg_refL)
   val fun_body_final_term = subst arg_ref_subst fun_body_val_args_term;
   val fun_term = pairLib.mk_pabs (pairLib.mk_pair(arg_ref_term, arg_val_term), fun_body_final_term);

   val arg_val_varL = map (fn s => mk_comb (holfoot_exp_var_term, string2holfoot_var s)) val_args;
   val arg_val_expL = map (fn c => mk_comb (holfoot_exp_const_term, c)) arg_valL;
   val arg_val_subst1 = map (fn (vt, s) => (vt |-> s)) (zip arg_val_varL arg_val_expL);

   val arg_val_numL = map (fn s => mk_var (s, numLib.num)) val_args;
   val arg_val_subst2 = map (fn (vt, s) => (vt |-> s)) (zip arg_val_numL arg_valL);
   val arg_val_subst = append arg_val_subst1 arg_val_subst2;

   val preCond2 = mk_holfoot_prop_input write_var_set read_var_set (SOME arg_ref_varL) preCond;
   val postCond2 = mk_holfoot_prop_input write_var_set read_var_set (SOME arg_ref_varL) postCond;

   val preCond3 = subst (append arg_val_subst arg_ref_subst) preCond2;
   val postCond3 = subst (append arg_val_subst arg_ref_subst) postCond2;


   val cond_free_var_list = 
       let
          val set1 = HOLset.addList(empty_tmset, free_vars preCond3);
          val set2 = HOLset.addList(set1, free_vars postCond3);
          val set3 = HOLset.delete (set2, arg_ref_term) handle HOLset.NotFound => set2;
          val set4 = HOLset.delete (set3, arg_val_term) handle HOLset.NotFound => set3;
       in
          HOLset.listItems set4
       end;
   
   val ref_arg_names = listSyntax.mk_list (map string_to_label ref_args, markerSyntax.label_ty);
   val val_args_const = map (fn s => s ^ "_const") val_args;
   val val_arg_names = listSyntax.mk_list (map string_to_label val_args_const, markerSyntax.label_ty);

   val wrapped_preCond = list_mk_icomb (fasl_procedure_call_preserve_names_wrapper_term,
      [ref_arg_names, val_arg_names,
       pairLib.mk_pabs (pairLib.mk_pair(arg_ref_term, arg_val_term), preCond3),
       pairLib.mk_pair(arg_ref_term, arg_val_term)]);

   val abstr_prog = 
       list_mk_icomb (holfoot_prog_quant_best_local_action_term, [mk_list_pabs cond_free_var_list wrapped_preCond, mk_list_pabs cond_free_var_list postCond3])
   val abstr_prog_val_args_term = pairLib.mk_pabs (pairLib.mk_pair(arg_ref_term, arg_val_term), abstr_prog);
in
   (assume_opt, funname, fun_term, abstr_prog_val_args_term)
end



fun p_item___is_fun_decl (Pfundecl _) = true |
     p_item___is_fun_decl _ = false;


fun p_item___is_resource (Presource _) = true |
     p_item___is_resource _ = false;

(*
val examplesDir = concat [Globals.HOLDIR, "/examples/separationLogic/src/holfoot/EXAMPLES/"]
val file = concat [examplesDir, "list.sf"]; 

val prog2 = parse file
val t = parse_holfoot_file file


fun dest_Pprogram (Pprogram (ident_decl, program_item_decl)) = 
   (ident_decl, program_item_decl);

val (ident_decl, program_item_decl) = dest_Pprogram prog2;
*)


fun Pprogram2term procL_opt (Pprogram (ident_decl, program_item_decl)) =
   let
      (*ignore ident_decl*)
      val resource_list = filter p_item___is_resource program_item_decl;
      val resource_parseL = map Presource2hol resource_list;
      val resource_parse_termL =map (fn (name, (prop, vars)) =>
          let
             val name_term = stringLib.fromMLstring name;
             val varL = listSyntax.mk_list (HOLset.listItems vars, Type `:holfoot_var`);
          in
             pairLib.mk_pair(name_term, pairLib.mk_pair(varL, prop))
          end) resource_parseL
      val resource_parseL_term = listSyntax.mk_list (resource_parse_termL,
                         Type `:string # holfoot_var list # holfoot_a_proposition`);
      val resource_term = mk_comb (HOLFOOT_LOCK_ENV_MAP_term, resource_parseL_term);

      val fun_decl_list = filter p_item___is_fun_decl program_item_decl;
      (*parse without knowledge about the functions read- write requirements*)
      val fun_decl_parse_read_writeL = map (Pfundecl2hol [] resource_parseL) fun_decl_list
      (*calculate the functions read- write requirements*)
      val fun_decl_parse_read_writeL2 = fun_decl_update_read_write fun_decl_parse_read_writeL [];

      (*parse again*)
      val fun_decl_parse_read_writeL3 = map (Pfundecl2hol fun_decl_parse_read_writeL2 resource_parseL) fun_decl_list

 
      val fun_decl_parseL = map Pfundecl2hol_final fun_decl_parse_read_writeL3;

      fun assume_proc_spec assume_opt proc =
         if (not assume_opt) then F else
         if (not (isSome procL_opt)) then T else
         if (mem proc (valOf procL_opt)) then T else F;

      fun mk_pair_terms (assume_opt, s, fun_body, spec) =
         pairLib.list_mk_pair [assume_proc_spec assume_opt s, stringLib.fromMLstring s, fun_body, spec];
      val fun_decl_parse_pairL = map mk_pair_terms fun_decl_parseL;

      val input = listSyntax.mk_list (fun_decl_parse_pairL, type_of (hd fun_decl_parse_pairL));

   in
      (list_mk_icomb (HOLFOOT_SPECIFICATION_term, [resource_term, input]))
   end;




val parse_holfoot_file = (Pprogram2term NONE) o parse;
fun parse_holfoot_file_restrict procL = (Pprogram2term (SOME procL)) o parse;

end