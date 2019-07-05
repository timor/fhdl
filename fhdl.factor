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



M: reg-node node>verilog_old ( module node -- module )
    [ out-d>> first dup <reg> ]
    [ in-d>> first defining-variable name>> ] 2bi
    over name>> swap "%s <= %s" sprintf >>assignment
    add-var
    ;


! ** Verilog Code generation

<PRIVATE
: module-clocks ( module -- seq )
    variables>> values [ reg-var? ] filter [ clock>> ] map members ;

: module-clocks-decl ( module -- str )
    module-clocks [ "input %s;" sprintf ] map "\n" join ;


: verilog. ( quot/word -- )
    code>verilog ;

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
