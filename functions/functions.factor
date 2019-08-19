USING: accessors fhdl.types kernel kernel.private math math.bitwise
math.intervals words ;

IN: fhdl.functions


! * Functions and Macros for usage in hardware description

! Concatenation operator.  Top of stack contains the new lsb, the
! element below is the msb part
! that is the new lsb. e.g. ... n b --> 2*n+b

: lsb-concat ( b n -- n' )
    1 shift + ;
\ lsb-concat [
    nip clone [ 1 [a,a] interval-shift ] change-interval
] "outputs" set-word-prop


! This word special-cases on the maximum value being a power of two, where it
! applies a more efficient operation.  It will only work correctly with positive
! values, and it will only perform a mod operation correctly when n is a power
! of 2.
! TODO: fix semantics, maybe split
: wrap-counter ( m n -- m' )
    [ { natural } declare ] dip
    dup power-of-2?
    [ wrap ]
    [ 2dup <
      [ drop ]
      [ 2drop 0 ]
      if
    ] if ; inline


