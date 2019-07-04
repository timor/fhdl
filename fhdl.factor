! Copyright (C) 2019 martinb.
! See http://factorcode.org/license.txt for BSD license.
USING: accessors arrays assocs combinators compiler.tree compiler.tree.builder
compiler.tree.propagation.copy compiler.tree.propagation.info effects fhdl.tree
formatting fry hashtables.identity io kernel kernel.private linked-assocs locals
macros math math.intervals math.parser math.private namespaces quotations
sequences sets stack-checker typed words ;
IN: fhdl

! Data Types which are supposed to be synthesizable
PREDICATE: uint8 < fixnum [ 0 >= ] [ 256 < ] bi and ;

SYMBOL: state
state [ IH{  } clone ] initialize

<PRIVATE

: get-state ( key -- seq )
    state get at ;

: set-state ( seq key -- )
    state get set-at ;

PRIVATE>

: reg ( x i -- x ) state get 2dup at [ set-at ] dip [ 0 ] unless* ;

: [reg] ( -- quot )
    gensym [ reg ] curry ;

MACRO: >reg ( -- quot )
    [reg] ;

! generate a register chain with parallel outputs, input is a sequence of
! quotations which are applied to each output value

: [map-reg-chain] ( quots -- quot )
    [ [reg] '[ _ _ bi ] ] map concat ;

: [delay-line] ( l -- quot )
    [ drop ] <repetition> [map-reg-chain] ;

! This would be used if we wanted to perform the computation immediately
MACRO: delay-line ( l -- quot )
    [delay-line] ;

: [fir] ( coeffs -- quot )
    [ [ [ * ] curry ] map [map-reg-chain] ]
    [ length [ + ] <repetition> concat ] bi compose
    ;

MACRO: fir ( coeffs -- quot )
    [fir] ;

TYPED: fir8 ( x: uint8 -- y )
    { 1 2 -2 1 } fir ;

! * Generating Verilog output

! This is inspired by the way confluence generates code.  An analyzed quotation
! is turned into a module.

PREDICATE: reg-node < #call  word>> \ reg = ;

! HACK the value info to copy the input info, this ensures correct value type propagation
\ reg [ drop clone ] "outputs" set-word-prop

! typed effect elements are tuples, we only want the name
: effect-elt-name ( elt -- str )
    dup array? [ first ] when ;

! generate list of names that identify verilog module inputs and output
: effect>inputs/outputs ( effect -- in-seq out-seq )
    [ in>> [ [ effect-elt-name "_in" append ] dip number>string append ] map-index ]
    [ out>> [ [ effect-elt-name "_out" append ] dip number>string append ] map-index ] bi
    ;

GENERIC: word>inputs/outputs ( word -- in-seq out-seq )
M: callable word>inputs/outputs
    infer effect>inputs/outputs ;

M: word word>inputs/outputs
    stack-effect
    effect>inputs/outputs ;

! SYMBOLS: value-var-mappings ;
TUPLE: verilog-var
    name
    width
    ;
: new-var ( name class -- var )
    new swap >>name ;

TUPLE: input-var < verilog-var ;
: <input> ( name -- var )
    input-var new-var ;

TUPLE: wire-var < verilog-var assignment ;
: <wire> ( value -- var )
    number>string "w_" prepend wire-var new-var ;

TUPLE: reg-var < wire-var { clock initial: "clock" } ;
: <reg> ( value -- var )
    number>string "r_" prepend reg-var new-var ;

TUPLE: parameter < verilog-var value ;
: <parameter> ( value -- var )
    number>string "p_" prepend parameter new-var ;

! ** Verilog module

TUPLE: module name inputs outputs variables ;

GENERIC: quot>module ( word -- obj )

: <module> ( name inputs outputs -- x )
    LH{ } clone module boa ;

M: word quot>module
    [ name>> ] [ word>inputs/outputs ] bi <module> ;
M: typed-word quot>module
    "typed-word" word-prop quot>module ;
M: callable quot>module
    "anon" swap word>inputs/outputs <module> ;

<PRIVATE
! depends on stack-checker scope!
: value-width ( value -- width )
    value-info interval>> interval-length log2 1 + ;
PRIVATE>

: add-var ( module value var -- module )
    over value-width >>width
    swap pick variables>> set-at ;

: get-var ( module value -- var )
    swap variables>> [ <wire> ] cache ;

! Main generation hook: each node is supposed to modify the variables slot of
! the module
GENERIC: node>verilog ( module node -- module )

! TODO: remove to ensure exhaustiveness
M: node node>verilog drop ;

M: #introduce node>verilog
    out-d>> over inputs>>
    [ <input> add-var ] 2each ;

<PRIVATE
: defining-variable ( module value -- var )
    resolve-copy get-var ;
PRIVATE>

M: reg-node node>verilog ( module node -- module )
    [ out-d>> first dup <reg> ]
    [ in-d>> first defining-variable name>> ] 2bi
    over name>> swap "%s <= %s" sprintf >>assignment
    add-var
    ;

! All non-primitive calls would be translated into module instantiations
M: #call node>verilog
    word>> name>> "Skipping #call to '%s'!\n" printf
    ;

PREDICATE: add-call < #call word>> \ fixnum+ = ;

: verilog-assign ( lhs rhs -- str )
    "assign %s = %s;" sprintf ;

M:: add-call node>verilog ( module node -- node )
    node out-d>> first dup <wire> :> ( value var )
    module node in-d>> [ defining-variable name>> ] with map :> inputs
    var name>> inputs first2 "%s + %s" sprintf verilog-assign var assignment<<
    module value var add-var ;

! convert the module's output sequence into an assoc with the definitions
M: #return node>verilog
    dupd in-d>> [ get-var ] with map
    '[ _ zip ] change-outputs ;

! Call quot for each node, which is expected to return a sequence of verilog variables
: make-module ( word -- module )
    [ quot>module ] keep
    build-tree
    [
        node>verilog
    ] each-node-with-def-use-info
    ;

! ** Code generation

<PRIVATE
: module-clocks ( module -- seq )
    variables>> values [ reg-var? ] filter [ clock>> ] map members ;

: module-clocks-decl ( module -- str )
    module-clocks [ "input %s;" sprintf ] map "\n" join ;

: module-begin ( module -- str )
    [ [ name>> ] keep module-clocks ] [ inputs>> ] [ outputs>> keys ] tri
    append append ", " join
    "module %s(%s)" sprintf ;

: var-range ( var -- str )
    width>> 1 - "[%s:0]" sprintf ;

: outputs-declarations ( module -- str )
    outputs>> [ var-range swap "output %s %s;" sprintf ] { } assoc>map
    "\n" join ;

: outputs-assignments ( module -- str )
    outputs>> [ name>> verilog-assign ] { } assoc>map "\n" join ;

! TODO: rename slot assignment -> expression, adjust string interpolations
GENERIC: var-decl ( var -- str )
: range-decl ( var type -- str )
    swap [ var-range ] [ name>> ] bi "%s %s %s;" sprintf ;

M: input-var var-decl "input" range-decl ;
M: wire-var var-decl "wire" range-decl ;
M: reg-var var-decl "reg" range-decl ;

GENERIC: var-def ( var -- str )
M: input-var var-def drop "" ;
M: wire-var var-def assignment>> ;
M: reg-var var-def
    [ clock>> ] [ assignment>> ] bi
    "always @(posedge %s)\n  %s" sprintf
    ;
PRIVATE>


: print-verilog ( module -- )
    {
        [ module-begin print ]
        [ module-clocks-decl print ]
        [ outputs-declarations print ]
        [ variables>> >alist values
          [ [ var-decl print ] each ] [ [ var-def print ] each ] bi ]
        [ outputs-assignments print ]
    } cleave
    "endmodule" print ;


! ** Examples
: ex-fir ( -- )
    { 1 -2 3 -4 } [fir] tree. ;

: test-registered-adder ( a b -- c )
    { fixnum fixnum } declare
    + >reg ;

: ex-adder ( -- )
   \ test-registered-adder make-module print-verilog ;
