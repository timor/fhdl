USING: accessors assocs compiler.tree compiler.tree.def-use.simplified
fhdl.module fhdl.tree.locals-propagation fhdl.verilog.syntax formatting io
kernel math.intervals sequences sets variables ;

IN: fhdl.verilog

FROM: fhdl.module => mod ;

! * Clocks and resets

! Per default, each module gets prefixed with a clock and an async reset value implicitly,
! which is connected to all registers implicitly
VAR: visited-regs

GLOBAL: clock-name
GLOBAL: reset-name
"clock" set: clock-name
"reset" set: reset-name

! * Verilog representations

<PRIVATE

! FIXME: rename to var-declaration
: var-definition ( value type -- str )
    [ [ value-name ] [ value-range ] bi ] dip
    var-decl ;

! FIXME: wire-definition
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

! local writer nodes don't have 1-to-1 equivalent verilog statements.
! Assignment is done producer nodes, not consumer nodes.  Thus, these are used
! to generate the code which actually sets the variable.  Since there can be
! more than one local writer node for one local variable, we must make sure that
! the code is generated only once.
M: local-writer-node node>verilog
    node-local-box mod registers>> at
    dup visited-regs member?
    [ drop ]
    [
        dup visited-regs adjoin
        [ writer-name>> ] [ reader-name>> ] bi clock-name reset-name
        reg-always-block print
    ] if ;

! local reader nodes are producer nodes, so they need to assign their results
M: local-reader-node node>verilog
    [ out-d>> first value-name ]
    [ node-local-box mod registers>> at reader-name>> ] bi
    assign-net print ;

! FIXME: this should be handled on module level, not verilog code generation
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
    V{ } clone set: visited-regs
    [
        node>verilog
    ] each-node-in-module ;
