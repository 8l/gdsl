
%name Spec;

%tokens
   : KW_andalso ("andalso")
   | KW_case ("case")
   | KW_do ("do")
   | KW_datatype ("datatype")
   | KW_decode ("decode")
   | KW_include ("include")
   | KW_extend ("extend")
   | KW_div ("div")
   | KW_else ("else")
   | KW_end ("end")
   | KW_if ("if")
   | KW_let ("let")
   | KW_mod ("%")
   | KW_of ("of")
   | KW_orelse ("orelse")
   | KW_otherwise ("otherwise")
   | KW_granularity ("granularity")
   | KW_raise ("raise")
   | KW_state ("state")
   | KW_then ("then")
   | KW_type ("type")
   | KW_rec ("rec")
   | ASSIGN (":=")
   | DOT (".")
   | TICK ("'")
   | HASH ("#")
   | DS ("$")
   | LP ("(")
   | RP (")")
   | LB ("[")
   | RB ("]")
   | LCB ("{")
   | RCB ("}")
   | LTEQ ("<=")
   | LT ("<")
   | NEQ ("<>")
   | GTEQ (">=")
   | GT (">")
   | DCOLON ("::")
   | AT ("@")
   | CONCAT ("^")
   | PSUB ("!")
   | PLUS ("+")
   | MINUS ("-")
   | TIMES ("*")
   | SLASH ("/")
   | BACKSLASH ("\\")
   | EQ ("=")
   | TILDE ("~")
   | COMMA (",")
   | SEMI (";")
   | BAR ("|")
   | COLON (":")
   | SEAL (":>")
   | ARROW ("->")
   | DARROW ("=>")
   | WILD ("_")
   | NDWILD ("?")
   | PCHOICE ("|?|")
   | AMP ("&")
   | BITSTR of string
   | SELECT of Atom.atom
   | TYVAR of Atom.atom
   | ID of Atom.atom
   | QID of (Atom.atom list) * Atom.atom
   | POSINT of IntInf.int (* positive integer *)
   | NEGINT of IntInf.int (* negative integer *)
   | FLOAT of FloatLit.float
   | STRING of string
   | SYMBOL of Atom.atom
   ;

%defs (
   structure PT = SpecParseTree

   (* apply a mark constructor to a span and a tree *)
   fun mark cons (span : AntlrStreamPos.span, tr) = cons{span = span, tree = tr}

   (* specialize mark functions for common node types *)
   val markDecl = mark PT.MARKdecl
   fun markExp (_, e as PT.MARKexp _) = e
     | markExp (sp, tr) = mark PT.MARKexp (sp, tr)
   val markMatch = mark PT.MARKmatch
   fun markPat (_, p as PT.MARKpat _) = p
     | markPat (sp, tr) = mark PT.MARKpat (sp, tr)

   (* construct conditional expressions for a list of expressions *)
   fun mkCondExp con = let
      fun mk (e, []) = e
        | mk (e, e'::r) = mk (con(e', e), r)
   in
      mk
   end

   (* build an application for an infix binary operator *)
   fun mkBinApp (e1, rator, e2) = PT.BINARYexp(e1, rator, e2)

   (* construct application expressions for left-associative binary operators *)
   fun mkLBinExp (e, []) = e
     | mkLBinExp (e, (id, e')::r) = mkLBinExp (mkBinApp(e, id, e'), r)

   (* construct application expressions for right-associative binary operators *)
   fun mkRBinExp (e, []) = e
     | mkRBinExp (e, [(id, e')]) = mkBinApp(e, id, e')
     | mkRBinExp (e, (id, e')::r) = mkBinApp(e, id, mkRBinExp(e', r))

   (* turn a list of expressions into a tree of applications; remember that
    * application associates to the left. *)
   fun mkApply (e, []) = e
     | mkApply (e, e'::r) = mkApply (PT.APPLYexp(e, e'), r)
);

Program
   : Decl (";"? Decl)*
      => ({span=FULL_SPAN, tree=Decl::SR})
   ;

Decl
   : "granularity" "=" Int => (markDecl (FULL_SPAN, PT.GRANULARITYdecl Int))
   | "include" STRING => (markDecl (FULL_SPAN, PT.INCLUDEdecl STRING))
   | "state" "=" StateTy => (markDecl (FULL_SPAN, PT.STATEdecl StateTy))
   | TypeDecl => (markDecl (FULL_SPAN, PT.TYdecl TypeDecl))
   | ValueDecl => (markDecl (FULL_SPAN, PT.VALUEdecl ValueDecl))
   | DecodeDecl => (markDecl (FULL_SPAN, PT.DECODEdecl DecodeDecl))
   ;

StateTy
   : "{" Name ":" Ty "=" Exp ("," Name ":" Ty "=" Exp)* "}" =>
      ((Name, Ty, Exp)::SR)
   ;

DecodeDecl
   : "decode" "[" DecodePat+ "]" pat=
      ( "=" Exp =>
         (mark PT.MARKdecodedecl (FULL_SPAN, PT.DECODEdecodedecl (DecodePat, Exp)))
      | ("|" Exp "=" Exp)+ =>
         (mark PT.MARKdecodedecl (FULL_SPAN, PT.GUARDEDdecodedecl (DecodePat, SR)))) =>
      (pat)
   | Name "[" DecodePat+ "]" "=" Exp =>
      (mark PT.MARKdecodedecl (FULL_SPAN, PT.NAMEDdecodedecl (Name, DecodePat, Exp)))
   ;

ValueDecl
   : "let" Name Name* "=" Exp =>
      (mark PT.MARKvaluedecl (FULL_SPAN, PT.LETvaluedecl (Name1, Name2, Exp)))
   ;

TypeDecl
   : "datatype" Name "=" ConDecls =>
      (mark PT.MARKtydecl (FULL_SPAN, PT.DATATYPEtydecl (Name, ConDecls)))
   | "type" Name "=" Ty =>
      (mark PT.MARKtydecl (FULL_SPAN, PT.TYPEtydecl (Name, Ty)))
   ;

ConDecls
   : ConDecl ("|" ConDecl)* => (ConDecl::SR)
   ;

ConDecl
   : Name ("of" Ty)? => (mark PT.MARKcondecl (FULL_SPAN, PT.CONdecl (Name, SR)))
   ;

Ty
   : Int => (mark PT.MARKty (FULL_SPAN, PT.BITty Int))
   | Qid => (mark PT.MARKty (FULL_SPAN, PT.NAMEDty Qid))
   | "{" Name ":" Ty ("," Name ":" Ty)* "}" =>
      (mark PT.MARKty (FULL_SPAN, PT.RECty ((Name, Ty)::SR)))
   ;

DecodePat
   : BitPat => (BitPat)
   | TokPat => (mark PT.MARKdecodepat (FULL_SPAN, PT.TOKENdecodepat TokPat))
   ;

BitPat
   : "'" PrimBitPat+ "'" =>
      (mark PT.MARKdecodepat (FULL_SPAN, PT.BITdecodepat PrimBitPat))
   ;

TokPat
   : Int => (mark PT.MARKtokpat (FULL_SPAN, PT.TOKtokpat Int))
   | Name => (mark PT.MARKtokpat (FULL_SPAN, PT.NAMEDtokpat Name))
   ;

PrimBitPat
   : BITSTR => (mark PT.MARKbitpat (FULL_SPAN, PT.BITSTRbitpat BITSTR))
   | Name ":" POSINT => (mark PT.MARKbitpat (FULL_SPAN, PT.NAMEDbitpat (Name, POSINT)))
   ;

Exp
   : ClosedExp => (ClosedExp)
   | "case" ClosedExp "of" Cases =>
      (mark PT.MARKexp (FULL_SPAN, PT.CASEexp (ClosedExp, Cases)))
   ;

ClosedExp
   : OrElseExp
   | "if" Exp "then" Exp "else" Exp =>
      (mark PT.MARKexp (FULL_SPAN, PT.IFexp (Exp1, Exp2, Exp3)))
   | "raise" Exp =>
      (mark PT.MARKexp (FULL_SPAN, PT.RAISEexp Exp))
   | "do" Exp ";" (Exp ";")+ =>
      (mark PT.MARKexp (FULL_SPAN, PT.SEQexp (Exp::SR)))
   ;

(* HACK *)
Cases
   : %try Pat ":" ClosedExp "|" Cases =>
      (mark PT.MARKmatch (Pat_SPAN, PT.CASEmatch (Pat, ClosedExp))::Cases)
   | %try Pat ":" Exp =>
      ([mark PT.MARKmatch (FULL_SPAN, PT.CASEmatch (Pat, Exp))])
   ;

Pat
   : "'" BITSTR "'" => (mark PT.MARKpat (FULL_SPAN, PT.BITpat BITSTR))
   | "_" => (mark PT.MARKpat (FULL_SPAN, PT.WILDpat))
   | Lit => (mark PT.MARKpat (FULL_SPAN, PT.LITpat Lit))
   | Name => (mark PT.MARKpat (FULL_SPAN, PT.IDpat {span=FULL_SPAN, tree=([], Op.uminus)}))
   ;

OrElseExp
   : AndAlsoExp ("orelse" AndAlsoExp)* =>
      (mark PT.MARKexp (FULL_SPAN, mkCondExp PT.ORELSEexp (AndAlsoExp, SR)))
   ;

AndAlsoExp
   : RExp ("andalso" RExp)* =>
      (mark PT.MARKexp (FULL_SPAN, mkCondExp PT.ANDALSOexp (RExp, SR)))
   ;

RExp
   : AExp (Sym AExp)* =>
      (mark PT.MARKexp (FULL_SPAN, mkLBinExp(AExp, SR)))
   ;

AExp
   : MExp (( "+" => (Op.plus) | "-" => (Op.minus) ) MExp => (SR, MExp))* =>
      (mark PT.MARKexp (FULL_SPAN, mkLBinExp (MExp, SR)))
   ;

MExp
   : ApplyExp
      (( "*" => (Op.times)
       | "div" => (Op.div)
       | "%" => (Op.mod)) ApplyExp =>
      (SR, ApplyExp))* =>
         (mark PT.MARKexp (FULL_SPAN, mkLBinExp (ApplyExp, SR)))
   ;

ApplyExp
   : AtomicExp AtomicExp* =>
      (mark PT.MARKexp (FULL_SPAN, mkApply(AtomicExp1, AtomicExp2)))
   | "~" AtomicExp =>
      (mark PT.MARKexp (FULL_SPAN, PT.APPLYexp (PT.IDexp {span=FULL_SPAN, tree=([], Op.uminus)}, AtomicExp)))
   ;

(* TODO: let bindings *)
AtomicExp
   : Lit => (mark PT.MARKexp (FULL_SPAN, PT.LITexp Lit))
   | Qid => (mark PT.MARKexp (FULL_SPAN, PT.IDexp Qid))
   | "(" ")" => (mark PT.MARKexp (FULL_SPAN, PT.RECORDexp []))
   | "(" Exp ")" => (Exp)
   | "{" Name "=" Exp ("," Name "=" Exp)* "}" =>
      (mark PT.MARKexp (FULL_SPAN, PT.RECORDexp ((Name, Exp)::SR)))
   ;

Lit
   : Int => (PT.INTlit Int)
   | STRING => (PT.STRlit STRING)
   ;

Int
   : POSINT => (POSINT)
   | NEGINT => (NEGINT)
   ;

Name
   : ID => (ID)
   ;

Sym
   : SYMBOL => (SYMBOL)
   ;

Qid
   : QID => ({span=FULL_SPAN, tree=QID})
   | ID => ({span=FULL_SPAN, tree=([], ID)})
   ;
