USING: accessors assocs combinators.short-circuit compiler.tree fhdl.module
fhdl.types fhdl.verilog fhdl.verilog.syntax generic io kernel math
math.intervals math.partial-dispatch math.private sequences words ;

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
    { = "==" }
    { number= "==" }
}

CONSTANT: unary-ops
H{
    { bitnot "~" }
    { fixnum-bitnot "~" }
}

GENERIC: verilog-binary-op ( word -- str )
M: math-partial verilog-binary-op generic-variant binary-ops at ;
M: method verilog-binary-op parent-word binary-ops at ;
M: word verilog-binary-op
    {
        [ binary-ops [ drop swap integer-derived-ops member? ] with assoc-find drop nip ]
        [ binary-ops at ]
    } 1|| ;

GENERIC: verilog-unary-op ( word -- str )
M: math-partial verilog-unary-op generic-variant unary-ops at ;
M: method verilog-unary-op parent-word unary-ops at ;
M: word verilog-unary-op
    {
        [ unary-ops [ drop swap integer-derived-ops member? ] with assoc-find drop nip ]
        [ unary-ops at ]
    } 1|| ;

PREDICATE: binary-op-node < #call word>> verilog-binary-op ;
PREDICATE: unary-op-node < #call word>> verilog-unary-op ;

M: binary-op-node node>verilog
    [ out-d>> first get-var name>> ]
    [ in-d>> [ value-name ] map first2 ]
    [ word>> verilog-binary-op ] tri
    binary-expression
    assign-net print
    ;

M: unary-op-node node>verilog
    [ out-d>> first get-var name>> ]
    [ in-d>> first get-var name>> ]
    [ word>> verilog-unary-op ] tri
    unary-expression assign-net print ;

! Concatenation operator.  Top of stack contains the new lsb, the
! element below is the msb part
! that is the new lsb. e.g. ... n b --> 2*n+b

: lsb-concat ( b n -- n' )
    1 shift + ;
\ lsb-concat [
    nip clone [ 1 [a,a] interval-shift ] change-interval
] "outputs" set-word-prop

PREDICATE: concat-op-node < #call word>> \ lsb-concat = ;
M: concat-op-node node>verilog
    [ out-d>> first get-var name>> ]
    [ in-d>> [ get-var name>> ] map first2 ] bi
    binary-concatenation assign-net print ;

! TODO: handle dummy nodes differently, by updating any var information if
! possible and then copying the variable
PREDICATE: dummy-unary-node < #call word>> \ >bit = ;
M: dummy-unary-node node>verilog
    [ out-d>> first get-var name>> ]
    [ in-d>> first get-var name>> ] bi
    assign-net print ;
