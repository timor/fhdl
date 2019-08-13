USING: accessors assocs compiler.tree compiler.tree.combinators
compiler.tree.def-use compiler.tree.def-use.simplified
compiler.tree.propagation.info definitions effects fhdl.tree
fhdl.tree.locals-propagation formatting fry hashtables.identity kernel locals
namespaces prettyprint quotations sequences stack-checker typed words ;

IN: fhdl.module


! * Iterating over High-Level IR Tree with hardware module context

! ** Modules
! A module captures all the info that is needed to derive a circuit
! representation from the output of the frontend compiler.

TUPLE: module
    { name initial: "anon" }
    effect
    variables
    registers           ! associates local boxes with variables
    inputs              ! all variables which are inputs
    outputs             ! all variables which are outputs
    nodes               ! All nodes which must be considered for code generation
    ;

: <module> ( name effect -- module )
    module new swap >>effect
    swap  >>name
    H{ } clone >>variables
    IH{ } clone >>registers
    V{ } clone >>inputs
    V{ } clone >>outputs
    V{ } clone >>nodes
    ;

SYMBOL: current-module
: mod ( -- module ) current-module get ;

! ** Variables


! TODO: maybe don't need value slot
TUPLE: var value info name ;
: <var> ( value -- var )
    var new swap >>value ;
TUPLE: input < var ;
TUPLE: wire < var ;
TUPLE: register < var setter-name ;
TUPLE: parameter < var literal ;
: <register> ( local-box -- var )
    register new swap
    identity-hashcode
    [ "reg_%d" sprintf >>name ]
    [ "next_%d" sprintf >>setter-name ] bi
    ;

:: <named-var> ( value info prefix -- var )
    value <var> info >>info
    prefix value "%s_%d" sprintf >>name ;

! TUPLE: register slot-box reader-var writer-var ;
! : <register> ( node -- register )
!     register new swap node-local-box >>slot-box ;

! Given a value, return the variable which is associated with that value in the
! current module.
: get-var ( value -- var ) mod variables>> at ;

! create a register variable, also define the name of the setter and reader
! based on the box hashcode
: get-register-create ( node -- reg )
    node-local-box mod registers>> [ <register> ] cache ;

! Some accessors for code generation
: module-registers ( module -- seq )
    registers>> values ;
<PRIVATE

! Augment a quotation on values with info on top of stack
: with-value-info ( node obj quot: ( ..a value -- ..b ) -- obj quot: ( ..a value info -- ..b ) )
    '[ [ node-value-info ] keep swap @ ] with ;

! TODO obsolete, replace with add-new-var
: add-var-old ( var -- ) dup value>> mod variables>> set-at ;

:: get-var-create ( value class -- var )
    value mod variables>> [ drop class new ] cache ;
    ! new swap [ mod variables>> set-at ] keepd ;

: add-var ( value class -- ) get-var-create drop ;

! TODO: err if written to twice
: set-var-info ( value info -- ) swap get-var info<< ;

 ! : get-register ( slot-box -- register ) mod registers>> [ <register> ] cache ;

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
    [ nip ] [ "NONAME%d" sprintf ] if* ;

: var-range ( var -- interval )
    info>> interval>> ;

: value-range ( value -- interval )
    mod variables>> at var-range ;

! Called on each node to determine whether the node should be added to the list
! of code-generation nodes.

GENERIC: code-node? ( node -- ? )
M: node code-node? drop f ;
M: #call code-node? drop t ;
M: local-reader-node code-node? drop f ;

<PRIVATE
: reg-push-node? ( node -- ? )
    out-d>> first actually-used-by first node>>
    [ local-writer-node? ] [ local-reader-node? ] bi or ;
PRIVATE>

M: #push code-node? reg-push-node? not ;
M: #if code-node? drop t ;

! Called on nodes which create new value>variable mappings
! Need to update the current module variables
! Return a list of var objects
! TODO: the naming is actually not correct, since this does not define
! variables, but rather value-to-variable mappings
! TODO: define-variables* and add-var-infos* should probably be merged, since
! they are called after each other for each node anyways...

GENERIC: define-variables* ( node -- )
M: node define-variables* drop ;
GENERIC: add-var-infos* ( node -- )
M: node add-var-infos* drop ;

! These nodes define new wires
UNION: var-definer #call #push ;
! These nodes have value info
UNION: var-consumer #call #return ;

M: #call define-variables*
    out-d>> [ [ "res_%d" sprintf ] [ wire get-var-create ] bi name<< ] each ;

M: #push define-variables*
    out-d>> first
    [ "const_%d" sprintf ]
    [ parameter get-var-create ] bi name<< ;

! FIXME: this code duplication should be caught in dispatch
M: local-reader-node define-variables* ( node -- )
    [ get-register-create ]
    [ out-d>> first ] bi mod variables>> set-at ;

M: #introduce define-variables*
    out-d>> [ input get-var-create ] map
    mod effect>> effect-inputs
    [ >>name mod inputs>> push ] 2each ;

! Assumes that for each returning value, a variable has already be defined by
! the producer
M: #return define-variables*
    in-d>> [ get-var ] map
    mod effect>> effect-outputs
    [ >>name mod outputs>> push ] 2each ;

M: #renaming define-variables*
    inputs/outputs [ [ get-var ] dip mod variables>> set-at ] 2each ;

! When a local variable is set, this is interpreted as an assignment to the
! variable representing the next value
! M: local-writer-node define-variables*

! When a local variable is read, this is interpreted as a register read.  Thus
! the value output by the local reader node needs to be set to the register
! output variable
! M: local-reader-node define-variables*
!     [ out-d>> first ]
!     [ dup in-d>> first node-value-info literal>> get-register reader-name>> ] bi
!     set-var-name ;

M: var-consumer add-var-infos*
    [ in-d>> ] [ node-input-infos ] bi
    [ set-var-info ] 2each ;

! Producer, sets the name of the output value based on the register information
! FIXME: deduplicate with after method on var-consumer
M: local-reader-node add-var-infos*
    [ [ in-d>> ] [ node-input-infos ] bi
      [ set-var-info ] 2each ] keep
    [ get-register-create ] [ out-d>> first ] bi
    mod variables>> set-at ;


! Consumer, but defines its input to be the setter var for the register
! FIXME: deduplicate with after method on var-consumer
! M: local-writer-node add-var-infos*
!     dup [ get-register-create setter-name>> ] [ in-d>> first ] bi
!     set-var-info
!     ! set dummy input to make check-module happy:
!     [ in-d>> second ] [ node-input-infos second ] bi
!     set-var-info
!     ;

M: #if add-var-infos*
    in-d>> first boolean <class-info> set-var-info ;

! M: #phi add-var-infos*
!     phi-in

! Rename the variables which are returned to the name of the output ports ;

! * Walking a Tree with correct Context
ERROR: no-var-info var ;

<PRIVATE
! TODO: base check on nodes slot
: check-module ( module -- )
    variables>> values
    [ dup info>> [ drop ] [ no-var-info ] if ] each
    ;


! Call each-node on the tree, with def-use-information available and the
! corresponding globals set
:: (each-node-in-module) ( name effect tree quot -- )
    [
        name effect <module> current-module set-global
        tree compute-def-use
        dup [ [ define-variables* ] [ add-var-infos* ] bi ] each-node
        ! mod check-module
        [ quot call( node -- ) ] each-node
    ] with-scope ;

GENERIC: get-module-name ( quot/word -- str )
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
! FIXME: not main interface anymore
: each-node-in-module ( quot/word quot -- )
    [
        [ get-module-name ] [ get-module-effect ] [ get-module-def ] tri
        build-fhdl-tree
        ! dup ...
    ] dip (each-node-in-module)
    ;

! Convert quotation or word into an fhdl module.
: fhdl-module ( quot/word -- module )
    [ get-module-name ]
    [ get-module-effect <module> current-module set-global ]
    [ get-module-def ] tri
    build-fhdl-tree compute-def-use
    [
        [ dup code-node? [ mod nodes>> push ] [ drop ] if ]
        [ define-variables* ]
        [ add-var-infos* ] tri
    ] each-node
    current-module get
    ;
