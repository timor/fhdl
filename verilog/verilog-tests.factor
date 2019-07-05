! Copyright (C) 2019 martinb.
! See http://factorcode.org/license.txt for BSD license.
USING: fhdl.verilog fhdl.verilog.private math stack-checker tools.test ;
IN: fhdl.verilog.tests

{
    { "x_i0" "x_i1" }
    { "x_o0" }
} [ [ + ] infer effect-ports ] unit-test

{ "v_1234"} [ 1234 value>verilog-identifier ] unit-test
