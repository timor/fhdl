! Copyright (C) 2019 martinb.
! See http://factorcode.org/license.txt for BSD license.
USING: accessors assocs compiler.tree.builder compiler.tree.normalization
compiler.tree.propagation compiler.tree.recursive fhdl.tree.locals-propagation
kernel kernel.private locals math namespaces sequences tools.test ;
IN: fhdl.tree.locals-propagation.tests

: 3reg-quot ( -- quot )
    [let
     -1 :> a!
     -2 :> b!
     -3 :> c!
     [
         { fixnum } declare
         c
         b c!
         a b!
         [ a! ] dip
     ]
    ] ;

: build-test-tree ( quot -- tree ) build-tree analyze-recursive normalize propagate cleanup-tree ;

: see-locals ( tree -- tree )
    dup
    [
        dup [ local-reader-node? ] [ local-writer-node? ] bi or
        [ dup ... node-local-box local-infos get at ... ]
        [ drop ] if
    ] each-node ;

{ { -3 -2 -1 } }
[
    3reg-quot build-test-tree init-local-infos drop local-infos get values
    [ first literal>> ] map
] unit-test
