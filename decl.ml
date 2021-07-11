open Module
open Check
open Error
open Ident
open Expr
open Elab

let ext x = x ^ ".anders"

type state = ctx * Files.t
let empty : state = (Env.empty, Files.empty)

let getDeclName : decl -> string = function Def (p, _, _) | Axiom (p, _) -> p
let getTerm e ctx = if !preeval then Value (eval e ctx) else Exp e

let checkDecl ctx d : ctx =
  let x = getDeclName d in if Env.mem (name x) ctx then
    raise (AlreadyDeclared x);
  match d with
  | Def (p, Some a, e) ->
    ignore (extSet (infer ctx a));
    let t = eval a ctx in let v = name p in
    check (upGlobal ctx v t (Var (v, t))) e t;
    Env.add (name p) (Global, Value t, getTerm e ctx) ctx
  | Def (p, None, e) ->
    Env.add (name p) (Global, Value (infer ctx e), getTerm e ctx) ctx
  | Axiom (p, a) ->
    ignore (extSet (infer ctx a)); let x = name p in
    let t = eval a ctx in Env.add x (Global, Value t, Value (Var (x, t))) ctx

let getBoolVal opt = function
  | "tt" | "true"  -> true
  | "ff" | "false" -> false
  | value -> raise (UnknownOptionValue (opt, value))

let rec checkLine st : line -> state =
  let (ctx, checked) = st in function
  | Decl d ->
    if !Ident.verbose then Printf.printf "Checking: %s\n" (getDeclName d); flush_all ();
    (checkDecl ctx (freshDecl d), checked)
  | Option (opt, value) ->
    begin match opt with
      | "girard"   -> girard  := getBoolVal opt value
      | "verbose"  -> verbose := getBoolVal opt value
      | "pre-eval" -> preeval := getBoolVal opt value
      | _          -> raise (UnknownOption opt)
    end; st
  | Import xs -> List.fold_left (fun st x -> let path = ext x in
    if Files.mem path checked then st else checkFile st path) st xs
and checkFile p path =
  let (ctx, checked) = p in
  let filename = Filename.basename path in
  let chan = open_in path in
  let (name, con) = Reader.parseErr Parser.file (Lexing.from_channel chan) in
  close_in chan; if !Ident.verbose then Printf.printf "Parsed “%s” successfully.\n" filename; flush_all ();
  if ext name = filename then ()
  else raise (InvalidModuleName (name, filename));
  let res = checkContent (ctx, Files.add path checked) con in
  if !Ident.verbose then Printf.printf "File loaded.\n"; res
and checkContent st xs = List.fold_left checkLine st xs
