USING: kernel math math.functions math.intervals math.intervals.predicates ;
IN: fhdl.types

! * Synthesizable Data Types
! Data Types which can be used in declarations to ensure synthesizable results

INTERVAL-PREDICATE: int8 < fixnum 128 [ neg ] [ 1 - ] bi [a,b] ;
! PREDICATE: int8 < fixnum [ -128 >= ] [ 128 < ] bi and ;
! \ int8 -128 127 [a,b] "declared-interval" set-word-prop

INTERVAL-PREDICATE: uint8 < fixnum 0 255 [a,b] ;
! PREDICATE: uint8 < fixnum [ 0 >= ] [ 256 < ] bi and ;
! \ uint8 0 255 [a,b] "declared-interval" set-word-prop
INTERVAL-PREDICATE: uint32 < fixnum 0 2 32 ^ 1 - [a,b] ;

! PREDICATE: natural < integer 0 >= ;
! \ natural 0 [a,inf] "declared-interval" set-word-prop
INTERVAL-PREDICATE: natural < integer 0 [a,inf] ;

! A single bit, will be synthesized as single-bit integer signal.
INTERVAL-PREDICATE: bit < fixnum 0 1 [a,b] ;

! Turns a boolean into a 1 bit unsigned integer.
: >bit ( ? -- b )
    {
        { t [ 1 ] }
        { f [ 0 ] }
    } case ;

! Declaring a value to be in a certain interval relies on a modification to the
! compiler for now, which also allows to declare intervals in addition to types
