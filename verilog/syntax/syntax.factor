USING: accessors combinators formatting kernel math math.intervals math.order
math.parser sequences shuffle ;

IN: fhdl.verilog.syntax

! * Verilog Syntax of emitted code

! FIXME: maybe rename to verilog-literal
GENERIC: literal>verilog ( literal -- str )
M: object literal>verilog "INVALID(/*%u*/)" sprintf ;
M: number literal>verilog number>string ;
M: boolean literal>verilog "1" "0" ? ;

: literal-zero-interval? ( int -- ? )
    { [ interval-zero? ] [ interval-singleton? ] } 1&& ;

! If an interval contains negative numbers, then we switch to signed.
! TODO: validate bit-widths
: interval-bitrange ( interval -- str )
    [ from>> ] [ to>> [ first abs ] bi@ max log2 ] [ interval-nonnegative? ] tri
    [ "" ] [ "signed " ] if
    swap "%s[%d:0]" sprintf
    ;


: range-spec ( interval -- str )
    {
        { full-interval [ "/*[FULL]*/" ] }
        { empty-interval [ "/*[EMPTY]*/" ] }
        [ dup literal-zero-interval?
          [ drop "/*[ZEROLENGTH]*/" ]
          [ interval-bitrange ] if
        ]
    } case ;

: decl-range ( name interval -- str ) range-spec swap "%s %s" sprintf ;
: ranged-var ( name interval -- str ) range-spec "%s %s" sprintf ;

! FIXME: name clash with var-declaration in fhdl.module
: var-decl ( name interval type -- str )
    -rot decl-range "%s %s;" sprintf ;

: procedural-assignment ( lhs-name rhs -- str )
    "%s = %s;" sprintf ;

! FIXME rename to explicit-assignment
: assign-net ( lhs-name rhs-name -- str )
    "assign %s = %s;" sprintf ;

: parameter-definition ( lhs-name value -- str )
    "parameter %s = %s;" sprintf ;

: binary-expression ( v1 v2 op -- str )
    swap "(%s %s %s)" sprintf ;

: unary-expression ( v op -- str )
    swap "(%s %s)" sprintf ;

: binary-concatenation ( v1 v2 -- str )
    "{%s,%s}" sprintf ;

: wrap-begin-block ( str -- str )
    "begin\n" "\nend" surround ;

: if-else-statement ( cond then else -- str )
    [ "if(%s)\n" sprintf ] [ " " prepend ] [ "\nelse\n " prepend ] tri*
    append append ;

: always-at-clock ( clock-name -- str )
    "always @(posedge %s) " sprintf ;

: reg-always-block ( source-val-name reg-val-name clock -- str )
    always-at-clock
    [ swap procedural-assignment ] dip
    swap append ;

: begin-module ( name ports -- str )
    ", " join
    "module \\%s (%s);" sprintf ;

: end-module ( -- str )
    "endmodule" ;

: instance ( type name ports -- str )
    ", " join
    "\\%s %s(%s);" sprintf ;

! Ternary conditional expression
: conditional-expr ( selector then else -- str )
    "%s ? %s : %s" sprintf ;
