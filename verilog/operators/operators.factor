USING: accessors assocs combinators.short-circuit compiler.tree fhdl.module
fhdl.verilog fhdl.verilog.syntax generic io kernel math math.partial-dispatch
sequences words ;

IN: fhdl.verilog.operators

! * Verilog operator expression generation

! Arithmetic expressions are generated from #call nodes which the compiler has
! transformed into calls to specialized words on fixnums and integers

CONSTANT: binary-ops
H{
    { + "+" }
    { - "-" }
    { * "*" }
    { < "<" }
    { > ">" }
    { bitand "&" }
    { bitor "|" }
    { bitxor "^" }
    { bitnot "~" }
}

GENERIC: verilog-operator ( word -- str )
M: math-partial verilog-operator generic-variant binary-ops at ;
M: method verilog-operator parent-word binary-ops at ;
M: word verilog-operator
    {
        [ binary-ops [ drop swap integer-derived-ops member? ] with assoc-find drop nip ]
        [ binary-ops at ]
    } 1|| ;

PREDICATE: binary-op-node < #call word>> verilog-operator ;

M: binary-op-node node>verilog
    [ out-d>> first get-var name>> ]
    [ in-d>> [ value-name ] map first2 ]
    [ word>> verilog-operator ] tri
    binary-expression
    assign-net print
    ;
