eqtype int
type num = arbnum.num

val zero : int
val one : int
val two : int

val toString : int -> string
val fromString : string -> int

val fromInt : Int.int -> int
val fromNat : num -> int
val toInt : int -> Int.int
val toNat : int -> num

val + : (int * int) -> int
val - : (int * int) -> int
val * : (int * int) -> int
val div : (int * int) -> int
val mod : (int * int) -> int
val divmod : (int * int) -> (int * int)
val negate : int -> int
val ~ : int -> int

val < : int * int -> bool
val <= : int * int -> bool
val > : int * int -> bool
val >= : int * int -> bool

val abs : int -> int

val compare : (int * int) -> order
