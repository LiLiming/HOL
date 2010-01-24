type pos = (int * int);
type arg = int;
open Tokens;
type lexresult  = (svalue,pos) token


fun mkTok f text pos line =
  (f text, (pos - String.size text, line), (pos, line));

fun mkMtTok text pos line = 
  ((pos - String.size text, line), (pos, line));

fun I x = x;
val yylineno = ref 0;

fun eof () = EOF ((~1, ~1), (~1, ~1));



exception LexicalError of string * string * int (* (message, loc1, loc2) *)
fun lexError msg text pos line =
  (raise (LexicalError (msg, text, line)))


(* The table of keywords *)

val keyword_table =
List.foldl (fn ((str, tok), t) => Binarymap.insert (t, str, tok))
(Binarymap.mkDict String.compare)
[
  ("dispose",   DISPOSE),
  ("else",      ELSE),
  ("emp",       EMPTY),
  ("if",        IF),
  ("local",     LOCAL),
  ("new",       NEW),
  ("resource",  RESOURCE),
  ("then",      THEN),
  ("when",      WHEN),
  ("while",     WHILE),
  ("with",      WITH),
  ("dlseg",     DLSEG),
  ("list" ,     LIST),
  ("lseg",      LISTSEG),
  ("data_list", DATA_LIST),
  ("data_lseg", DATA_LISTSEG),
  ("tree" ,     TREE),
  ("xlseg",     XLSEG),
  ("true" ,     TT),
  ("false",     FF),
  ("NULL",      (fn (x,y) => NAT (0,x,y)))
];


fun mkKeyword text pos line =
  (Binarymap.find (keyword_table, text)) (mkMtTok text pos line)
  handle Binarymap.NotFound => IDENT (mkTok I text pos line);




%%
%header (functor SmallfootLexFun(structure Tokens : Smallfoot_TOKENS));
%s Comment;


newline=(\010 | \013 | "\013\010");
blank = [\ | \009 | \012];
letter = [A-Z\_a-z];
digit = [0-9];
alphanum = ({digit} | {letter});
ident = {letter} {alphanum}*;
qident = ("_" | "#") {ident};
num = [0-9]+;
hol_quote = "``" [^ `\``]* "``";



%%


<INITIAL>{newline} => ( continue () );
<INITIAL>{blank} => ( continue () );
<INITIAL>"/*" =>
  ( (YYBEGIN Comment; lex ()) );
<INITIAL>"|->" =>
  ( POINTSTO (mkMtTok yytext yypos (!yylineno)) );
<INITIAL>"," =>
  ( COMMA (mkMtTok yytext yypos (!yylineno)) );
<INITIAL>"," =>
  ( COMMA (mkMtTok yytext yypos (!yylineno)) );
<INITIAL>"{" =>
  ( LBRACE (mkMtTok yytext yypos (!yylineno)) );
<INITIAL>"[" =>
  ( LBRACKET (mkMtTok yytext yypos (!yylineno)) );
<INITIAL>"(" =>
  ( LPAREN (mkMtTok yytext yypos (!yylineno)) );
<INITIAL>"->" =>
  ( MINUSGREATER (mkMtTok yytext yypos (!yylineno)) );
<INITIAL>"}" =>
  ( RBRACE (mkMtTok yytext yypos (!yylineno)) );
<INITIAL>"]" =>
  ( RBRACKET (mkMtTok yytext yypos (!yylineno)) );
<INITIAL>")" =>
  ( RPAREN (mkMtTok yytext yypos (!yylineno)) );
<INITIAL>";" =>
  ( SEMI (mkMtTok yytext yypos (!yylineno)) );
<INITIAL>"&&" =>
  ( AMPERAMPER (mkMtTok yytext yypos (!yylineno)) );
<INITIAL>"||" =>
  ( BARBAR (mkMtTok yytext yypos (!yylineno)) );
<INITIAL>":" =>
  ( COLON (mkMtTok yytext yypos (!yylineno)) );
<INITIAL>"=" =>
  ( EQUAL (mkMtTok yytext yypos (!yylineno)) );
<INITIAL>"==" =>
  ( EQUALEQUAL (mkMtTok yytext yypos (!yylineno)) );
<INITIAL>"!=" =>
  ( BANGEQUAL (mkMtTok yytext yypos (!yylineno)) );
<INITIAL>("<" | "<=" | ">" | ">=") =>
  ( INFIXOP1 (mkTok I yytext yypos (!yylineno)) );
<INITIAL>("+" | "-") =>
  ( INFIXOP2 (mkTok I yytext yypos (!yylineno)) );
<INITIAL>("/" | "%") =>
  ( INFIXOP3 (mkTok I yytext yypos (!yylineno)) );
<INITIAL>"*" =>
  ( STAR (mkMtTok yytext yypos (!yylineno)) );
<INITIAL>"^" =>
  ( XOR (mkMtTok yytext yypos (!yylineno)) );
<INITIAL>{hol_quote} =>
  ( HOL_TERM (mkTok (fn s => (substring (s, 2, (String.size s)-4))) yytext yypos (!yylineno)) );
<INITIAL>{num} =>
  ( NAT (mkTok (fn s => (valOf(Int.fromString s))) yytext yypos (!yylineno)) );
<INITIAL>{ident} =>
  ( mkKeyword yytext yypos (!yylineno) );
<INITIAL>{qident} =>
  ( QIDENT (mkTok I yytext yypos (!yylineno)) );
<INITIAL>. =>
  ( lexError "ill-formed token" yytext yypos (!yylineno) );

<Comment>"*/" =>
  ( YYBEGIN INITIAL; lex ());
<Comment>[^*/]+ =>
  ( continue () );
<Comment>. => 
  ( continue () );
