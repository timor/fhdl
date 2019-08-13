! Copyright (C) 2019 martinb.
! See http://factorcode.org/license.txt for BSD license.
USING: fhdl.combinators fhdl.verilog fhdl.verilog.operators kernel macros math typed ;
IN: fhdl

! * Synthesizable Data Types
! Data Types which are supposed to be synthesizable
PREDICATE: uint8 < fixnum [ 0 >= ] [ 256 < ] bi and ;


! * Synthesizable Quotations

! Hardware description with concatenative code works on two levels:

! 1. The actual words inside a quotation, which are executed when the code is run
!    interactively
! 2. The combinator level, where existing quotations are composed into newer ones

! There are basically two types of words which work with code as input.
! combinators, and macros

! In regular factor execution, combinators are called at runtime, where the inputs
! can be quotations, and the result is usually a concrete value, which has been
! calculated by applying one or more input quotations in a specified manner.

! Macros, on the other hand, use quotations, transform them into different
! quotations, which can then be executed.  This is akin to lisp-style macros, whose
! expansions are applied at compile time, and the resulting code executed.

! The big difference is, that for macros to work as intended at compile time, the
! inputs have to be literals.  Factor macros actually don't have that restriction,
! as they simply call the expander code at runtime, if the input cannot be
! inferred at compile (or rather parse) time.

! This allows Macros to be applied in a context where the stack-effect is a
! function of these macro parameters.  For regular combinators, the stack effect
! is independent on the input.

! This way, it is straight-forward to create synthesizable code based on other,
! smaller synthesizable code: The composition of two synthesizable quotations is
! always also a synthesizable quotation.

! * Higher-order words
! These words are used at data-level code (note quotation-building, or macro-expansion-level code).
! they are based on the expanders defined in fhdl.combinators.


! This is used in data-level code (not the macro-expansion-level code) to define a register for
! the value currently on top of stack
MACRO: reg ( -- quot )
    [reg] ;

! Generate a register chain with parallel outputs, input is a sequence of
! quotations which are applied to each output value.
MACRO: delay-line ( l -- quot )
    [delay-line] ;

! Take a sequence of input coefficients, generate a FIR filter structure using
! addition and multiplication operations.

MACRO: fir ( coeffs -- quot )
    [fir] ;


MACRO: counter ( n -- quot )
    [counter] ;

! * TODO remove headline Generating Verilog Code
