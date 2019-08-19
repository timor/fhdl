USING: combinators.smart fhdl fhdl.functions fhdl.types fry kernel
kernel.private locals math math.functions sequences ;

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

! (Technically this is probably a Medvedev machine)

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

! In the simplest case, calling [ ... ] [ ] <1mealy> will simply copy the inputs
! below the state output

! ** Compositional Combinators

! Since a module/block/synthesizable-unit-of-code is represented by a quotation,
! functionality can be added by using function composition.  In concatenative
! languages, functional composition amounts to simply concatenating quotations.
! To add functionality at the input, additional quotations can be preposed.  To
! add stuff at the output, quotations are appended.  This could be done using
! sequence operations, but Factor provides the words `prepose` and `compose` for
! the respective operations on quotations.

! *** Input transformation

! Add another input (will become the first input, e.g. top of stack element)
! which conditionally loads the new-state (tos-1) or the input value (tos-2) in
! a quotation which is passed to the `<1moore>` combintator.
:: with-load-enable ( stf -- stf' )
    [| enable? state | state stf call :> new-state enable? new-state state ? ]
    ;

! Add another input, like above, which when set will result in loading the
! reset-value instead of calculating the output
:: with-sync-clear ( stf reset-val -- stf' )
    [| clear? state | state stf call :> new-state clear? reset-val new-state ? ]
    ! '[ swap @ swap _ swap ? ]
    ;


! *** Chaining composition

! This combinator bypasses the inputs to quotation as additional outputs on top
! of the stack
: keeping-inputs ( quot -- quot )
    '[ _ keep-inputs ] ;

! Take a combinator that returns a quotation when called and chain the result n
! times.
:: compose-times ( quot n quot-generator -- quot )
    quot n [ quot-generator call( ... -- ... quot ) compose ] times ;

! *** Type declarations

! Although in practice typed definitions should be used to set the input types
! of a module-describing quotation, the following combinator is useful during
! interactive development to prepose input type declarations:

: with-declared-inputs ( quot decl -- quot' )
    '[ _ declare ] prepose ;

! *** Output transformation
! Another combinator can be used to connect single bits resulting from a
! quotation into a resulting integer variable

: outputs>integer ( quot -- quot )
    [ >bit ] compose
    dup outputs 1 - [ [ [ >bit ] dip lsb-concat ] ] compose-times
    ;

! A well-known pattern in functional programming is the reduce operation.
! Interpreting the outputs of a quotation as a series of values, the reduce
! operations amounts to creating a structure which combines successive output
! values, forming a single output.

:: with-reduced-outputs ( quot reducer -- quot )
    quot dup outputs 1 - [ reducer ] compose-times ;

: summing-outputs ( quot -- quot )
    [ + ] with-reduced-outputs ;
    ! dup outputs 1 - [ [ + ] ] compose-times ;

! * Examples

! ** Register with clear and/or enable inputs

! An enable input is simply used to decide between old state and new state.
: [regE] ( -- quot: ( enable in -- state ) )
    [ swapd ? ] 0 <1moore> ;

! Note that the above could also be implemented with the previously defined
! with-load-enable combinator

: [regE]' ( -- quot ) [ drop ] with-load-enable 0 <1moore> ;

! ** Register chains (delay lines)
: [delay-line] ( n -- quot: ( in -- out ) )
    [ ] swap [ [reg] ] compose-times ;

! ** Fixed-width wraparound accumulator

! An accumulator has an adder in the feedback path.  This results in the
! accumulator being able to grow indefinitely.  Therefore, it needs to be
! constrained.  This is done using factor's `wrap` word, which is implemented
! with a bitmask internally.


:: [acc] ( limit -- quot: ( in -- acc ) )
    [ + limit wrap-counter ] 0 <1moore> ;

! Can also be defined with clear input:
:: [acc-c] ( limit -- quot: ( in -- acc ) )
    [ + limit wrap-counter ] 0 with-sync-clear 0 <1moore> ;

! ** Toggle Flipflop

! One could also use the `bitnot` operator to enforce creating an inverter
! instead of a mux.  For FPGAs, this could make a difference when some backend
! synthesizer can absorb inverters into adjacent elements.
: [tff] ( -- quot: ( -- out ) )
    [ not ] f <1moore> ;

! With clock enable
! The state transition function looks in this case has the following signature:
! ( enable state -- new-state )
: [tffE] ( -- quot: ( enable -- out ) )
    [ swap [ not ] when ] f <1moore> ;

! ** Counters

! This is simply an accumulator with a constant 1 input
: [counter] ( max -- quot )
    [acc] [ 1 ] prepose ;

! A different way is to cascade toggle flipflops into counters.  This makes use
! of structural composition of the [tffE] quotations, which have the following
! signature:
! ( enable -- out )

! To make a counter, the clock-enable must be bit-and'ed with the preceding stage
! The "glue" quotation has signature ( d ce -- d ce' ).  After the last stage,
! the bypassed clock-enable is dropped.  Because all the outputs are single
! bits, they have to be collected into one resulting integer.
:: [tffE-counter] ( n -- quot )
   [ ] n [ [tffE] keeping-inputs [ over and ] compose ] compose-times
    [ drop ] compose
    outputs>integer
;

! ** DSP Structures

! FIR filter structure.  Takes a sequence of coefficients, returns a quotation
! which implements a register.  This is similar to the delay line, but each
! output is fed through a multiplier, and all outputs are summed

: [fir] ( coeffs -- quot )
    unclip '[ [ _ * ] keep ] swap           ! first coefficient multiplier
    [ '[ [ _ * ] keep ] [reg] prepose ] map ! Creating the delay element with connected multiplier
    swap [ compose ] reduce                 ! connect everthing together
    summing-outputs ;                       ! sum all outputs

! AR structure, which is the feedback part of an IIR filter.
! If we take advantage of the fact that this is basically a multiply accumulate
! with an FIR filter in the feedback part, this is straight-forward to define.
! Note that we need to specify a register width for the a0 accumulator, which is
! enough to infer the bit-widths of the whole structure

! Since the <1moore> combinator only returns the value after the register, we
! change the stf to duplicate its next-state output, basically leaking it, while
! dropping the output that is delayed by 1 sample.  Note that in practice,
! having mealy outputs from the IIR filter will add the critical path of the
! filter to the following circuit's input logic.
:: [iir] ( bi ai width  -- quot )
    bi [fir]
    ai [ neg ] map [fir] [ + width 2 ^ wrap-counter dup ] compose 0 <1moore>
    compose [ drop ] compose ;


! TODO: DF-II

! For this, either structs or a dlet-style accessible closures are required.
