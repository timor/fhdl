! Copyright (C) 2019 martinb.
! See http://factorcode.org/license.txt for BSD license.
USING: compiler fhdl.tree math prettyprint tools.test ;
IN: fhdl.tree.tests

: fhdl-tree-test ( -- )
    [ + + ] tree. ;
