USING: accessors compiler.tree compiler.tree.def-use.simplified fhdl.module
fhdl.tree.locals-propagation fhdl.verilog.syntax formatting io kernel
math.intervals prettyprint sequences variables ;

IN: fhdl.verilog

FROM: fhdl.module => mod ;

! * Clocks and resets

! Per default, each module gets prefixed with a clock and an async reset value implicitly,
! which is connected to all registers implicitly

GLOBAL: clock-name
GLOBAL: reset-name
"clock" set: clock-name
"reset" set: reset-name

! * Verilog representations

<PRIVATE

: var-definition ( value type -- str )
    [ [ value-name ] [ value-range ] bi ] dip
    var-decl ;

: wire-definition ( value -- str )
    "wire" var-definition ;


PRIVATE>

! * Verilog Code Generation from SSA Tree Node


! This is called for each node, and expected to print verilog code to stdout
GENERIC: node>verilog ( node -- )


M: #introduce node>verilog
    mod [ name>> ] [ effect>> effect-ports append ] bi
    reset-name prefix clock-name prefix
    begin-module print
    clock-name empty-interval "input" var-decl print
    reset-name empty-interval "input" var-decl print

    out-d>> [
        "input" var-definition print
    ] each
    ;

M: #call node>verilog
    dup out-d>> [
        "wire" var-definition print
    ] each

    out-d>>
    [ word>> name>> ]
    [ identity-hashcode "inst_%d" sprintf ]
    [ in-d>> [ value-name ] map ", " join ] tri
    instance print ;

! Converts set-local-value calls: ( value box -- )
M: local-writer-node node>verilog
    "writer:" print . ;

M: local-reader-node node>verilog
    "reader:" print
    out-d>> first value-name print
    ;

! M: reg-node node>verilog
!     [ out-d>> first ] [ in-d>> first ] bi
!     over [ dup make-verilog-var set-value-name ] [ "reg" var-definition print ] bi
!     swap [ value-name ] bi@ clock-name reset-name reg-always-block print

!     ! [ out-d>> first dup <reg> ]
!     ! [ in-d>> first defining-variable name>> ] 2bi
!     ! over name>> swap "%s <= %s" sprintf >>assignment
!     ! add-var
!     ;

<PRIVATE
: reg-push-node? ( node -- ? )
    out-d>> first actually-used-by first node>>
    [ local-writer-node? ] [ local-reader-node? ] bi or ;
PRIVATE>

M: #push node>verilog
    dup reg-push-node?
    [ drop ] [
        out-d>> dup literal>> literal>verilog set-var-name
    ] if ;

! Note that the assignment of the output is actually done by whatever produces
! the value, e.g. a call or a registered assignment
M: #return node>verilog
    in-d>> [ "output" var-definition print ] each
    end-module print ;


M: #declare node>verilog drop ;
M: #renaming node>verilog drop ;

! * Converting a Word or Quotation into Verilog code

! TODO: rename
: code>verilog ( word/quot -- )
    [
        node>verilog
    ] each-node-in-module ;
