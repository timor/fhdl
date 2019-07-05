USING: accessors assocs compiler.tree.combinators definitions compiler.tree.def-use effects
kernel locals namespaces quotations sequences stack-checker typed variables
words ;

IN: fhdl.module


! * Iterating over High-Level IR Tree with hardware module context

! * State During Tree Walk
! stack effect of the current definition being output
! there always has to be one, otherwise we cannot print the module's inputs and outputs
! declarations
VAR: module-effect

! Name of the module currently visited
VAR: module-name
"anon" set: module-name

! Tracks the mappings of values to identifiers
! TODO make symbol if it does not work right
<PRIVATE

GLOBAL: value-names
H{ } clone set: value-names

PRIVATE>

ERROR: undefined-value value ;

: value-name ( value -- str )
    value-names ?at [ undefined-value ] unless ;

: set-value-name ( value str -- )
    swap value-names set-at ;

! * Keeping track of value names at each IR node

! Basically, every word that defines new values must add them to the value-names
! assoc by calling `set-value-names`

! * Walking a Tree with correct Context

<PRIVATE
! Call each-node on the tree, with def-use-information available and the
! corresponding globals set
:: (each-node-in-module) ( name effect tree quot -- )
    [
        name set: module-name
        effect set: module-effect
        tree compute-def-use
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
    ] dip (each-node-in-module)
    ;
