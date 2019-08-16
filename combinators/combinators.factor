USING: accessors assocs combinators.smart fhdl.types fry hashtables.identity
kernel kernel.private locals math math.bitwise math.functions math.order
namespaces sequences ;

IN: fhdl.combinators

! * Structure-defining Combinators

! These words are used at macro-expansion time to build up quotations from
! smaller primitive quotations.


! * Sequential logic

! ** Moore FSM
! The most basic combinator is one which allocates a memory location
! (synthesized as register), and takes a quotation which computes the value which
! will be stored in that location on the next invocation (state transition
! function, /stf/) of the resulting
! quotation, with the current state on the top of the stack, and any inputs
! below.  Additionally, an initial value has to be supplied.

:: <1moore> ( stf: ( ..in state -- new-state ) initial --
              quot: ( ..in -- state ) )
    initial :> state!
    [ state [ stf call state! ] keep ] ;

! This is general enough to build any sequential element with state feedback,
! the simplest being a single register, initialized to 0.  The state transfer
! function consists of dropping the old state, and returning the top-most
! stack-element as the next-state.  The resulting signature:
! ( -- in ) + ( -- state ) + ( in state -- new-state ) + ( new-state -- state )
! = ( in -- state )
: [reg] ( -- quot )
    [ drop ] 0 <1moore> ;

! ** Compositional Combinators

! Since a module/block/synthesizable-unit-of-code is represented by a quotation,
! functionality can be added by using function composition.  In concatenative
! languages, functional composition amounts to simply concatenating quotations.
! To add functionality at the input, additional quotations can be preposed.  To
! add stuff at the output, quotations are appended.  This could be done using
! sequence operations, but Factor provides the words `prepose` and `compose` for
! the respective operations on quotations.

! *** Register chaining composition

! FIXME describe (n)map-reduce instead
! A recurring pattern in digital circuits is a chain of registers.  This
! combinator abstracts over this pattern by generating a register for each
! quotation in the provided sequence, connecting it to the next one and creating
! an output for each stage, where the provided quotation is applied

! Although in practice typed definitions should be used to set the input types
! of a module-describing quotation, the following combinator is useful during
! interactive development to prepose input type declarations:

: with-declared-inputs ( quot decl -- quot' )
    '[ _ declare ] prepose ;

! * Examples

! ** Register with clear and/or enable inputs

: [regE] ( -- quot: ( in enable -- state ) )
    [ swapd ? ] 0 <1moore> ;

! ** Fixed-width wraparound accumulator

! An accumulator has an adder in the feedback path.  This results in the
! accumulator being able to grow indefinitely.  Therefore, it needs to be
! constrained.  This is done using factor's `wrap` word, which is implemented
! with a bitmask internally.


:: [acc] ( limit -- quot: ( in -- acc ) )
    [ + limit mod ] 0 <1moore> ;

! ** Toggle Flipflop

! One could also use the `bitnot` operator to enforce creating an inverter
! instead of a mux.  For FPGAs, this could make a difference when some backend
! synthesizer can absorb inverters into adjacent elements.
: [tff] ( -- quot: ( -- out ) )
    [ not ] f <1moore> ;

! ** Counters

! This is simply an accumulator with a constant 1 input
: [counter] ( max -- quot )
    [acc] [ 1 ] prepose ;


! * Obsolete

! the basic sequential combinator is [1mealy], which takes an initial value in
! addition to a state and output transition function (stf). There is a
! small sub-protocol operating on the results of this combinator, which allows
! to modify stf and the output setting quotation,
! returning a new 1mealy quotation. This allows things
! like adding enable signals or synchronous clears.

! The fact that this is implemented with composed as super class is important.  Using compose
! preserves the structure of the underlying quotations, and allows access to
! parts of the quotations afterwards.  Thus, all quotations returned by [1mealy]
! can be used to derive new quotations.  This is used to define a small protocol
! which can be used to add things like load-enable, clear, or type declarations.

! Based on a state transition function, output transition function and an
! initial state, generate a quotation that implements that recurrence relation.
! Implementation is based on lexical closure

TUPLE: 1mealy < composed { state-getter read-only } { stf read-only } { output-quot read-only } ;

:: <1mealy> ( state-getter stf output-quot -- 1mealy )
    state-getter stf compose
    output-quot
    state-getter clone
    stf clone
    output-quot clone
    1mealy boa ;

:: [1mealy] ( stf: ( ..a state -- ..b output new-state ) initial -- quot: ( -- out state ) )
    initial :> state!
    [ state ] stf [ state! ] <1mealy> ;

! Take a 1mealy and a quotation which modifies the state transition function,
! return a new 1mealy.  Note that the resulting 1mealy shares state storage with
! the original one, so it can not be used as a "template" mechanism.
: change-stf ( 1mealy quot: ( stf: ( ..in state -- ..out new-state ) -- stf' ) -- 1mealy' )
    [ [ state-getter>> ] [ output-quot>> ] [ stf>> ] tri ] dip
    call( stf -- stf' ) swap <1mealy> ;

: change-output-quot ( 1mealy quot: ( output-quot: ( ..a new-state -- ..b ) --
                                      output-quot' ) -- 1mealy' )
    [ [ state-getter>> ] [ stf>> ] [ output-quot>> ] tri ] dip
    call( oset -- oset' ) <1mealy> ;

! Add an a state output to a 1mealy quotation
: with-state-output ( 1mealy: ( ..in -- ..out state ) --
                         1mealy': ( ..in -- ..out ) )
    dup state-getter>>
    '[ [ _ dip ] prepose ] change-output-quot ;

! Add a load-enable to a 1mealy function when defining a mealy circuit. This
! results in the resulting quotation to expect an additional flag below the
! inputs, i.e. what is left after calling the stf, whether to latch the new
! state or the old state. It is implemented by bypassing the TOS element around
! the set, making the state-setter conditional on this.

! TODO See whether it would ! make more sense to expect this below the inputs instead
: with-load-enable ( 1mealy: ( ..in -- out.. state ) --
                      1mealy': ( ..in enable -- out.. state ) )
    ! [| stf | [| enabled state | state stf call :> ( out new-state ) out enabled
    !           new-state state ? ] ]
    [ '[ swap _ dip ] ] change-stf
    [ '[ _ [ drop ] if ] ] change-output-quot
    ;

! Add a synchronous clear input to ta state transfer function when defining a
! mealy circuit
:: with-sync-clear ( 1mealy: ( ..in -- out.. state ) reset-val --
                    1mealy': ( ..in enable -- out.. state ) )
    1mealy [| stf | [| clear? state | state stf call :> ( output new-state )
     output clear? reset-val new-state ? ] ] change-stf
    ;

! Add a list of declarations to the front of the stf, excluding the state-input
! on tos
! : with-declared-inputs ( 1mealy seq -- 1mealy )
!     '[ [ [ _ declare ] dip ] prepose ]
!     change-stf ;

! pre-set an enable input with t, does not keep 1mealy composability!
: always-enabled ( quot: ( ..a enable -- ..b ) -- quot: ( ..a -- ..b ) )
    t swap curry ;

! This is the simplest primitive sequential quotation
! : [reg] ( -- quot )
!     [ swap ] 0 [1mealy] ;

! Return a quotation which counts internally from 0 up to n each time it is
! called, and outputs the current counter value
! :: [counter] ( n -- quot: ( -- x ) )
!     [| s | s { natural } declare 1 + dup n > [ drop 0 ] when s swap ] 0 [1mealy] ;

! * Accumulator definition ( example character )
! The following functions define some example accumulators.  Note that these
! will not be synthesizable if the output of the state-transition function is
! not constrained.

: acc-stf ( -- stf )
    [ [ + ] keep swap ] ;

! Define an accumulator with a certain bit width
! :: [acc] ( width -- quot: ( x -- y ) )
!     2 width ^ :> n
!      acc-stf 0 [1mealy] [ [ n wrap ] compose ] change-stf ;

! With sync clear
: [acc-c] ( width -- quot: ( x clear? -- y ) )
    [acc] 0 with-sync-clear ;

! With load enable
: [acc-e] ( width -- quot: ( x enable? -- y ) )
    [acc] with-load-enable ;

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

! Synthesize the feedback part of a DF1 filter structure

! This is based on a single block which can be composed into a parallel feedback
! structure
: [ar1] ( a -- quot: ( x -- x' y ) )
    '[ + _ * dup ] 0 [1mealy] ;
