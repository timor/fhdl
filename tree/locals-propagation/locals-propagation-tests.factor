! Copyright (C) 2019 martinb.
! See http://factorcode.org/license.txt for BSD license.
USING: accessors assocs compiler.tree.builder compiler.tree.cleanup
compiler.tree.combinators compiler.tree.normalization compiler.tree.propagation
compiler.tree.recursive fhdl.tree.locals-propagation kernel kernel.private
locals math namespaces prettyprint sequences sets tools.test ;
IN: fhdl.tree.locals-propagation.tests

: 3reg-quot-untyped ( -- quot )
    [let
     -1 :> a!
     -2 :> b!
     -3 :> c!
     [
         c
         b c!
         a b!
         [ a! ] dip
     ]
    ] ;

: 3reg-quot ( -- quot )
    3reg-quot-untyped [ { fixnum } declare ] prepend ;

: diverging-acc ( -- quot )
    [let
     -1 :> a!
     [ { fixnum } declare a [ + a! ] keep ]
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

! should result in fixnum interval not rippling through entirely
{ f } [ 3reg-quot build-test-tree init-local-infos
        2 [ propagate-locals-step ] times drop local-infos-fixpoint? ] unit-test

! should result in rippling through fixnum interval
{ t } [ 3reg-quot build-test-tree init-local-infos optimize-locals-run drop local-infos-fixpoint? ] unit-test

! dito
{ t } [ 3reg-quot build-test-tree optimize-locals drop local-infos-fixpoint? ] unit-test

! should result in rippling through full interval
{ t } [ 3reg-quot-untyped build-test-tree optimize-locals drop local-infos-fixpoint? ] unit-test
