! Copyright (C) 2019 martinb.
! See http://factorcode.org/license.txt for BSD license.
USING: fhdl kernel.private math tools.test ;
IN: fhdl.tests

{  } [ [ { uint8 uint8 } declare + ] verilog. ] unit-test
{  } [ \ fir8 verilog. ] unit-test
