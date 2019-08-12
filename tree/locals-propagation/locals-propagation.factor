USING: accessors assocs compiler.tree compiler.tree.combinators
compiler.tree.propagation compiler.tree.propagation.info hashtables.identity
kernel locals.backend namespaces prettyprint sequences vectors words ;

IN: fhdl.tree.locals-propagation

! * SSA Value Information Propagation for Local Variables

! Local Variables are implemented as opaque accesses to constant memory locations.
! These operations are opaque, so the general type inference chain (value info
! propagation) is broken.  Nevertheless, the data flow concerning local variables
! can be determined deterministically, since all accesses to and from that
! location are in the scope of the quotation being compiled.

! So for the regular propagation pass to work, the output value info of the local
! variable read calls must be computed.

! Since there is no direct link between local variable access nodes in the graph,
! information is kept in a hash table during compilation, which is indexed by the
! identity-hashcode of the box, which has been generated for the local variable.
! This id connects all local-value and set-local-value calls to the same variable.

! Basically, there are two possible cases: write-before-read, read-before-write.
! Write-before read should not be interesting, as it is only syntax sugar.

! Read-before write is the interesting case, since this is what is generated when
! a lexical closure is defined.

! ** Input Cone analysis
! In theory, it should be sufficient to look at the input cone(s) of for the
! variable setter(s) in the data flow graph for one specific variable.  There can
! be several cases:

! 1. No input cone contains a call to the reader of that local variable
! 2. An input cone contains a call to the reader of that local variable, but the
!    function which determines the type and interval information has a fixed point
!    or converges, i.e. the union type of all "iterations" has a fixed point.
! 3. Like above, but the function computing the union type converges.

! The first case happens e.g. for a register chain, where the set-local-value
! input cone will never contain the same local's reader.

! The second case happens e.g. for a state machine, where the next state is
! computed based on the previous state, but the state encoding is a bounded set
! (e.g. an enum), and the function which computes the next value type based on the
! initial value, input, and current state will always return a value from the set
! of possible states.

! The last case happens for example for a simple accumulator structure.  The input
! cone for the setter contains the previous value, and the function which computes
! the type for the next variable value will always take into account the new
! input.  If left like that, the result is not synthesizable since the register
! values are unbounded.

! *** Diverging input cone type information
!   There are two ways to deal with this:

! 1. Declare the local variable type.

! This amounts to having declare statements at the output of all local reader
! nodes.  This forces the compiler to abandon type checking, since it is assumed
! that no values will be stored in the local variable which don't conform to the
! type.  This puts the burden onto the user to guarantee that no illegal values
! are stored in the variable

! 2. Insert overflow handling code.

! With this solution, code which (re-)establishes bounded type information is
! inserted before all setter calls.  A practical example would be to implement a
! cut-off operation to a certain number of bits, or a block which saturates the
! value.  Doing this reverts this to the second case explained above, since now an
! element is inserted into the input cone of the setter(s), which makes the value
! information independent of the type information of the local variable reader.

! *** Mutual dependencies

! So far, only the case was considered where one variable's dependency on itself
! was analyzed,  however, if more than one variable setter share a part of the
! input cone where both local variable readers are present, the assumptions that
! have to be made on the initial values are combinations of possible variable values.

! Thus it is necessary to step through the paths from readers to setters in
! parallel.  How often this has to be done depends on the "depths" of the
! worst-case chain of read-before-write operations.  In the best case (Parallel
! single bit registers), all Information is available after twod iteration.  In the
! worst case (register chain, all next-values depend on the previous values), this
! is only known after /n+1/ iterations, when all combinations have been
! considered.

! The reason why it has to be 1 extra iteration is to decide whether the function
! computing the type is growing.  If the value range does not grow anymore, it is
! assumed that there is no possibility that this value grows anymore.

! * Implementation strategy

! To arrive at conservative type information, all possible input value types to
! the setters have to be considered.  For each local box, a list is created, which
! stores value info for that iteration.  The algorithm is then as follows:

! 1. Initialize each local's list with the type of the initial value
! 2. For up to /n+1/ iterations, do
!    1. Run a propagate pass
!    2. For each setter node, use the computed value information, create the union
!       with the preceding element.
!    3. If the new value range is bigger than the last one, add the union of both
!       to the list for that local variable
!    4. If all lists have equally large value interval info, terminate early
! 3. For each local variable, If the last two elements describe the same value
!    interval:
!    1. Leave this as the output type of the local reader
!    2. Else set the output type of the local reader to the unbounded interval,
!       which is a conservative estimate assuming that the type will grow
!       monotonically for each iteration, repeat from step 2


!  #+begin_src factor
PREDICATE: local-writer-node < #call word>> \ set-local-value = ;
PREDICATE: local-reader-node < #call word>> \ local-value = ;
PREDICATE: regular-call < #call [ local-writer-node? ] [ local-reader-node? ] bi@ or not ;

SYMBOL: local-infos

SYMBOL: track-local-infos
: track-local-infos? ( -- ? ) track-local-infos get ;

GENERIC: node-local-box ( node -- box )
M: local-writer-node node-local-box
    node-input-infos second literal>> ;
M: local-reader-node node-local-box
    node-input-infos first literal>> ;

: init-local-infos ( nodes -- nodes )
    IH{ } clone local-infos set
    dup
    [
        dup local-reader-node?
        [ node-local-box local-infos get [ first clone <literal-info> 1vector ] cache drop ]
        [ drop ] if
    ] each-node ;

: current-local-info ( box -- info )
    local-infos get at last ;

! Update the local info record with new info
: update-local-info ( box info -- )
    over current-local-info value-info-union
    swap local-infos get push-at ;

! Perform one iteration, do after initializing local infos
: propagate-locals-step ( nodes -- nodes )
    propagate
    dup
    [
        dup local-writer-node?
        [
            [ node-local-box ] [ node-input-infos first ] bi
            update-local-info
        ]
        [ drop ] if
    ] each-node
    ;

!  #+end_src

!  #+begin_src factor
: optimize-locals-run ( nodes -- nodes )
    local-infos get assoc-size 1 + [ propagate-locals-step ] times
    ;

! This is needed to ensure that local value information propagation has converged.
: local-info-entry-converges? ( seq -- ? )
    last2 swap value-info<= ;

: local-infos-fixpoint? ( -- ? )
    local-infos get values
    [ local-info-entry-converges? ] all?
    ;

ERROR: local-value-infos-not-converging ;

! This re-initializes the local value infos so that the variables that diverge
! will start with the full intervall.  The other info records are initialized like previously
: unconstrain-local-infos ( -- )
    local-infos [
        [
            dup local-info-entry-converges?
            [
                first
            ] [
                last clone full-interval >>interval
            ] if 1vector
        ] assoc-map
    ] change ;

! This is is the top-level function that should be inserted as a pass during
! frontend compilation.
: optimize-locals ( nodes -- nodes )
    init-local-infos
    optimize-locals-run
    local-infos get assoc-size swap
    [ local-infos-fixpoint? ]
    [
        unconstrain-local-infos
        over .
        over 0 <= [ local-value-infos-not-converging ] when
        optimize-locals-run [ 1 - ] dip
    ]
    until nip
    ;

! #+end_src

\ local-value [
    literal>> local-infos get at
    [ last clone ] [ object-info ] if*
] "outputs" set-word-prop
!  #+end_src


!  Hack inlining so loading this triggers the new behavior, this should obviously
!  be removed and local-value and set-local-value defined non-inline properly

!  #+begin_src factor
{ set-local-value local-value } [ f "inline" set-word-prop ] each
!  #+end_src
