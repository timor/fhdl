! Copyright (C) 2019 martinb.
! See http://factorcode.org/license.txt for BSD license.
USING: fhdl fhdl.module kernel.private math prettyprint tools.test ;
IN: fhdl.tests

{  } [ [ { uint8 uint8 } declare + ] fhdl-module . ] unit-test

{  } [ [ { uint8 uint8 } declare + reg ] fhdl-module . ] unit-test

{  } [ [ { uint8 uint8 } declare + ] verilog. ] unit-test
