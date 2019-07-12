! Copyright (C) 2019 martinb.
! See http://factorcode.org/license.txt for BSD license.
USING: tools.test fhdl.combinators ;
IN: fhdl.combinators.tests


{ { 0 0 2 2 4 4 } }
[
    { 1 2 3 4 5 6 } { f t f t f t }
    [ ] with-load-enable 0 [1mealy] without-state-output
    2map
] unit-test

{ { 0 1 0 3 0 5 } }
[
    { 1 2 3 4 5 6 } { f t f t f t }
    [ ] 0 with-sync-clear 0 [1mealy] without-state-output
    2map
] unit-test

{ { 0 1 2 2 0 5 } }
[
    { 1 2 3 4 5 6 } { t t f t t f } { f f f t f f }
    [ ] with-load-enable 0 with-sync-clear 0 [1mealy] without-state-output
    3map
] unit-test

