! Copyright (C) 2019 martinb.
! See http://factorcode.org/license.txt for BSD license.
USING: accessors compiler.tree.propagation.info fhdl.module fhdl.verilog.private
kernel math math.intervals stack-checker tools.test ;
IN: fhdl.verilog.tests

{
    { "x_i_0" "x_i_1" }
    { "x_o_0" }
} [ [ + ] infer effect-ports ] unit-test

{ "wire /*[EMPTY]*/ foo = bar;" } [
    wire new "foo" >>name <value-info> empty-interval >>interval >>info
    "bar" implicit-wire-definition
                      ] unit-test
