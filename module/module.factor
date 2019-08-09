USING: accessors assocs compiler.tree compiler.tree.combinators
compiler.tree.def-use compiler.tree.propagation.info definitions effects
fhdl.tree formatting fry kernel locals namespaces quotations sequences
stack-checker typed variables words ;

IN: fhdl.module


! * Iterating over High-Level IR Tree with hardware module context

! ** Modules
! A module captures all the info that is needed to derive a circuit
! representation from the output of the frontend compiler.

TUPLE: module
    { name initial: "anon" }
    effect
    variables ;

: <module> ( effect -- module )
    module new swap >>effect H{ } clone >>variables ;

SYMBOL: current-module
: mod ( -- module ) current-module get ;

! ** Variables


! TODO: maybe don't need value slot
TUPLE: var value info name ;
: <var> ( value -- var )
    var new swap >>value ;

:: <named-var> ( value info prefix -- var )
    value <var> info >>info
    prefix value "%s_%d" sprintf >>name ;

<PRIVATE

! Augment a quotation on values with info on top of stack
: with-value-info ( node obj quot: ( ..a value -- ..b ) -- obj quot: ( ..a value info -- ..b ) )
    '[ [ node-value-info ] keep swap @ ] with ;

: get-var ( value -- var ) mod variables>> [ <var> ] cache ;

: add-var ( var -- ) dup value>> mod variables>> set-at ;

! TODO: err if written to twice
: set-var-info ( var info -- ) swap get-var info<< ;


PRIVATE>
: effect-ports ( effect -- ins outs )
    [ in>> ] [ out>> ] bi
    "i" "o"
    [ swap [ "%s_%s_%d" sprintf ] with map-index ] bi-curry@ bi* ;

: effect-inputs ( effect -- ins ) effect-ports drop ;
: effect-outputs ( effect -- outs ) effect-ports nip ;

! TODO make private, after factoring out at call site
: set-var-name ( value str -- ) swap get-var name<< ;

: value-name ( value -- name )
    dup mod variables>> at name>>
    [ nip ] [ "v%d" sprintf ] if* ;

: value-range ( value -- interval )
    mod variables>> at info>> interval>> ;

! Called on nodes which create new value>variable mappings
! Need to update the current module variables
! Return a list of var objects
GENERIC: define-variables* ( node -- )
M: node define-variables* drop ;
GENERIC: add-var-infos* ( node -- )
M: node add-var-infos* drop ;

UNION: var-definer #call #push ;
UNION: var-consumer #call #return ;

M: var-definer define-variables*
    out-d>> [ <var> add-var ] each ;

M: #introduce define-variables*
    out-d>>
    mod effect>> effect-inputs
    [ set-var-name ] 2each ;

M: #return define-variables*
    in-d>>
    mod effect>> effect-outputs
    [ set-var-name ] 2each ;

M: #renaming define-variables*
    inputs/outputs [ [ get-var ] dip mod variables>> set-at ] 2each ;

M: var-consumer add-var-infos*
    [ in-d>> ] [ node-input-infos ] bi
    [ set-var-info ] 2each ;

M: #if add-var-infos*
    in-d>> first boolean <class-info> set-var-info ;

! M: #phi add-var-infos*
!     phi-in

! Rename the variables which are returned to the name of the output ports ;

! * Walking a Tree with correct Context
ERROR: no-var-info var ;

<PRIVATE
: check-module ( module -- )
    variables>> values
    [ dup info>> [ drop ] [ no-var-info ] if ] each
    ;


! Call each-node on the tree, with def-use-information available and the
! corresponding globals set
:: (each-node-in-module) ( name effect tree quot -- )
    [
        effect <module> name >>name current-module set-global
        tree compute-def-use
        dup [ [ define-variables* ] [ add-var-infos* ] bi ] each-node
        mod check-module
        [ quot call( node -- ) ] each-node
    ] with-scope ;

GENERIC: get-module-name ( quot/word -- module )
M: callable get-module-name drop "anon" ;
M: word get-module-name name>> ;

GENERIC: get-module-effect ( quot/word -- effect )
M: callable get-module-effect infer ;
M: word get-module-effect stack-effect ;
M: typed-word get-module-effect
    "typed-word" word-prop stack-effect
    [ in>> ] [ out>> ] bi
    [ [ first ] map ] bi@ <effect>
    ;

GENERIC: get-module-def ( quot/word -- definition )
M: callable get-module-def ;
M: word get-module-def definitions:definition ;
M: typed-word get-module-def "typed-word" word-prop get-module-def ;
PRIVATE>

! main interface
: each-node-in-module ( quot/word quot -- )
    [
        [ get-module-name ] [ get-module-effect ] [ get-module-def ] tri
        build-fhdl-tree
        ! dup ...
    ] dip (each-node-in-module)
    ;
