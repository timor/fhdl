! Copyright (C) 2019 martinb.
! See http://factorcode.org/license.txt for BSD license.
USING: accessors arrays assocs combinators compiler.tree
compiler.tree.combinators compiler.tree.propagation.copy
compiler.tree.propagation.info definitions effects fhdl.tree formatting fry
hashtables.identity io kernel kernel.private linked-assocs locals macros math
math.intervals math.parser math.partial-dispatch math.private namespaces
quotations sequences sequences.zipped sets stack-checker typed words ;
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

! TODO: maybe put into extra vocab instead of parse-time
<<
: [reg] ( -- quot )
    gensym [ reg ] curry ;
>>

MACRO: >reg ( -- quot )
    [reg] ;

! generate a register chain with parallel outputs, input is a sequence of
! quotations which are applied to each output value

<<
: [map-reg-chain] ( quots -- quot )
    [ [reg] '[ _ _ bi ] ] map concat ;

: [delay-line] ( l -- quot )
    [ drop ] <repetition> [map-reg-chain] ;

>>
! This would be used if we wanted to perform the computation immediately
MACRO: delay-line ( l -- quot )
    [delay-line] ;

<<
: [fir] ( coeffs -- quot )
    [ [ [ * ] curry ] map [map-reg-chain] ]
    [ length [ + ] <repetition> concat ] bi compose
    ;
>>

MACRO: fir ( coeffs -- quot )
    [fir] ;

TYPED: fir8 ( x: uint8 -- y )
    { 1 2 -2 1 } fir ;

! * Generating Verilog output

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
    number>string "value_" prepend wire-var new-var ;

TUPLE: reg-var < wire-var { clock initial: "clock" } ;
: <reg> ( value -- var )
    number>string "reg_" prepend reg-var new-var ;

TUPLE: parameter < verilog-var literal ;
: <parameter> ( value -- var )
    number>string "literal_" prepend parameter new-var ;
M: parameter name>> literal>> number>string ;

! *** Instances
TUPLE: instance mod-name inputs outputs ;

: instance-name ( instance -- str )
    identity-hashcode number>string "inst_" prepend ;

: <instance> ( mod-name inputs outputs -- obj )
    pick instance-name '[ [ _ "_%s_out" sprintf append ] change-name ] map
    instance boa ;

! ** Hardware Module

! A synthesizable quotation is turned into a module object, from which target
! HDL can be generated.

! This is inspired by the way confluence generates code.  An analyzed quotation
! is turned into a module.


! TODO: maybe remove tree and definition if only used for debugging
TUPLE: module name inputs outputs variables instances definition tree ;

: <module> ( name definition -- x )
    module new swap >>definition
    swap >>name
    LH{ } clone >>variables
    V{ } clone >>instances
    ;

<PRIVATE
! depends on stack-checker scope!
: value-width ( value -- width )
    value-info interval>> interval-length log2 1 + ;
PRIVATE>

GENERIC: add-var ( module value var -- module )

M: verilog-var add-var
    over value-width >>width
    swap pick variables>> set-at ;

M: parameter add-var
    swap pick variables>> set-at ;

: get-var ( module value -- var )
    swap variables>> at
    ;


! Main generation hook: each node is supposed to modify the variables slot of
! the module
GENERIC: node>verilog ( module node -- module )

! TODO: remove to ensure exhaustiveness
M: node node>verilog drop ;

M: #introduce node>verilog
    out-d>> over inputs>>
    [ <input> add-var ] 2each ;

M: #push node>verilog
    [ out-d>> first dup <parameter> ] [ literal>> >>literal ] bi add-var
    ;

<PRIVATE
: defining-variable ( module value -- var )
    resolve-copy ! should not have any influence
    get-var ;
PRIVATE>

M: reg-node node>verilog ( module node -- module )
    [ out-d>> first dup <reg> ]
    [ in-d>> first defining-variable name>> ] 2bi
    over name>> swap "%s <= %s" sprintf >>assignment
    add-var
    ;

! All non-primitive calls would be translated into module instantiations
M:: #call node>verilog ( module node -- module )
    node [ word>> name>> ]
    [ in-d>> [ module swap get-var ] map ]
    [ out-d>> module swap [ dup <wire> [ add-var ] keep ] map ] tri nip
   <instance> module instances>> push
    module
    ;

CONSTANT: add-op-words { fixnum+ +-integer-integer +-fixnum-integer }
CONSTANT: mul-op-words { fixnum* }
PREDICATE: add-call < #call word>> add-op-words member? ;
PREDICATE: mul-call < #call word>> mul-op-words member? ;

: verilog-assign ( lhs rhs -- str )
    "assign %s = %s;" sprintf ;

! for rename nodes, we copy the verilog variable associations from the inputs to
! the outputs
M: #renaming node>verilog
    dupd
    [ variables>> ] [ inputs/outputs ] bi* swap
    <zipped> [ pick at ] assoc-map assoc-union! drop ;

M:: add-call node>verilog ( module node -- node )
    node out-d>> first dup <wire> :> ( value var )
    module node in-d>> [ defining-variable name>> ] with map :> inputs
    var name>> inputs first2 "%s + %s" sprintf verilog-assign var assignment<<
    module value var add-var ;

! TODO: generalize to binary operators
M:: mul-call node>verilog ( module node -- node )
    node out-d>> first dup <wire> :> ( value var )
    module node in-d>> [ defining-variable name>> ] with map :> inputs
    var name>> inputs first2 "%s * %s" sprintf verilog-assign var assignment<<
    module value var add-var ;

! convert the module's output sequence into an assoc with the definitions
M: #return node>verilog
    dupd in-d>> [ get-var ] with map
    '[ _ zip ] change-outputs ;

<PRIVATE

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

! Initialize a module struct from a quotation or word
PRIVATE>


! Call quot for each node, which is expected to return a sequence of verilog variables
:: build-module ( code -- module )
    code [ module-name ] [ module-def ] bi <module> :> mod
    code word>inputs/outputs [ mod inputs<< ] [ mod outputs<< ] bi*
    mod dup definition>>
    [
        build-fhdl-tree
        [ >>tree ] keep
        [
            node>verilog
        ] each-node
    ] with-scope
    ;

! ** Verilog Code generation

<PRIVATE
: module-clocks ( module -- seq )
    variables>> values [ reg-var? ] filter [ clock>> ] map members ;

: module-clocks-decl ( module -- str )
    module-clocks [ "input %s;" sprintf ] map "\n" join ;

: module-begin ( module -- str )
    [ [ name>> ] keep module-clocks ] [ inputs>> ] [ outputs>> keys ] tri
    append append ", " join
    "module %s(%s);" sprintf ;

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
M: parameter var-decl drop "" ;

GENERIC: var-def ( var -- str )
M: input-var var-def drop "" ;
M: wire-var var-def assignment>> ;
M: reg-var var-def
    [ clock>> ] [ assignment>> ] bi
    "always @(posedge %s)\n  %s;" sprintf
    ;
M: parameter var-def drop "" ;

! *** Printing Instances
: instance-outputs-decls ( instance -- str )
    outputs>> [ var-decl ] map "\n" join ;

:: instance-definition ( instance -- str )
    instance
    [ instance-name ]
    [ mod-name>> ]
    [ [ inputs>> ] [ outputs>> ] bi append sift [ name>> ] map ", " join ] tri
    "%s %s(%s);" sprintf ;
PRIVATE>

: print-verilog ( module -- )
    {
        [ module-begin print ]
        [ module-clocks-decl print ]
        [ outputs-declarations print ]
        [ instances>> [ instance-outputs-decls print ] each ]
        [ variables>> >alist values members
          [ [ var-decl print ] each ] [ [ var-def print ] each ] bi ]
        [ instances>> [ instance-definition print ] each ]
        [ outputs-assignments print ]
    } cleave
    "endmodule" print ;

: verilog. ( quot/word -- )
    build-module print-verilog ;

! ** Examples
: ex-fir-tree ( -- )
    { 1 -2 3 -4 } [fir] tree. ;

: ex-fir-typed ( -- )
    { 1 -2 3 -4 } [fir] [ { uint8 } declare ] prepend tree. ;

: test-registered-adder ( a b -- c )
    { fixnum fixnum } declare
    + >reg ;

: ex-adder ( -- )
   \ test-registered-adder build-module print-verilog ;

: test-anon-adder ( -- quot )
    [ { uint8 uint8 } declare + ] ;

: ex-anon-module ( -- module )
    test-anon-adder build-module ;

: ex-anon ( -- )
    test-anon-adder verilog. ;
