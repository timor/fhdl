USING: assocs combinators.smart fhdl fry hashtables.identity kernel locals math
namespaces sequences stack-checker.transforms words ;

IN: fhdl.combinators

! * Structure-defining Combinators

! These words are used at macro-expansion time to build up quotations from
! smaller primitive quotations.

! OBSOLETE At the moment, the only true primitive quotation is the [reg] word, which
! generates the functionality to store the current input and return a previous
! one.

! TODO: maybe initial value support


! * Primitive State Handling

! The primitive for synthesizing register logic is the mealy combinator, which
! takes a quotation ( input state -- output new-state ) as input, as
! well as an initial state, and returns a quotation ( input -- ouput ! state ).
! This combinator should suffice to compose all necessary structures
! involving feedback.

SYMBOL: state
state [ IH{  } clone ] initialize

<PRIVATE

: get-state ( key -- seq )
    state get at ;

: set-state ( seq key -- )
    state get set-at ;

: (reg) ( x i -- x ) state get 2dup at [ set-at ] dip [ 0 ] unless* ;
PRIVATE>

! based on a state transition function and an initial state, generate a
! quotation that implements that recurrence relation.
! Implementation is based on lexical closure
:: [1mealy] ( stf: ( state -- out new-state ) initial --
              quot: ( -- out state ) )
    initial :> state! stf '[ state @ dup state! ] ;

! : [reg] ( -- quot )
!     gensym [ (reg) ] curry ;

: [reg] ( -- quot )
    [ swap ] 0 [1mealy] [ drop ] compose ;

! This combinator takes a sequence of n quotations, and returns a quotation that
! generates a register chain with one input and n outputs, where the each output
! is passed through the respective quotation of the input sequence.
: [map-reg-chain] ( quots -- quot )
    [ [reg] '[ _ _ bi ] ] map concat ;

! Above combinator used to implement a simple delay line
: [delay-line] ( l -- quot )
    [ drop ] <repetition> [map-reg-chain] ;

! Create a quotation summing all outputs
: [sum-outputs] ( quot -- quot )
    dup outputs 1 - [ [ + ] append ] times ;

! Above combinator used to generate a quotation which realizes a FIR filter with
! constant coefficients, summing all outputs by simply applying successive adders.
: [fir] ( coeffs -- quot )
    [ '[ _ * ] ] map [map-reg-chain] [sum-outputs] ;
