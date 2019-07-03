! Copyright (C) 2019 martinb.
! See http://factorcode.org/license.txt for BSD license.
USING: arrays assocs fhdl.tree hashtables.identity kernel macros math namespaces
sequences ;
IN: fhdl


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

: example ( -- )
    { 1 -2 3 -4 } [fir] tree. ;

