(module List-sig (lib "mlsig.scm" "lang")
  (provide List^)
  (require)
  (define-signature
   List^
   ((struct Empty ())
    null
    hd
    tl
    last
    nth
    take
    drop
    length
    rev
    @
    concat
    revAppend
    app
    map
    mapPartial
    find
    filter
    partition
    foldr
    foldl
    exists
    all
    tabulate
    getItem)))