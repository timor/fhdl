USING: accessors assocs compiler.tree fhdl.module fhdl.verilog
fhdl.verilog.private fhdl.verilog.syntax formatting io kernel
math.partial-dispatch math.private sequences sets ;

IN: fhdl.verilog.operators

! * Verilog operator expression generation

! Arithmetic expressions are generated from #call nodes which the compiler has
! transformed into calls to specialized words on fixnums and integers

CONSTANT: binary-ops {
    { { fixnum+ +-integer-integer +-fixnum-integer } "+" }
    { { fixnum* } "*" }
}

: binary-op-word? ( word -- ? )
    binary-ops keys combine member? ;

: verilog-operator ( word -- str )
    binary-ops [ drop swap member? ] with assoc-find drop nip ;

PREDICATE: binary-op-node < #call word>> binary-op-word? ;

M: binary-op-node node>verilog
    [ out-d>> first get-var name>> ]
    [ in-d>> [ value-name ] map first2 ]
    [ word>> verilog-operator ] tri
    binary-expression
    assign-net print
    ;
