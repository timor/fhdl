USING: combinators.smart fry kernel locals sequences ;

IN: fhdl.simulation


! * Functions and Combinators for simulating hardware-describing Quotations

! Synthesizable quotations for FHDL are regular factor quotations, so all the
! regular combinators like `map`, `each`, etc. can be used to evaluate them.
! However, since we are mostly dealing with closures which return one result at
! a time, it makes to provide some words which facilitate simulation of fhdl modules.


! Modify quotations to always use predefined inputs for each call.
: with-constant-input ( quot inputs -- quot )
    [ '[ _ ] prepose ] each ;

! Map quotation over sequence, collecting all outputs into a result sequence.
: map>outputs ( quot seq -- seq )
    swap '[ _ output>array ] map ; inline

: 2map>outputs ( quot s1 s2 -- seq )
    rot '[ _ output>array ] 2map ; inline

! Call quot n times, collect all outputs into a result sequence.
:: run-cycles ( quot n -- seq )
    quot n [ quot output>array ] replicate
    ; inline
