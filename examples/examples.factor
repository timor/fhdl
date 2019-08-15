USING: fhdl fhdl.combinators fhdl.module fhdl.tree fhdl.types fhdl.verilog
kernel.private math sequences typed ;

IN: fhdl.examples

! ** Examples
: ex-fir-tree ( -- )
    { 1 -2 3 -4 } [fir] tree. ;


: typed-fir ( -- quot )
    { 1 -2 3 -4 } [fir] [ { uint8 } declare ] prepend ;

: ex-fir-typed ( -- )
    typed-fir tree. ;

: test-registered-adder ( a b -- c )
    { fixnum fixnum } declare
    + reg ;

: ex-adder ( -- )
    \ test-registered-adder verilog. ;

: test-anon-adder ( -- quot )
    [ { uint8 uint8 } declare + ] ;

: test-module ( -- module )
    \ test-registered-adder fhdl-module ;

: ex-anon ( -- )
    test-anon-adder verilog. ;

TYPED: fir8 ( x: uint8 -- y )
    { 1 2 -2 1 } fir ;

: ex-fir-verilog ( -- )
    \ fir8 verilog.
    typed-fir verilog. ;

! Quick way to run all examples and verify that everything still works
: run-examples ( -- )
    ex-fir-tree
    ex-fir-typed
    ex-adder
    ex-anon
    ex-fir-verilog ;
