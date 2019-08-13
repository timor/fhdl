USING: accessors assocs combinators.short-circuit compiler.tree fhdl.module
fhdl.tree.locals-propagation fhdl.verilog.syntax formatting io kernel locals
math.intervals math.parser sequences sets variables ;

IN: fhdl.verilog

FROM: fhdl.module => mod ;

! * Clocks and resets

! Per default, each module gets prefixed with a clock
! which is connected to all registers implicitly

GLOBAL: clock-name
GLOBAL: reset-name              ! unused
"clock" set: clock-name
"reset" set: reset-name

! * Verilog representations

<PRIVATE
: typed-decl ( var type -- str )
    [ [ name>> ] [ var-range ] bi ] dip var-decl ;

GENERIC: var-declaration ( variable -- str )
M: input var-declaration "input" typed-decl ;
M: wire var-declaration "wire" typed-decl ;
M: parameter var-declaration
    [ name>> ] [ literal>> literal>verilog ] bi parameter-definition ;
M: register var-declaration
    [ name>> ] [ setter-name>> ] [ var-range ] tri
    "reg" "wire" [ var-decl ] bi-curry@
     bi-curry bi*
    "\n" glue ;

: var-definition ( value type -- str )
    [ [ value-name ] [ value-range ] bi ] dip
    var-decl ;

: implicit-wire-definition ( var rhs -- str )
    [ [ var-range range-spec ] [ name>> ] bi ] dip
    "wire %s %s = %s;" sprintf ;

PRIVATE>

! * Verilog Code Generation from FHDL Module

! A module, which has been constructed by `build-fhdl-module` contains enough
! information to generate corresponding Verilog code.
! First, all declarations are generated.  Then the relevant nodes of the SSA
! Tree are traversed, and corresponding verilog code emitted.
! Before emitting the closing module statement, the clocked processes which
! generate the registers are emitted.

! ** Module Header and declarations

:: verilog-header. ( module -- )
    module [ name>> ] [ inputs>> ] [ outputs>> ] tri :> ( name ins outs )
    name ins outs append [ name>> ] map clock-name prefix begin-module print
    clock-name empty-interval "input" var-decl print
    ins [ var-declaration print ] each
    outs [ "output" typed-decl print ] each
    module module-registers [ var-declaration print ] each
    ! module variables>> values members
    ! [ { [ wire? ] [ name>> ] } 1&& ] filter [ var-declaration print ] each
    ;


! ** Verilog Code Generation from SSA Tree Node

! This is called for each node, and expected to print verilog code to stdout
GENERIC: node>verilog ( node -- )

! TODO: TEST
M: #call node>verilog
    [ word>> name>> ]
    [ identity-hashcode "inst_%d" sprintf ]
    [ in-d>> [ value-name ] map ", " join ] tri
    instance print
    ;

M: local-writer-node node>verilog
    [ node-local-box mod registers>> at setter-name>> ]
    [ in-d>> first value-name ] bi
    assign-net print ;

! FIXME: currently special-cased on number literals
M: #push node>verilog
    out-d>> first [ value-name ] [ get-var info>> literal>> ] bi
    number>string parameter-definition print ;

! ** Emitting the register logic processes

: reg-assignments. ( module -- )
    clock-name always-at-clock print
    registers>> values
    [
        [ name>> ] [ setter-name>> ] bi procedural-assignment
        "  " prepend
    ] map "\n" join
    wrap-begin-block print ;

! ** Converting the Module into Verilog Code
: module>verilog. ( module -- )
    dup verilog-header. nl
    dup nodes>> [ node>verilog ] each
    reg-assignments. nl
    end-module print ;

! * Converting a Word or Quotation into Verilog code

! Print a verilog implementation of the word or quotation to standard output.
: verilog. ( quot/word -- )
    fhdl-module module>verilog. ;
