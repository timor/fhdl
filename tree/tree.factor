! Copyright (C) 2019 martinb.
! See http://factorcode.org/license.txt for BSD license.
USING: accessors assocs classes combinators compiler.tree compiler.tree.builder
compiler.tree.cleanup compiler.tree.combinators compiler.tree.dead-code
compiler.tree.def-use compiler.tree.escape-analysis
compiler.tree.escape-analysis.check compiler.tree.identities
compiler.tree.modular-arithmetic compiler.tree.normalization
compiler.tree.optimizer compiler.tree.propagation compiler.tree.propagation.info
compiler.tree.recursive compiler.tree.tuple-unboxing formatting graphviz
graphviz.notation graphviz.render images.viewer io.files.temp kernel locals math
math.intervals math.parser namespaces present prettyprint sequences strings ui
ui.gadgets.scrollers words ;
IN: fhdl.tree

FROM: compiler.tree => node node? ;
FROM: namespaces => set ;
FROM: fhdl.combinators.private => reg ;

! * Special treatment of reg-pseudocall

PREDICATE: reg-node < #call
    word>> \ reg = ;

! HACK the value info to copy the input info, this ensures correct value type propagation
\ reg [ drop clone ] "outputs" set-word-prop

! * Directed Graph construction

! This vocab is used to generate representations of high-level factor IR from
! words, and utilities meant for extracting info for hardware synthesis.

! The data structure used id factor's digraph representation, wich is an assoc
! that pairs a vertex with a hash set of incoming edges, that is, the set of
! source vertices.

! needs def-use
: actual-definition ( value -- node position )
    dup defined-by dup #shuffle? [
        mapping>> at actual-definition ]
    [ [ node-defs-values index ] keep swap ] if ; recursive


! * Graphviz visualization

GENERIC: set-node-attributes* ( attrs node -- attrs )

M: object set-node-attributes* drop ;

GENERIC: vertex-id ( vertex -- id )
M: object vertex-id ;

GENERIC: vertex-label ( vertex -- str )

M: object vertex-label
    present ;

M: tuple vertex-id identity-hashcode ;

! compiler tree node names for use in record labels
GENERIC: node-name ( x -- x )

M: node node-name
    class-of name>> ;

M: #call node-name
    word>> name>> ;

M: #push node-name
    literal>> "%u" sprintf "'" dup surround ;

<PRIVATE
: intervall-length>str ( x -- x )
    {
        { [ dup 1/0. = ] [ drop "inf" ] }
        { [ dup 0 = not ] [ log2 1 + number>string ] }
        [ number>string ]
    } cond ;

: value-label ( value prefix -- str )
    swap
    value-info dup . interval>> interval-length intervall-length>str "(" ")" surround
    append ;

: escape-node-name ( str -- str )
    [ [ 1string ] [ "{}<>|" member? ] bi [ "\\" prepend ] when ]
    [ append ] map-reduce ;

PRIVATE>


M: node vertex-label
    [ node-uses-values [ "i%d" sprintf [ value-label ] keep swap "<%s> %s" sprintf ] map-index " | " join ]
    [ node-name escape-node-name " | %s | " sprintf ]
    [ node-defs-values [ nip dup "<o%d> o%d" sprintf ] map-index " | " join ]
    tri append append ;

M: node set-node-attributes*
    drop
    "record" =shape ;

: vertex>node ( vertex -- node )
    [ vertex-id <node> ] keep
    [ vertex-label =label ]
    [ [ attributes>> ] dip set-node-attributes* drop ] 2bi
    ;

GENERIC: add-tree-node ( graph node -- graph )
M: #shuffle add-tree-node drop ;
M: node add-tree-node
    vertex>node add ;

GENERIC: add-input-edges ( graph node -- graph )
M: #shuffle add-input-edges drop ;
M: node add-input-edges
    [let :> dest
        dest node-uses-values :> input-values
        input-values [| val dest-pos |
          val actual-definition :> ( source source-pos )
          source dest [ vertex-id ] bi@ <edge>
          source-pos "o%d" sprintf =tailport
          dest-pos "i%d" sprintf =headport
          add
        ] each-index
    ]
    ;


! TODO better name
: fhdl-optimize ( nodes  -- nodes )
    analyze-recursive normalize propagate cleanup-tree dup
    run-escape-analysis?
    [ escape-analysis unbox-tuples ] when
    apply-identities compute-def-use remove-dead-code ?check
    compute-def-use
    optimize-modular-arithmetic
    ! TODO reintroduce if no necessary info is lost
    ! finalize
    ;

! Modifies compiler variable scope!
: build-fhdl-tree ( quot/word -- nodes )
    build-tree fhdl-optimize ;

: tree>graphviz ( nodes -- graph )
    [
        <digraph> swap
        [
            [ add-tree-node ]
            [ add-input-edges ]
            bi
        ] each-node
    ] with-scope
    ;


: tree. ( word/quot -- )
    build-fhdl-tree
    tree>graphviz
    [
        "preview" png
        "preview.png" <image-gadget> <scroller> "CDFG" open-window
    ] with-temp-directory ;
