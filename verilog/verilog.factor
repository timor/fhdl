USING: accessors combinators compiler.tree compiler.tree.def-use.simplified
compiler.tree.propagation.info fhdl.module fhdl.tree formatting io kernel math
math.intervals math.parser sequences shuffle variables ;

IN: fhdl.verilog

! * Clocks and resets

! Per default, each module gets prefixed with a clock and an async reset value implicitly,
! which is connected to all registers implicitly

GLOBAL: clock-name
GLOBAL: reset-name
"clock" set: clock-name
"reset" set: reset-name

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
    [ swap [ "%s_%s_%d" sprintf ] with map-index ] bi-curry@ bi* ;

: define-output-nets ( node -- node )
    dup out-d>>
    [ dup make-verilog-var set-value-name ] each
    dup out-d>> [ wire-definition print nl ] each
    ;

: reg-var-assignment ( reg-name source-name -- str )
    "%s <= %s;" sprintf ;

: wrap-begin-block ( str -- str )
    "begin\n" "\nend" surround ;

: if-else-statement ( cond then else -- str )
    [ "if(%s)\n" sprintf ] [ " " prepend ] [ "\nelse\n " prepend ] tri*
    append append ;

: reg-always-block ( source-val-name reg-val-name clock reset -- str )
    [ "always @(posedge %s or posedge %s) " sprintf ] keep
    "%s == 1'b1" sprintf
    2swap [ nip 0 reg-var-assignment ] [ swap reg-var-assignment ] 2bi
    if-else-statement
    wrap-begin-block append ;


PRIVATE>

: net-assignment ( lhs-value rhs -- str )
    "assign %s = %s;" sprintf ;

! * Verilog Code Generation from SSA Tree Node

! This is called for each node, and expected to print verilog code to stdout
GENERIC: node>verilog ( node -- )

! TODO: rewrite with combinators
M: #introduce node>verilog
    module-name
    module-effect effect-ports append
    reset-name prefix clock-name prefix
    ", " join
    "module \\%s (%s);" printf nl
    clock-name "input %s;" printf nl
    reset-name "input %s;" printf nl

    out-d>>
    module-effect effect-ports drop
    [
        [ set-value-name ] keepd
        "input" var-definition print
    ] 2each
    ;

M: #call node>verilog
    define-output-nets

    [ identity-hashcode "inst_%d" sprintf ]
    [ word>> name>> ]
    [ in-d>> [ value-name ] map ", " join ] tri
    "%s \\%s (%s);" printf nl ;


M: reg-node node>verilog
    [ out-d>> first ] [ in-d>> first ] bi
    over [ dup make-verilog-var set-value-name ] [ "reg" var-definition print ] bi
    swap [ value-name ] bi@ clock-name reset-name reg-always-block print

    ! [ out-d>> first dup <reg> ]
    ! [ in-d>> first defining-variable name>> ] 2bi
    ! over name>> swap "%s <= %s" sprintf >>assignment
    ! add-var
    ;

<PRIVATE
GENERIC: literal>verilog ( literal -- str )
M: number literal>verilog number>string ;
M: boolean literal>verilog "1" "0" ? ;

: reg-push-node? ( node -- ? )
    out-d>> first actually-used-by first node>> reg-node? ;
PRIVATE>

M: #push node>verilog
    dup reg-push-node?
    [ drop ] [
        [ out-d>> first ] [ literal>> literal>verilog ] bi set-value-name
    ] if ;

M: #renaming node>verilog
    inputs/outputs swap [ value-name set-value-name ] 2each ;

<PRIVATE
! FIXME: this duplicated code from net-assignment and var-definiton. If either of those
! change, a better abstraction is probably needed.
: output-port-decl-def ( port value -- str )
    [ value-verilog-range swap "output %s %s;" sprintf ]
    [ value-name " assign %s = %s;" sprintf ] 2bi append ;
PRIVATE>

M: #return node>verilog
    in-d>>
    module-effect effect-ports nip
    [ swap output-port-decl-def print ] 2each
    "endmodule" print ;

M: #declare node>verilog drop ;

! * Converting a Word or Quotation into Verilog code

! TODO: rename
: code>verilog ( word/quot -- )
    [
        node>verilog
    ] each-node-in-module ;
