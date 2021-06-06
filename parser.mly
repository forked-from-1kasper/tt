%{
  open Expr
  exception UnexpectedToken of string
%}

%token <string> IDENT
%token <int> NAT
%token LPARENS RPARENS COMMA COLON NO EOF HOLE
%token SET DEFEQ ARROW FST SND LAM DEF
%token DIRSEP MODULE WHERE IMPORT AXIOM
%token SIGMA PI OPTION

%start <Expr.file> file
%start <Expr.command> repl

%%

ident : NO { No } | IDENT { Name ($1, 0) }
vars : ident vars { $1 :: $2 } | ident { [$1] }
lense : LPARENS vars COLON exp1 RPARENS { List.map (fun x -> (x, $4)) $2 }
telescope : lense telescope { List.append $1 $2 } | lense { $1 }
params : telescope { $1 } | { [] }
exp0 : exp1 COMMA exp0 { EPair ($1, $3) } | exp1 { $1 }
exp2 : exp2 exp3 { EApp ($1, $2) } | exp3 { $1 }
path : IDENT { $1 } | IDENT DIRSEP path { $1 ^ Filename.dir_sep ^ $3 }
content : line content { $1 :: $2 } | EOF { [] }
file : MODULE IDENT WHERE content { ($2, $4) }

exp1:
  | LAM telescope COMMA exp1 { cotele eLam $4 $2 }
  | PI telescope COMMA exp1 { cotele ePi $4 $2 }
  | SIGMA telescope COMMA exp1 { cotele eSig $4 $2 }
  | exp2 ARROW exp1 { EPi ((No, $1), $3) }
  | exp2 { $1 }

exp3:
  | HOLE { EHole }
  | SET NAT { ESet $2 }
  | SET { ESet 0 }
  | exp3 FST { EFst $1 }
  | exp3 SND { ESnd $1 }
  | LPARENS exp0 RPARENS { $2 }
  | ident { EVar $1 }

declarations:
  | DEF IDENT   params DEFEQ exp1 { NotAnnotated ($2, cotele eLam $5 $3) }
  | DEF IDENT   params COLON exp1 DEFEQ exp1 { Annotated ($2, cotele ePi $5 $3, cotele eLam $7 $3) }
  | AXIOM IDENT params COLON exp1 { Annotated ($2, cotele ePi $5 $3, EAxiom ($2, cotele ePi $5 $3)) }

line:
  | IMPORT path { Import $2 }
  | OPTION IDENT IDENT { Option ($2, $3) }
  | declarations { Decl $1 }

repl:
  | COLON IDENT exp1 EOF { Command ($2, $3) }
  | COLON IDENT EOF { Action $2 }
  | exp0 EOF { Eval $1 }
  | EOF { Nope }
