! Copyright (C) 2019 martinb.
! See http://factorcode.org/license.txt for BSD license.
USING: accessors arrays assocs classes compiler compiler.tree
compiler.tree.combinators compiler.tree.def-use formatting fry graphs graphviz
graphviz.notation graphviz.render images.viewer io.files.temp kernel locals math
math.bitwise mirrors namespaces present sequences sequences.deep sets ui
ui.gadgets.scrollers ;
IN: fhdl.tree

FROM: compiler.tree => node node? ;
FROM: namespaces => set ;

! * Directed Graph construction

! This vocab is used to generate representations of high-level factor IR from
! words, and utilities meant for extracting info for hardware synthesis.

! The data structure used id factor's digraph representation, wich is an assoc
! that pairs a vertex with a hash set of incoming edges, that is, the set of
! source vertices.

<PRIVATE

! Add edge to existing vertex
! TODO this is probably redundant, add-vertex already seems to exhibit the same
! behavior.
: add-edge-to-vertex ( graph vertex edge -- graph' )
    swap pick adjoin-at ;

GENERIC: add-node-to-graph ( graph node -- graph' )
! assume computed def-use!

M: node add-node-to-graph
    dup node-defs-values [ used-by ] map
    [
        pick add-vertex
    ] with each ;

! M: #introduce add-node-to-graph
!     node-defs-values [
!         swap used-by pick add-vertex
!     ] each-index
!     ;
! M: #return add-node-to-graph
!     [ node-uses-values [ [ defined-by ] keep 1array pick add-vertex ] each ]
!     [ [ 1array ] [ node-uses-values ] bi
!       [ defined-by ] map [ swap pick remove-vertex ] with each ]
!     [ over delete-at ] tri
!     ;

! M: #shuffle add-node-to-graph
!     mapping>> [ swap [ defined-by ] [ used-by ] bi* pick maybe-add-vertex ] assoc-each ;

PRIVATE>

! This is for keeping track of conditionals.  AFAICT, every #if node is
! immediately followed by a #phi node.  Whenever an #if node is encountered,
! that is pushed to the stack, so it can be used for analysis in the following
! #phi node.
SYMBOL: if-stack

: save-#if ( x -- )
    dup #if? [ if-stack get push ] [ drop ] if ;

: connect-phi-stack ( graph phi-in if-out -- graph' )
    [ add-edge-to-vertex ] 2each ;

: connect-#phi ( graph node -- graph' )
    dup #phi? [
        if-stack get pop
        [ add-edge-to-vertex ] 2keep
        [ phi-in-d>> ]
        [ children>> [ last out-d>> ] map ] bi*
        [ connect-phi-stack ] 2each
    ] [ drop ] if ;

! ** Remove non-input/output value nodes in the graph

! Assumes computed def-use.

<PRIVATE
: intermediate-value? ( vertex -- ? )
    dup integer? [
        [ defined-by #introduce? ]
        [ used-by [ #return? ] any? ] bi or not
    ]
    [ drop f ] if ;

! Remove a vertex by reconnecting the input to all output vertices.
: interpolate-vertex ( graph vertex -- graph' )
    [ [ defined-by ] [ 1array ] bi pick remove-vertex ]
    [ dup used-by pick remove-vertex ]
    [ [ defined-by ] [ used-by ] bi pick add-vertex ]
    tri ;

PRIVATE>

: interpolate-intermediate-values ( graph -- graph' )
    dup keys [
        dup intermediate-value? [
            interpolate-vertex
        ] [ drop ] if
    ] each
    [ nip null? ] assoc-reject
    ;

! Construct a directed graph that can be used with e.g. add-vertex, closure.
: tree>digraph ( tree -- assoc )
    [
        compute-def-use
        V{ } clone if-stack set
        H{ } clone swap
        [
            [ save-#if ]
            [ add-node-to-graph ]
            [ connect-#phi ] tri
        ] each-node
        ! interpolate-intermediate-values
    ] with-scope
    ;


! * Graphviz visualization

GENERIC: set-node-attributes* ( attrs node -- attrs )

M: object set-node-attributes* drop ;

GENERIC: node-id ( node -- id )
M: object node-id ;

GENERIC: node-label ( node -- str )

M: object node-label
    present ;

! Return a list of graphviz input edges to connect the two nodes
GENERIC: input-edges ( input vertex -- edges )

M: object input-edges [ node-id ] bi@ <edge> 1array ;

M: tuple node-id identity-hashcode ;

! compiler tree node names for use in record labels
GENERIC: node-name ( x -- x )

M: node node-name
    class-of name>> ;

M: #call node-name
    word>> name>> ;

M: #push node-name
    literal>> present "'" dup surround ;

M: node node-label
    [ node-uses-values [ nip dup "<i%d> i%d" sprintf ] map-index " | " join ]
    [ node-name " | %s | " sprintf ]
    [ node-defs-values [ nip dup "<o%d> o%d" sprintf ] map-index " | " join ]
    tri append append ;

M: node set-node-attributes*
    drop
    "record" =shape ;

<PRIVATE

! In the internal graph repesentation, source nodes don't have an entry. This
! creates an empty entry for each source node.
: ensure-source-nodes ( graph -- graph' )
    dup values [                ! graph value
        members
        [                       ! graph key
            2dup swap key?
            [ drop ]
            [ HS{ } swap pick set-at ] if
        ] each
    ] each ;

: vertex>node ( vertex -- node )
    [ node-id <node> ] keep
    [ node-label =label ]
    [ [ attributes>> ] dip set-node-attributes* drop ] 2bi
    ;

PRIVATE>

: digraph>graphviz ( assoc -- graph )
    ensure-source-nodes
    <digraph> swap
    [ [
            members
            [ swap input-edges [ add ] each ] with each ]
        [
            ! drop [ node-id <node> ] [ node-label ] bi
            ! =label add
            drop vertex>node add
        ] 2bi
    ] assoc-each ;

: digraph. ( digraph -- )
    digraph>graphviz
    [
        "preview" png
        "preview.png" <image-gadget> <scroller> "CDFG" open-window
    ] with-temp-directory ;

: tree. ( word/quot -- )
    frontend tree>digraph digraph. ;
