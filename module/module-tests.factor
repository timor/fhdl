! Copyright (C) 2019 martinb.
! See http://factorcode.org/license.txt for BSD license.
USING: accessors fhdl.module kernel tools.test ;
IN: fhdl.module.tests


{ "reg_42" "next_42" }
[ 42 <register> [ name>> ] [ setter-name>> ] bi ] unit-test
