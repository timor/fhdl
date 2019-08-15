USING: math.intervals.predicates kernel math math.intervals ;
IN: fhdl.types

! * Synthesizable Data Types
! Data Types which can be used in declarations to ensure synthesizable results

INTERVAL-PREDICATE: int8 < fixnum 128 [ neg ] [ 1 - ] bi [a,b] ;
! PREDICATE: int8 < fixnum [ -128 >= ] [ 128 < ] bi and ;
! \ int8 -128 127 [a,b] "declared-interval" set-word-prop

INTERVAL-PREDICATE: uint8 < fixnum 0 255 [a,b] ;
! PREDICATE: uint8 < fixnum [ 0 >= ] [ 256 < ] bi and ;
! \ uint8 0 255 [a,b] "declared-interval" set-word-prop

! PREDICATE: natural < integer 0 >= ;
! \ natural 0 [a,inf] "declared-interval" set-word-prop
INTERVAL-PREDICATE: natural < integer 0 [a,inf] ;


! Declaring a value to be in a certain interval relies on a modification to the
! compiler for now, which also allows to declare intervals in addition to types
