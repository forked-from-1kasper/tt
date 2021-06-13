open Error
open Expr
open Eval

let traceCheck (k : int) (e0 : exp) (t0 : value) : unit =
  if !Prefs.trace then (Printf.printf "[%d] CHECK: %s : %s\n" k (showExp e0) (showValue t0); flush_all ()) else ()

let traceInfer (k : int) (e0 : exp) : unit =
  if !Prefs.trace then (Printf.printf "[%d] INFER: %s\n" k (showExp e0); flush_all ()) else ()

let extPiG : value -> value * clos = function
  | VPi (t, g) -> (t, g)
  | u          -> raise (ExpectedPi u)

let extSigG : value -> value * clos = function
  | VSig (t, g) -> (t, g)
  | u           -> raise (ExpectedSig u)

let isVSet : value -> bool = function
  | VKan _ -> true
  | VPre _ -> true
  | _      -> false

let isFibrant : value -> bool = function
  | VKan _ -> true
  | _      -> false

let imax a b = match a, b with
  | VKan u, VKan v -> VKan (max u v)
  | VPre u, VPre v -> VPre (max u v)
  | VPre u, VKan v -> VPre (max u v)
  | VKan u, VPre v -> VPre (max u v)
  | u, v -> ExpectedVSet (if isVSet u then v else u) |> raise

let rec check k (rho : rho) (gma : gamma) (e0 : exp) (t0 : value) : rho * gamma = traceCheck k e0 t0; match e0, t0 with
  | ELam ((p, a), e), VPi (t, g) -> eqNf (eval a rho) t; let gma' = upLocal gma p t in check (k + 1) (upVar rho p (genV p)) gma' e (closByVal g (genV p))
  | EPair (e1, e2), VSig (t, g) -> let _ = check (k + 1) rho gma e1 t in check (k + 1) rho gma e2 (closByVal g (eval e1 rho))
  | EHole, v -> print_string ("\nHole:\n\n" ^ Expr.showGamma gma ^ "\n" ^ String.make 80 '-' ^ "\n" ^ Expr.showValue v ^ "\n\n"); (rho, gma)
  | EAxiom (_, u), v -> eqNf (eval u rho) v; (rho, gma)
  | EKan u, VPre v -> if u + 1 = v then (rho, gma) else raise (TypeIneq (VPre (u + 1), VPre v))
  | e, t -> eqNf t (infer (k + 1) rho gma e); (rho, gma)
and infer k rho gma e0 : value = traceInfer k e0; match e0 with
  | EVar x -> lookup x gma
  | EPre u -> VPre (u + 1)
  | EKan u -> VKan (u + 1)
  | EPi ((p, a), b) -> let v = infer (k + 1) (upVar rho p (genV p)) (upLocal gma p (eval a rho)) b in imax (infer (k + 1) rho gma a) v
  | ESig (x, y) -> infer (k + 1) rho gma (EPi (x, y))
  | EApp (f, x) -> let (t, g) = extPiG (infer (k + 1) rho gma f) in ignore (check (k + 1) rho gma x t); closByVal g (eval x rho)
  | EFst e -> fst (extSigG (infer (k + 1) rho gma e))
  | ESnd e -> let (_, g) = extSigG (infer (k + 1) rho gma e) in closByVal g (vfst (eval e rho))
  | EAxiom (_, e) -> eval e rho
  | e -> raise (InferError e)