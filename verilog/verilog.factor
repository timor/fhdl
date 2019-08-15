USING: accessors arrays assocs combinators compiler.tree fhdl.module
fhdl.tree.locals-propagation fhdl.verilog.syntax formatting io kernel locals
math.intervals sequences variables ;

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
M: register var-declaration
    [ name>> ] [ setter-name>> ] [ var-range ] tri
    "reg" "wire" [ var-decl ] bi-curry@
     bi-curry bi*
    "\n" glue ;

: var-definition ( value type -- str )
    [ [ value-name ] [ value-range ] bi ] dip
    var-decl ;

! If a variable is used as output, a corresponding output var decl needs to
! be generated.  The setter for this is emitted from the #return node.
: named-output-declaration ( name var -- str )
    var-range "output" var-decl ;

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

: verilog-header ( module -- str )
    [ name>> ] [ input-names ] [ output-names ] tri
    append clock-name prefix begin-module ;

: locals-declarations ( module -- seq )
    {
        [ inputs>> [ var-declaration ] map ]
        [ [ output-names ] [ outputs>> ] bi [ named-output-declaration ] 2map ]
        [ module-registers [ var-declaration ] map ]
        [ module-locals [ "wire" typed-decl ] map ]
    } cleave 4array concat ;

: verilog-preamble. ( module -- )
    dup verilog-header print
    clock-name full-interval "input" var-decl print
    locals-declarations [ print ] each
    ;


! ** Verilog Code Generation from SSA Tree Nodes

! This is called for each node, and expected to print verilog code to stdout
GENERIC: node>verilog ( node -- )

! TODO: TEST
M: #call node>verilog
    [ word>> name>> ]
    [ identity-hashcode "inst_%d" sprintf ]
    [ [ in-d>> ] [ out-d>> ] bi append [ value-name ] map ] tri
    instance print
    ;

M: local-writer-node node>verilog
    [ node-local-box mod registers>> at setter-name>> ]
    [ in-d>> first value-name ] bi
    assign-net print ;

M: #push node>verilog
    out-d>> first [ value-name ] [ get-var info>> literal>> ] bi
    literal>verilog assign-net print ;

M: #return node>verilog
    in-d>>
    mod output-names swap
    [ get-var name>> assign-net print ] 2each ;

M: #phi node>verilog
    [let
     [ phi-in-d>> ] [ out-d>> ] [ get-condition ] tri :> ( ins outs cond )
     outs ins first2
     [
         [ get-var name>> ] tri@ [ cond name>> ] 2dip conditional-expr
         assign-net print
     ] 3each
    ] ;

! ** Emitting the register logic processes

: reg-assignments. ( module -- )
    module-registers dup empty?
    [ drop ]
    [
        clock-name always-at-clock print
        [
            [ name>> ] [ setter-name>> ] bi procedural-assignment
            "  " prepend
        ] map "\n" join
        wrap-begin-block print
    ] if ;

! ** Converting the Module into Verilog Code
: module>verilog. ( module -- )
    [ mod
      dup verilog-preamble. nl
      dup nodes>> [ node>verilog ] each
      reg-assignments. nl
      end-module print ] with-fhdl-module
    ;

! * Converting a Word or Quotation into Verilog code

! Print a verilog implementation of the word or quotation to standard output.
: verilog. ( quot/word -- )
    fhdl-module module>verilog. ;
