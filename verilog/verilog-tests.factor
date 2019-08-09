! Copyright (C) 2019 martinb.
! See http://factorcode.org/license.txt for BSD license.
USING: fhdl.module math stack-checker tools.test ;
IN: fhdl.verilog.tests

{
    { "x_i_0" "x_i_1" }
    { "x_o_0" }
} [ [ + ] infer effect-ports ] unit-test
