structure holindexData :> holindexData =
struct

val scomp = String.collate (fn (c1, c2) =>
    Char.compare (Char.toUpper c1, Char.toUpper c2))

type data_entry =
   {label         : string option,
    in_index      : bool,
    full_index    : bool option,
    comment       : string option,
    pos_opt       : int option,
    options       : string,
    content       : string option,
    pages         : string Redblackset.set}

val default_data_entry =
  ({label         = NONE,
    in_index      = false,
    full_index    = NONE,
    pos_opt       = NONE,
    comment       = NONE,
    options       = "",
    content       = NONE,
    pages         = (Redblackset.empty String.compare)}:data_entry)

fun data_entry___update_in_index new_ii
  ({label         = label,
    in_index      = in_index,
    full_index    = full_index,
    comment       = comment,
    pos_opt       = pos_opt,
    options       = options,
    content       = content,
    pages         = pages}:data_entry) =
   {label            = label,
    in_index      = new_ii,
    full_index    = full_index,
    comment       = comment,
    pos_opt       = pos_opt,
    options       = options,
    content       = content,
    pages         = pages}:data_entry;


fun data_entry___update_full_index new_fi
  ({label         = label,
    in_index      = in_index,
    full_index    = full_index,
    comment       = comment,
    pos_opt       = pos_opt,
    options       = options,
    content       = content,
    pages         = pages}:data_entry) =
   {label            = label,
    in_index      = in_index,
    full_index    = SOME new_fi,
    comment       = comment,
    pos_opt       = pos_opt,
    options       = options,
    content       = content,
    pages         = pages}:data_entry;


fun data_entry___update_label new_label
  ({label         = label,
    in_index      = in_index,
    full_index    = full_index,
    comment       = comment,
    pos_opt       = pos_opt,
    options       = options,
    content       = content,
    pages         = pages}:data_entry) =
   {label         = new_label,
    in_index      = in_index,
    full_index    = full_index,
    comment       = comment,
    pos_opt       = pos_opt,
    options       = options,
    content       = content,
    pages         = pages}:data_entry;


fun data_entry___update_comment new_comment
  ({label         = label,
    in_index      = in_index,
    full_index    = full_index,
    comment       = comment,
    pos_opt       = pos_opt,
    options       = options,
    content       = content,
    pages         = pages}:data_entry) =
   {label         = label,
    in_index      = in_index,
    full_index    = full_index,
    comment       = new_comment,
    pos_opt       = pos_opt,
    options       = options,
    content       = content,
    pages         = pages}:data_entry;

fun data_entry___update_options new_op
  ({label         = label,
    in_index      = in_index,
    full_index    = full_index,
    comment       = comment,
    pos_opt       = pos_opt,
    options       = options,
    content       = content,
    pages         = pages}:data_entry) =
   {label         = label,
    in_index      = in_index,
    full_index    = full_index,
    comment       = comment,
    pos_opt       = pos_opt,
    options       = new_op,
    content       = content,
    pages         = pages}:data_entry;

fun data_entry___update_content new_content
  ({label         = label,
    in_index      = in_index,
    full_index    = full_index,
    comment       = comment,
    pos_opt       = pos_opt,
    options       = options,
    content       = content,
    pages         = pages}:data_entry) =
   {label         = label,
    in_index      = in_index,
    full_index    = full_index,
    comment       = comment,
    pos_opt       = pos_opt,
    options       = options,
    content       = new_content,
    pages         = pages}:data_entry;

val data_entry___pos_counter_ref = ref 0;
fun data_entry___add_page page
  ({label         = label,
    in_index      = in_index,
    full_index    = full_index,
    comment       = comment,
    pos_opt       = pos_opt,
    options       = options,
    content       = content,
    pages         = pages}:data_entry) =
   let
      val new_pos_opt =
         if isSome pos_opt then pos_opt else
         (data_entry___pos_counter_ref := (!data_entry___pos_counter_ref) + 1;
          SOME (!data_entry___pos_counter_ref));
   in
   {label         = label,
    in_index      = in_index,
    full_index    = full_index,
    comment       = comment,
    pos_opt       = new_pos_opt,
    options       = options,
    content       = content,
    pages         = Redblackset.add(pages,page)}:data_entry
   end;


fun data_entry_is_used
  ({label         = label,
    in_index      = in_index,
    full_index    = full_index,
    comment       = comment,
    pos_opt       = pos_opt,
    options       = options,
    content       = content,
    pages         = pages}:data_entry) =
   (in_index orelse isSome pos_opt);


val new_data_substore = (Redblackmap.mkDict scomp):(string, data_entry) Redblackmap.dict

val new_data_store  =  (*Thms, Terms, Types*)
   (new_data_substore, new_data_substore, new_data_substore);


(*
   val key1 = "Term";
   val key2 = "Term_ID_1"
   fun upf e = data_entry___add_page e "1";
*)
type data_store_ty = ((string, data_entry) Redblackmap.dict * (string, data_entry) Redblackmap.dict * (string, data_entry) Redblackmap.dict);

local
   fun update_data_substore sds (key:string) upf =
   let
      open Redblackmap
      val ent = find (sds, key) handle NotFound => default_data_entry;
      val ent' = upf ent;
      val sds' = insert(sds,key,ent')
   in
      sds'
   end;

in

fun update_data_store (sds_thm,sds_term,sds_type) "Thm" key upf =
   (update_data_substore sds_thm key upf,sds_term,sds_type)
| update_data_store (sds_thm,sds_term,sds_type) "Term" key upf =
   (sds_thm, update_data_substore sds_term key upf,sds_type)
| update_data_store (sds_thm,sds_term,sds_type) "Type" key upf =
   (sds_thm, sds_term, update_data_substore sds_type key upf)
| update_data_store (sds_thm,sds_term,sds_type) ty key upf =
   Feedback.failwith ("Unkwown entry_type '"^ty^"'!")

end;












type parse_entry =
   {id          : (string * string),
    label       : string option,
    force_index : bool,
    full_index  : bool option,
    comment     : string option,
    options     : string option,
    content     : string option}

fun mk_parse_entry id =
   {id          = id,
    label       = NONE,
    force_index = false,
    full_index  = NONE,
    comment     = NONE,
    options     = NONE,
    content     = NONE}:parse_entry

fun mk_update_parse_entry id up =
   (up (mk_parse_entry id)):parse_entry

fun parse_entry___set_label l
   ({id          = id,
    label       = label_opt,
    force_index = fi,
    full_index  = full_index,
    comment     = comment,
    options     = options_opt,
    content     = content_opt}:parse_entry) =
   {id          = id,
    label       = SOME l,
    force_index = fi,
    full_index  = full_index,
    comment     = comment,
    options     = options_opt,
    content     = content_opt}:parse_entry;

fun parse_entry___set_comment c
   ({id          = id,
    label       = label_opt,
    force_index = fi,
    full_index  = full_index,
    comment     = comment,
    options     = options_opt,
    content     = content_opt}:parse_entry) =
   {id          = id,
    label       = label_opt,
    force_index = fi,
    full_index  = full_index,
    comment     = SOME c,
    options     = options_opt,
    content     = content_opt}:parse_entry;

fun parse_entry___set_options new_opt
   ({id          = id,
    label       = label_opt,
    force_index = fi,
    full_index  = full_index,
    comment     = comment,
    options     = options_opt,
    content     = content_opt}:parse_entry) =
   {id          = id,
    label       = label_opt,
    force_index = fi,
    full_index  = full_index,
    comment     = comment,
    options     = SOME new_opt,
    content     = content_opt}:parse_entry;


fun parse_entry___set_content new_cont
   ({id          = id,
    label       = label_opt,
    force_index = fi,
    full_index  = full_index,
    comment     = comment,
    options     = options_opt,
    content     = content_opt}:parse_entry) =
   {id          = id,
    label       = label_opt,
    force_index = fi,
    full_index  = full_index,
    comment     = comment,
    options     = options_opt,
    content     = SOME new_cont}:parse_entry;

fun parse_entry___force_index
   ({id          = id,
    label       = label_opt,
    force_index = fi,
    full_index  = full_index,
    options     = options_opt,
    comment     = comment,
    content     = content_opt}:parse_entry) =
   {id          = id,
    label       = label_opt,
    force_index = true,
    full_index  = full_index,
    comment     = comment,
    options     = options_opt,
    content     = content_opt}:parse_entry;

fun parse_entry___full_index b
   ({id          = id,
    label       = label_opt,
    force_index = fi,
    full_index  = full_index,
    options     = options_opt,
    comment     = comment,
    content     = content_opt}:parse_entry) =
   {id          = id,
    label       = label_opt,
    force_index = fi,
    full_index  = SOME b,
    comment     = comment,
    options     = options_opt,
    content     = content_opt}:parse_entry;



fun parse_entry___add_to_data_store ds
  ({id          = (ety, id_s),
    label       = label_opt,
    force_index = fi,
    full_index  = full_i,
    comment     = comment_opt,
    options     = options_opt,
    content     = content_opt}:parse_entry) =
let
   fun update_fun ({label    = label,
                    in_index = in_index,
                    full_index = full_index,
                    comment    = comment,
                    pos_opt    = pos_opt,
                    options  = options,
                    content  = content,
                    pages    = pages}:data_entry) =
      ({label      = if isSome label_opt then label_opt else label,
        in_index   = fi orelse in_index,
        full_index = if isSome full_i then full_i else full_index,
        comment    = if isSome comment_opt then comment_opt else comment,
        pos_opt    = pos_opt,
        options    = if isSome options_opt then valOf options_opt else options,
        content    = if isSome content_opt then content_opt else content,
        pages      = pages}:data_entry);
in
   update_data_store ds ety id_s update_fun
end;


end