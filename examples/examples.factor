USING: fhdl fhdl.combinators fhdl.tree kernel.private math sequences typed ;

IN: fhdl.examples

! ** Examples
: ex-fir-tree ( -- )
    { 1 -2 3 -4 } [fir] tree. ;

: ex-fir-typed ( -- )
    { 1 -2 3 -4 } [fir] [ { uint8 } declare ] prepend tree. ;

: test-registered-adder ( a b -- c )
    { fixnum fixnum } declare
    + reg ;

: ex-adder ( -- )
    \ test-registered-adder verilog. ;

: test-anon-adder ( -- quot )
    [ { uint8 uint8 } declare + ] ;

: ex-anon-module ( -- )
    test-anon-adder verilog. ;

: ex-anon ( -- )
    test-anon-adder verilog. ;

TYPED: fir8 ( x: uint8 -- y )
    { 1 2 -2 1 } fir ;

: ex-fir-verilog ( -- )
    \ fir8 verilog. ;

! Quick way to run all examples and verify that everything still works
: run-examples ( -- )
    ex-fir-tree
    ex-fir-typed
    ex-adder
    ex-anon-module
    ex-anon
    ex-fir-verilog ;
