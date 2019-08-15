USING: assocs combinators.smart fhdl.types fry hashtables.identity kernel
kernel.private locals math namespaces sequences ;

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

! * Sequential logic

! The basic sequential combinator is [1mealy], which takes an initial value in
! addition to a state and output transfer function (stf). There is a small
! sub-protocol operating on these stfs before they are given to the [1mealy]
! "constructor".  This allows things like adding enable signals or synchronous
! clears

! based on a state transition function and an initial state, generate a
! quotation that implements that recurrence relation.
! Implementation is based on lexical closure
:: [1mealy] ( stf: ( ..a state -- ..b new-state output ) initial --
              quot: ( -- out state ) )
    initial :> state! stf '[ state @ swap dup state! ] ;

! Add a load-enable to a state-transfer function when defining a mealy circuit.
! This results in the resulting quotation to expect a flag on top of stack
! whether to latch the new state or the old state.
:: with-load-enable ( stf: ( state -- new-state output ) --
                      stf': ( enable state -- new-state output ) )
    [| enabled state | state stf call :> ( new-state output )
     enabled { boolean } declare new-state state ? output ] ;

! pre-set an enable input with t
: always-enabled ( quot: ( ..a enable -- ..b ) -- quot: ( ..a -- ..b ) )
    t swap curry ;

! Add a synchronous clear input to ta state transfer function when defining a
! mealy circuit
:: with-sync-clear ( stf: ( state -- new-state output ) reset-val --
                     stf': ( clear state -- new-state output ) )
    [| clear? state | state stf call :> ( new-state output )
     clear? { boolean } declare reset-val new-state ? output ]
    ;

! drop the state from a mealy quotation
: without-state-output ( quot -- quot )
    [ drop ] compose ; inline

! This is the simplest primitive sequential quotation
: [reg] ( -- quot )
    [ ] 0 [1mealy] without-state-output ;

! Return a quotation which counts internally from 0 up to n each time it is
! called, and outputs the current counter value
:: [counter] ( n -- quot: ( -- x ) )
    [| s | s { natural } declare 1 + dup n > [ drop 0 ] when s ] 0 [1mealy] without-state-output ;

! * Accumulator definition ( example character )
: acc-stf ( reg-declaration -- stf )
    '[ _ declare [ + ] keep ] ;

: [acc] ( -- quot: ( x -- y ) )
    [ [ + ] keep ] 0 [1mealy] without-state-output ;

! With sync clear
: [acc-c] ( reg-declaration reset-val -- quot: ( x enable? -- y ) )
    [ acc-stf ] dip with-sync-clear 0 [1mealy] without-state-output ;

! With load enable
: [acc-e] ( reg-declaration -- quot: ( x enable? -- y ) )
    acc-stf with-load-enable 0 [1mealy] without-state-output ;

! * DSP Structures
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
