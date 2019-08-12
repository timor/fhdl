! Copyright (C) 2019 martinb.
! See http://factorcode.org/license.txt for BSD license.
USING: accessors assocs compiler.tree.builder compiler.tree.cleanup
compiler.tree.combinators compiler.tree.normalization compiler.tree.propagation
compiler.tree.recursive fhdl.tree.locals-propagation kernel kernel.private
locals math namespaces prettyprint sequences sets tools.test ;
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

{ t }
[
    3reg-quot build-test-tree init-local-infos drop local-infos get values
    [ first literal>> ] map
    { -3 -2 -1 } set=
] unit-test

{ f } [ 3reg-quot build-test-tree init-local-infos
        2 [ propagate-locals-step ] times drop local-infos-fixpoint? ] unit-test

{ t } [ 3reg-quot build-test-tree optimize-locals drop local-infos-fixpoint? ] unit-test
