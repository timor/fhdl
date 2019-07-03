! Copyright (C) 2019 martinb.
! See http://factorcode.org/license.txt for BSD license.
USING: accessors arrays assocs compiler.tree compiler.tree.builder
compiler.tree.propagation.info effects fhdl.tree formatting fry
hashtables.identity kernel macros math math.parser namespaces prettyprint
sequences typed words ;
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

! TODO: use reg as a macro/call inside the combinators to generate an actual
! state-holding node
: reg ( x i -- x ) state get 2dup at [ set-at ] dip [ 0 ] unless* ;

: [reg] ( -- quot )
    gensym [ reg ] curry ;

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

TYPED: fir8 ( x: uint8 -- y: uint8 )
    { 10 20 -20 10 } fir ;

: example ( -- )
    { 1 -2 3 -4 } [fir] tree. ;

! * Generating Verilog output

PREDICATE: reg-node < #call  word>> \ reg = ;

! HACK the value info to copy the input info
\ reg [ drop clone ] "outputs" set-word-prop

! This is inspired by the way confluence generates code.  An analyzed quotation
! is turned into a module.
GENERIC: node-inputs-info. ( node -- )

UNION: using-node #call #return ;

M: object node-inputs-info. drop ;
M: using-node node-inputs-info. node-input-infos . ;
M: reg-node node-inputs-info.
    node-input-infos but-last . ;

! Helper: print node info
: nodes-info. ( word/quot -- )
    build-tree
    [ dup . node-inputs-info. ]
    each-node-with-def-use-info ;

! typed effect elements are tuples, we only want the name
: effect-elt-name ( elt -- str )
    dup array? [ first ] when ;

! generate list of names that identify verilog module inputs and output
: word>inputs/outputs ( word -- in-seq out-seq )
    stack-effect
    [ in>> [ [ effect-elt-name "_in" append ] dip number>string append ] map-index ]
    [ out>> [ [ effect-elt-name "_out" append ] dip number>string append ] map-index ] bi ;

: word>inputs ( word -- seq )
    word>inputs/outputs drop ;

: word>outputs ( word -- seq )
    word>inputs/outputs nip ;

: word>module-header ( word -- str )
    [ name>> ] [ word>inputs/outputs ] bi
    append ", " join
    "module %s(%s)" sprintf ;

! SYMBOLS: value-var-mappings ;
TUPLE: verilog-var
    name
    { width initial: 0 }
    ;
: new-var ( name class -- var )
    new swap >>name ;

TUPLE: input-var < verilog-var ;
: <input> ( name -- var )
    input-var new-var ;

TUPLE: output-var < verilog-var ;
: <output> ( name -- var )
    output-var new-var ;

TUPLE: wire-var < verilog-var assignment ;
: <wire> ( value -- var )
    number>string "w_" prepend wire-var new-var ;

TUPLE: reg-var < wire-var { clock initial: "clock" } ;
: <reg> ( value -- var )
    number>string "r_" prepend reg-var new-var ;

TUPLE: module name inputs outputs variables ;

<PRIVATE
! : initialize-vars ( module -- module )
!     [ variables>> ] [ inputs ] bi

PRIVATE>

: <module> ( word -- obj )
    [ name>> ] [ word>inputs/outputs ] bi H{ } clone module boa ;

! map values to verilog variables
! : value>var ( value -- str )
!     dup value-var-mappings get at [ nip ] [ number>string "v_" prepend ] if* ;

! call quot in the context where def-uses and variable mappings are known
! output header and parens;

: add-var ( module value var -- module )
    swap pick variables>> set-at ;

! Main generation hook: each node is supposed to modify the variables slot of
! the module
GENERIC: node>verilog ( module node -- module )
M: node node>verilog drop ;

M: #introduce node>verilog
    out-d>> over inputs>>
    [ <input> add-var ] 2each ;

M: #return node>verilog
    in-d>> over outputs>>
    [ <output> add-var ] 2each ;

M: reg-node node>verilog
    [ out-d>> first <reg> ]
    [
        in-d>> first over variables>> at name>>
        over name>> swap "%s <= %s;" sprintf >>assignment
    ]
    [  ] tri add-var
    ;


! Call quot for each node, which is expected to return a sequence of verilog variables
: make-module ( word -- module )
    [ <module> ] keep
    build-tree
    [
        node>verilog
    ] each-node-with-def-use-info
    ;

! :: with-verilog-module ( tree quot -- )
!     tree unclip :> ( rest intro )
!     into
