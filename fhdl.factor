! Copyright (C) 2019 martinb.
! See http://factorcode.org/license.txt for BSD license.
USING: fhdl.combinators fhdl.verilog kernel macros math typed ;
IN: fhdl

! Data Types which are supposed to be synthesizable
PREDICATE: uint8 < fixnum [ 0 >= ] [ 256 < ] bi and ;

! This is used in data-level code (not the macro-expansion-level code) to define a register for
! the value currently on top of stack
MACRO: >reg ( -- quot )
    [reg] ;

! generate a register chain with parallel outputs, input is a sequence of
! quotations which are applied to each output value

<<

>>
! This would be used if we wanted to perform the computation immediately
MACRO: delay-line ( l -- quot )
    [delay-line] ;

MACRO: fir ( coeffs -- quot )
    [fir] ;

TYPED: fir8 ( x: uint8 -- y )
    { 1 2 -2 1 } fir ;

: verilog. ( quot/word -- )
    code>verilog ;
