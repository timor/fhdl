! Copyright (C) 2019 martinb.
! See http://factorcode.org/license.txt for BSD license.
USING: fhdl.combinators math sequences tools.test ;
IN: fhdl.combinators.tests


! Mealy machines and stf manipulation protocol
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

! Accumulators
{ { 0 1 2 10 11 } }
[
    { 1 1 1 1 1 } { f f t f f }
    { fixnum } 10 [acc-c]
    2map
] unit-test

{ { 0 0 1 2 } }
[
    { 1 1 1 1 }
    { f t t t }
    { fixnum } acc-stf with-load-enable 0 [1mealy] without-state-output
    2map
] unit-test

{ { 0 1 2 3 } }
[
    { 1 1 1 1 }
    { fixnum } acc-stf with-load-enable 0 [1mealy]
    without-state-output always-enabled
    map
] unit-test
