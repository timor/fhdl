USING: accessors combinators formatting kernel math math.intervals math.parser
sequences shuffle ;

IN: fhdl.verilog.syntax

! * Verilog Syntax of emitted code

GENERIC: literal>verilog ( literal -- str )
M: number literal>verilog number>string ;
M: boolean literal>verilog "1" "0" ? ;

: var-range ( interval -- str )
    {
        { full-interval [ "[FULL]" ] }
        { empty-interval [ "[EMPTY]" ] }
        [ interval-length log2 1 + "[%s:0]" sprintf ]
    } case ;

: ranged-var ( name interval -- str ) var-range "%s %s" sprintf ;

: var-decl ( name interval type -- str )
    -rot ranged-var "%s %s;" sprintf ;

! Generate identifiers from stack effects
: assign-reg ( lhs-name rhs-name -- str )
    "%s <= %s;" sprintf ;

: assign-net ( lhs-name rhs-name -- str )
    "assign %s = %s;" sprintf ;

: binary-expression ( v1 v2 op -- str )
    swap "(%s %s %s)" sprintf ;

: wrap-begin-block ( str -- str )
    "begin\n" "\nend" surround ;

: if-else-statement ( cond then else -- str )
    [ "if(%s)\n" sprintf ] [ " " prepend ] [ "\nelse\n " prepend ] tri*
    append append ;

: reg-always-block ( source-val-name reg-val-name clock reset -- str )
    [ "always @(posedge %s or posedge %s) " sprintf ] keep
    "%s == 1'b1" sprintf
    2swap [ nip 0 assign-reg ] [ swap assign-reg ] 2bi
    if-else-statement
    wrap-begin-block append ;

: begin-module ( name ports -- str )
    ", " join
    "module \\%s (%s);" sprintf ;

: end-module ( -- str )
    "endmodule" ;

: instance ( type name ports -- str )
    ", " join
    "%s %s(%s);" sprintf ;
