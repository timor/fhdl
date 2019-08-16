USING: fhdl fhdl.combinators fhdl.module fhdl.tree fhdl.types fhdl.verilog
kernel kernel.private locals math math.bitwise sequences typed ;

IN: fhdl.examples

! * Examples
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

: ex-correct-FDRE ( -- )
    [reg] { uint8 } with-declared-inputs 0 with-sync-clear with-load-enable verilog. ;

: ex-incorrect-FDRE ( -- )
    [reg] { uint8 } with-declared-inputs with-load-enable 0 with-sync-clear verilog. ;

! Quick way to run all examples and verify that everything still works
: run-examples ( -- )
    ex-fir-tree
    ex-fir-typed
    ex-adder
    ex-anon
    ex-fir-verilog
    ex-correct-FDRE
    ex-incorrect-FDRE
    ;


! One of the tests which infer the widths correctly, but infers wrong because
! incomplete next-state assignment would have to be expressed as behavioral code
: closure1 ( -- quot )
    [let 0 :> state! [| in enable | state enable [ state in + 2048 wrap state! ] when ] ] [ { uint8 boolean } declare ] prepend ;

! This one does not generate correct code because there are side-effect
! statements inside branches, resulting in two assign statements.  Again, this
! would be valid in behavioral code.
! TODO actually insert check for this when going to emit structural code...
: closure2 ( -- quot )
    [let 0 :> state! [| in enable | state enable [ state in + 2048 wrap state!
                                                 ] [ state state! ] if ] ]
    [ { uint8 boolean } declare ] prepend ;

! This one generates the correct code, but unfortunately breaks inference of the
! register width.  If this is due to a non-stabilizing issue in value
! propagation, something is wrong with the value type detection at the input of
! the state register, because both paths should be bounded.
: closure3 ( -- quot )
    [let 0 :> state! [| in enable | state enable [ state in + 2048 wrap
                                                 ] [ state ] if state! ] ]
    [ { uint8 boolean } declare ] prepend ;

: closure4 ( -- quot )
    [let 0 :> state! [| in enable | state enable [ state in +
                                                 ] [ state ] if 2048 wrap state! ] ]
    [ { uint8 boolean } declare ] prepend ;
