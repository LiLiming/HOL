structure codegen_armLib :> codegen_armLib =
struct

open HolKernel boolLib bossLib Parse;
open codegen_inputLib helperLib;


fun arm_guard2assembly (GUARD_NOT t) = let 
      val (code,(x,y)) = arm_guard2assembly t in (code,(y,x)) end
  | arm_guard2assembly (GUARD_COMPARE (i,cmp,j)) = let
      val rd = "r" ^ int_to_string i
      fun f (ASSIGN_X_REG r) = "r" ^ int_to_string r
        | f (ASSIGN_X_CONST c) = "#" ^ Arbnum.toString c
      val code = ["cmp " ^ rd ^ ", " ^ f j]
      fun g (GUARD_COMPARE_LESS false) = ("cc","cs")
        | g (GUARD_COMPARE_LESS true) = ("lt","ge")
        | g (GUARD_COMPARE_LESS_EQUAL false) = ("ls","hi")
        | g (GUARD_COMPARE_LESS_EQUAL true) = ("le","gt")
        | g (GUARD_COMPARE_EQUAL) = ("eq","ne")
      in (code, g cmp) end
  | arm_guard2assembly (GUARD_TEST (i,j)) = let
      val rd = "r" ^ int_to_string i
      fun f (ASSIGN_X_REG r) = "r" ^ int_to_string r
        | f (ASSIGN_X_CONST c) = "#" ^ Arbnum.toString c
      val code = ["tst " ^ rd ^ ", " ^ f j]
      in (code, ("eq","ne")) end

val arm_assign2assembly = let
  fun r i = "r" ^ int_to_string i
  fun s i = "[sp,#" ^ int_to_string (4 * i) ^ "]"
  fun address (ASSIGN_ADDRESS_REG i) = "[" ^ r i ^ "]"
    | address (ASSIGN_ADDRESS_OFFSET_ADD (d,i)) = "[" ^ r d ^ ", #" ^ Arbnum.toString i ^ "]"
    | address (ASSIGN_ADDRESS_OFFSET_SUB (d,i)) = "[" ^ r d ^ ", #-" ^ Arbnum.toString i ^ "]"
  fun assign_const_to_reg i d = let
    fun add_byte i n = let
      val k = Arbnum.div(i,Arbnum.pow(Arbnum.fromInt 2,Arbnum.fromInt n))
      val k = Arbnum.mod(k,Arbnum.fromInt 256)
      in if Arbnum.<(k,Arbnum.fromInt 1) then [] else [(Arbnum.toInt k,n)] end
    val res = add_byte i 0 @ add_byte i 8 @ add_byte i 16 @ add_byte i 24    
    fun sub k [] = []
      | sub k ((i,j)::xs) = (i,j-k) :: sub j xs
    val res = sub 0 res
    fun ins [] = []
      | ins ((i,j)::xs) = let 
         val k = (if xs = [] then "mov? " ^ r d else "add? " ^ r d ^ ", " ^ r d)
         val l = k ^ ", #" ^ int_to_string i
         in ins xs @ [l] @ (if j = 0 then [] else ["mov? " ^ r d ^ ", " ^ r d ^ ", LSL #" ^ int_to_string j]) end        
    in ins res end
  fun binop_to_name ASSIGN_BINOP_ADD _ = "add"
    | binop_to_name ASSIGN_BINOP_SUB false = "sub"
    | binop_to_name ASSIGN_BINOP_SUB true = "rsb"
    | binop_to_name ASSIGN_BINOP_TIMES _ = "mul"
    | binop_to_name ASSIGN_BINOP_AND _ = "and"
    | binop_to_name ASSIGN_BINOP_XOR _ = "xor"
    | binop_to_name ASSIGN_BINOP_OR _ = "orr"
  fun code_for_binop d b (ASSIGN_X_REG i) (ASSIGN_X_REG j) reversed = 
       if b = ASSIGN_BINOP_TIMES then
         if d = i andalso i = j then hd [] else
           if d = i then code_for_binop d b (ASSIGN_X_REG j) (ASSIGN_X_REG i) (not reversed)
           else [binop_to_name b reversed ^ "? " ^ r d ^ ", " ^ r i ^ ", " ^ r j]
       else [binop_to_name b reversed ^ "? " ^ r d ^ ", " ^ r i ^ ", " ^ r j]
    | code_for_binop d b (ASSIGN_X_CONST i) (ASSIGN_X_REG j) reversed =
        code_for_binop d b (ASSIGN_X_REG j) (ASSIGN_X_CONST i) (not reversed)
    | code_for_binop d b (ASSIGN_X_CONST i) (ASSIGN_X_CONST j) reversed = hd []
    | code_for_binop d b (ASSIGN_X_REG i) (ASSIGN_X_CONST j) reversed = let
        val code = assign_const_to_reg j i 
        in if length code = 1 andalso not (b = ASSIGN_BINOP_TIMES) then 
             [binop_to_name b reversed ^ "? " ^ r d ^ "," ^ 
              ((implode o tl o tl o tl o tl o explode o hd) code)]
           else if d = i then hd [] else           
             assign_const_to_reg j d @ 
             code_for_binop d b (ASSIGN_X_REG i) (ASSIGN_X_REG d) reversed
        end
  fun f (ASSIGN_EXP (d, ASSIGN_EXP_REG s)) = ["mov? " ^ r d ^ ", " ^ r s]
    | f (ASSIGN_EXP (d, ASSIGN_EXP_CONST i)) = assign_const_to_reg i d      
    | f (ASSIGN_EXP (d, ASSIGN_EXP_STACK i)) = ["ldr? " ^ r d ^ ", " ^ s i]
    | f (ASSIGN_EXP (d, ASSIGN_EXP_BINOP (i,b,j))) = code_for_binop d b i j false
    | f (ASSIGN_EXP (d, ASSIGN_EXP_MONOP (ASSIGN_MONOP_NOT, ASSIGN_X_REG i))) = ["mvn? " ^ r d ^ ", " ^ r i]
    | f (ASSIGN_EXP (d, ASSIGN_EXP_MONOP (ASSIGN_MONOP_NEG, ASSIGN_X_REG i))) = ["rsb? " ^ r d ^ ", " ^ r i ^ ", #0"]
    | f (ASSIGN_EXP (d, ASSIGN_EXP_MEMORY a)) = ["ldr? " ^ r d ^ ", " ^ address a]       
    | f (ASSIGN_EXP (d, ASSIGN_EXP_SHIFT_LEFT (ASSIGN_X_REG i,n))) = ["mov? " ^ r d ^ ", " ^ r i ^ ", LSL #" ^ int_to_string n ]
    | f (ASSIGN_EXP (d, ASSIGN_EXP_SHIFT_RIGHT (ASSIGN_X_REG i,n))) = ["mov? " ^ r d ^ ", " ^ r i ^ ", LSR #" ^ int_to_string n ]
    | f (ASSIGN_EXP (d, ASSIGN_EXP_SHIFT_ARITHMETIC_RIGHT (ASSIGN_X_REG i,n))) = ["mov? " ^ r d ^ ", " ^ r i ^ ", ASR #" ^ int_to_string n ]
    | f (ASSIGN_STACK (i,d)) = ["str? " ^ r d ^ ", " ^ s i]
    | f (ASSIGN_MEMORY (a,d)) = ["str? " ^ r d ^ ", " ^ address a]
    | f _ = hd []
  in f end  

fun arm_conditionalise c condition = let
  val c' = String.translate (fn x => if x = #"?" then condition else implode [x]) c
  in if c = c' then hd [] else c' end

fun arm_remove_annotations c = 
  String.translate (fn x => if x = #"?" then "" else implode [x]) c

fun arm_cond_code tm = 
  (* carry    *) if tm = ``aS1 sC`` then ("cs","cc") else
  (* zero     *) if tm = ``aS1 sZ`` then ("eq","ne") else
  (* negative *) if tm = ``aS1 sN`` then ("mi","pl") else
  (* overflow *) if tm = ``aS1 sV`` then ("vs","vc") else hd []

fun arm_encode_instruction s = let
  val tm = mk_comb(``enc``,instructionSyntax.mk_instruction s)
  in ((Arbnum.toHexString o numSyntax.dest_numeral o cdr o cdr o concl o EVAL) tm,4) end

fun arm_encode_branch forward l cond = let
  fun asm NONE = "b" 
    | asm (SOME c) = if hd (explode c) = #"b" then c else "b" ^ c
  val code = if forward then asm cond ^ " " ^ int_to_string (l + 4)
                        else asm cond ^ " -" ^ int_to_string l
  in arm_encode_instruction code end 


end;