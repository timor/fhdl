USING: accessors combinators compiler.tree compiler.tree.propagation.info
formatting io kernel math math.intervals math.parser module.factor sequences ;

IN: fhdl.verilog

! * Verilog representations

<PRIVATE

: make-verilog-var ( value -- str )
    "v_%d" sprintf ;

ERROR: unconstrained-value value ;

: value-verilog-range ( value -- str )
    dup value-info interval>>
    {
        { full-interval [ unconstrained-value ] }
        { empty-interval [ unconstrained-value ] }
        [ nip interval-length log2 1 + "[%s:0]" sprintf ]
    } case ;

: define-output-nets ( node -- node )
    dup out-d>>
    [ dup make-verilog-var set-value-name ] each
    ;

: var-definition ( value type -- str )
    swap [ value-verilog-range ] [ value-name ] bi
    "%s %s %s;" sprintf ;

! TODO inline
: wire-definition ( value -- str )
    "wire" var-definition ;

! Generate identifiers from stack effects
: effect-ports ( effect -- ins outs )
    [ in>> ] [ out>> ] bi
    "i" "o"
    [ swap [ "%s%s_%d" sprintf ] with map-index ] bi-curry@ bi* ;

! ! TODO: widths
! : ports-declaration ( node effect -- str )
!     effect-ports "input" "output" [ swap [ "%s %s" sprintf ] with map ] bi-curry@ bi* append
!     ",\n " join ;

: net-assignment ( value output -- str )
    swap value-name "assign %s = %s;" sprintf ;

PRIVATE>

! * Verilog Code Generation from SSA Tree Node

! This is called for each node, and expected to print verilog code to stdout
GENERIC: node>verilog ( node -- )

! TODO: rewrite with combinators
M: #introduce node>verilog
    module-name
    module-effect effect-ports append ", " join
    "module %s(%s);" printf nl

    out-d>>
    module-effect effect-ports drop
    [
        [ set-value-name ] keepd
        "input" var-definition print
    ] 2each
    ;

M: #call node>verilog
    define-output-nets

    dup out-d>> [ wire-definition print nl ] each

    [ identity-hashcode "inst_%d" sprintf ]
    [ word>> name>> ]
    [ in-d>> [ value-name ] map ", " join ] tri
    "%s \\%s (%s);" printf nl ;

GENERIC: literal>verilog ( literal -- str )
M: number literal>verilog number>string ;
M: boolean literal>verilog "1" "0" ? ;

M: #push node>verilog
    [ out-d>> first ] [ literal>> literal>verilog ] bi set-value-name ;

M: #renaming node>verilog
    inputs/outputs swap [ value-name set-value-name ] 2each ;

M: #return node>verilog
    in-d>>
    dup [ "output" var-definition print ] each
    module-effect effect-ports nip
    [ net-assignment print ] 2each
    "endmodule" print ;

M: #declare node>verilog drop ;

! * Converting a Word or Quotation into Verilog code

! TODO: rename
: code>verilog ( word/quot -- )
    [
        node>verilog
    ] each-node-in-module ;
