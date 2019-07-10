USING: assocs fry hashtables.identity kernel math namespaces sequences words ;

IN: fhdl.combinators

! * Structure-defining Combinators

! These words are used at macro-expansion time to build up quotations from
! smaller primitive quotations.

! At the moment, the only true primitive quotation is the [reg] word, which
! generates the functionality to store the current input and return a previous
! one.

! TODO: maybe initial value support


SYMBOL: state
state [ IH{  } clone ] initialize

<PRIVATE

: get-state ( key -- seq )
    state get at ;

: set-state ( seq key -- )
    state get set-at ;

: reg ( x i -- x ) state get 2dup at [ set-at ] dip [ 0 ] unless* ;
PRIVATE>

: [reg] ( -- quot )
    gensym [ reg ] curry ;

! This combinator takes a sequence of n quotations, and returns a quotation that
! generates a register chain with one input and n outputs, where the each output
! is passed through the respective quotation of the input sequence.
: [map-reg-chain] ( quots -- quot )
    [ [reg] '[ _ _ bi ] ] map concat ;

! Above combinator used to implement a simple delay line
: [delay-line] ( l -- quot )
    [ drop ] <repetition> [map-reg-chain] ;


! Above combinator used to generate a quotation which realizes a FIR filter with
! constant coefficients, summing all outputs by simply applying successive adders.
: [fir] ( coeffs -- quot )
    [ [ [ * ] curry ] map [map-reg-chain] ]
    [ length [ + ] <repetition> concat ] bi compose
    ;
