! Copyright (C) 2019 martinb.
! See http://factorcode.org/license.txt for BSD license.
USING: accessors assocs classes compiler compiler.tree compiler.tree.combinators
formatting fry graphviz graphviz.notation graphviz.render images.viewer
io.files.temp kernel locals math math.bitwise mirrors namespaces present
sequences sequences.deep sets ui ui.gadgets.scrollers ;
IN: fhdl.tree

FROM: compiler.tree => node node? ;
FROM: namespaces => set ;

! * Directed Graph construction

! This vocab is used to generate representations of high-level factor IR from
! words, and utilities meant for extracting info for hardware synthesis.

! The data structure used id factor's digraph representation, wich is an assoc
! that pairs a vertex with a hash set of incoming edges.

! At the moment, edges are just source vertices.

<PRIVATE

! Add edge to existing vertex
: add-edge-to-vertex ( graph vertex edge -- graph' )
    swap pick adjoin-at ;

:: add-edges ( graph vertex edges -- graph' )
    graph edges [ vertex swap add-edge-to-vertex ] each ;

! Helper, build the associations from values to the node, where the key can be
! used for iteration.
: node-ports ( node port-list -- assoc )
    over <mirror> extract-keys
    values sift harvest concat flatten
    swap '[ _ ] map>alist ;


! This returns all the node inputs.
! TODO: replace by node-uses-values from compiler.tree.def-use
: node-inputs ( node -- assoc )
    { "in-d" "phi-in-d" "in-r" } node-ports ;

! TODO: replace by node-defs-values from compiler.tree.def-use
: node-outputs ( node -- assoc )
    { "out-d" "out-r" } node-ports ;

: add-node-to-graph ( graph node -- graph' )
    [ swap [ drop HS{ } clone ] cache drop ] 2keep
    [ dup node-uses-values [ add-edge-to-vertex ] with each ]
    [ dup node-defs-values [ swap add-edge-to-vertex ] with each ]
    bi
    ;

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

! Construct a directed graph that can be used with e.g. add-vertex, closure.
: tree>digraph ( tree -- assoc )
    V{ } clone if-stack set
    H{ } clone swap
    [
        [ save-#if ]
        [ add-node-to-graph ]
        [ connect-#phi ] tri
    ] each-node ;

! * Graphviz visualization

<PRIVATE
! Can be used for short display of a long integer id.
: id-label ( d -- str )
    15 0 bit-range "...%04x" sprintf ;

: node-id ( node -- id )
    identity-hashcode ;

GENERIC: node-label ( node -- str )

M: node node-label
    class-of ;

! stack index
M: fixnum node-label
    present ;

M: #call node-label
    word>> ;

M: #push node-label
    literal>> "%u" sprintf "'" dup surround ;

PRIVATE>
: digraph>graphviz ( assoc -- graph )
    <digraph> swap
    [   members swap
        [ node-id '[ node-id _ add-edge ] each ] keep
        [ node-id <node> ] [ node-label ] bi
        =label add
    ] assoc-each ;


: tree. ( word/quot -- )
   frontend tree>digraph digraph>graphviz
    [
        "preview" png
        "preview.png" <image-gadget> <scroller> "CDFG" open-window
    ] with-temp-directory ;
