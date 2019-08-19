! Copyright (C) 2019 martinb.
! See http://factorcode.org/license.txt for BSD license.
USING: fhdl.combinators fhdl.functions fhdl.simulation kernel math sequences
tools.test ;
IN: fhdl.combinators.tests


! FSMs and stf manipulation protocol
{ { 0 0 2 2 4 4 } }
[
    { 1 2 3 4 5 6 } { f t f t f t }
    [ drop ] with-load-enable 0 <1moore>
    2map
] unit-test

{ { 0 1 0 3 0 5 } }
[
    { 1 2 3 4 5 6 } { f t f t f t }
    [ drop ] 0 with-sync-clear 0 <1moore>
    2map
] unit-test

{ { 0 1 2 2 0 5 } }
[
    { 1 2 3 4 5 6 } { t t f t t f } { f f f t f f }
    [ drop ] with-load-enable 0 with-sync-clear 0 <1moore>
    3map
] unit-test

! ! Accumulators
{ { 0 1 2 0 1 } }
[
    { 1 1 1 1 1 } { f f t f f }
    10 [acc-c]
    2map
] unit-test

{ { 0 0 1 2 } }
[
    { 1 1 1 1 }
    { f t t t }
    [ + 100 wrap-counter ] with-load-enable 0 <1moore>
    2map
] unit-test

{ { 0 1 2 3 } }
[
    { 1 1 1 1 }
    [ + 100 wrap-counter ] with-load-enable 0 <1moore>
    { t } with-constant-input
    map
] unit-test


! parallel output counter stuff
{ { 0 1 2 3 0 1 2 } } [
   2 [tffE-counter] [ t ] prepend
   7 run-cycles concat nip
] unit-test

{ { 0 0 1 1 1 4 } } [
    [regE] 6 <iota> { f t f f t f } 2map>outputs concat
] unit-test

! DSP stuff

{ { 0 42 66 0 0 0 0 0 } } [
    { 0 42 66 0 5 0 0 } [fir]
    { 1 0 0 0 0 0 0 0 } map>outputs concat
] unit-test
