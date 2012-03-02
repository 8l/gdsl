
structure StringMap = struct
   structure Key = struct
      open String
      type ord_key = string
   end
   structure Map = RedBlackMapFn(Key)
   open Map
end

structure SpecDesugaredTree = struct
   structure T = SpecAbstractTree
   datatype dec =
      TOPdec of tokpat list * guarded
    | NAMEDdec of var_use * tokpat list * exp

   and pat =
      BITSTRpat of string
    | BINDpat of var_use * int

   withtype tokpat = pat list
   and guarded = (T.exp, (T.exp * T.exp) list) Sum.t
   and var_use = T.var_use
   and exp = T.exp

   (** Returns the size in bits of the given pattern `pat` *)
   fun size pat =
      case pat of
         BITSTRpat str => String.size str
       | BINDpat (_, i) => i

   fun toWildcardPattern tokpat = let
      fun lp (pats, acc) =
         case pats of
            [] => acc
          | p::ps =>
               case p of
                  BITSTRpat str => lp (ps, acc^str)
                | BINDpat (_, i) =>
                     lp (ps,
                         acc^String.implode (List.tabulate (i, fn _ => #".")))
   in
      lp (tokpat, "")
   end

   fun toVec xs = VectorSlice.full (Vector.fromList xs)

   fun grabToplevel decls = let
      fun lp (decls, acc) =
         case decls of
            [] => rev acc
          | (TOPdec (toks, e))::ds => lp (ds, (toVec toks, e)::acc)
          | d::ds => lp (ds, acc)
   in
      toVec (lp (decls, []))
   end

   structure PP = struct
      open Layout Pretty Sum
      fun dec t = 
         case t of
            TOPdec (pats, guarded) =>
                T.PP.def
                  (seq [str "DECODE", space, list (map tokpat pats)],
                   seq [str "[",
                        guardedexp guarded,
                        str "]"])
          | NAMEDdec (name, pats, e) =>
               T.PP.def
                  (seq [str "DECODE", space, T.PP.var_bind name, space,
                        list (map tokpat pats)],
                   exp e)
      and guardedexp e =
       case e of
          INL e => exp e
        | INR es => alignPrefix (map T.PP.guardedexp es, ",")
      and exp e = T.PP.exp e
      and tokpat pats = listex "'" "'" " " (map pat pats)
      and pat t =
         case t of
            BITSTRpat bits => str bits
          | BINDpat (n, i) =>
                seq [T.PP.var_use n, str ":", str (Int.toString i)]
      val spec = list o map dec
      val pretty = Pretty.pretty o spec
      fun prettyTo (os, t) = Pretty.prettyTo (os, spec t)
   end
end

structure DesugarControl = struct
   val (registry, debug) =
      BasicControl.newRegistryWithDebug
         {name="desugar",
          pri=9,
          help="controls for the desugaring phases"}
end

structure Detokenize : sig
   val run:
      SpecAbstractTree.specification ->
         SpecDesugaredTree.dec list CompilationMonad.t
end = struct

   structure CM = CompilationMonad
   structure DT = SpecDesugaredTree
   structure AT = struct
      open SpecAbstractTree
      fun grabDecodeDecls spec = let 
         fun lp (spec, acc) =
            case spec of
               (MARKdecl t::ss) => lp(#tree t::ss, acc)
             | (DECODEdecl dec::ss) => lp(ss, dec::acc)
             | _::ss => lp(ss, acc)
             | [] => rev acc
      in
         lp (spec, [])
      end
   end

   open AT DT

   val granularity = 8 

   fun detokenize dec =
      case dec of
         MARKdecodedecl t => detokenize (#tree t)
       | NAMEDdecodedecl (name, pats, exp) =>
             NAMEDdec (name, detokenizeDecodePats pats, exp)
       | DECODEdecodedecl (pats, exp) =>
             TOPdec (detokenizeDecodePats pats, Sum.INL exp)
       | GUARDEDdecodedecl (pats, exps) =>
             TOPdec (detokenizeDecodePats pats, Sum.INR exps)

   and detokenizeDecodePats pats = map detokenizeDecodePat pats

   and detokenizeDecodePat pat =
      case pat of
         MARKdecodepat t => detokenizeDecodePat (#tree t)
       | TOKENdecodepat pat => detokenizeTokPat pat
       | BITdecodepat pats => map detokenizeBitPat pats

   and detokenizeTokPat pat =
      case pat of
         MARKtokpat t => detokenizeTokPat (#tree t)
       | TOKtokpat pat =>
            let
               (* XXX: this should be `granularity` dependend *)
               val bitstr =
                  IntInf.fmt
                     StringCvt.BIN
                     (IntInf.andb
                        (IntInf.orb (pat, 0x100),
                      0x1ff))
            in
               [BITSTRpat (String.substring (bitstr, 0, 8))]
            end
       | _ => raise CM.CompilationError

   and detokenizeBitPat pat =
      case pat of
         MARKbitpat t => detokenizeBitPat (#tree t)
       | BITSTRbitpat pat => BITSTRpat pat
       | BITVECbitpat (n, i) => BINDpat (n, IntInf.toInt i)
       | _ => raise CM.CompilationError

   fun dumpPre (os, spec) = AT.PP.prettyTo (os, spec)
   fun dumpPost (os, spec) = DT.PP.prettyTo (os, spec)

   fun pass {span, tree} = let
      val decodedecls = AT.grabDecodeDecls tree
   in
      map detokenize decodedecls
   end

   val pass =
      BasicControl.mkKeepPass
         {passName="detokenizeDecodePatterns",
          registry=DesugarControl.registry,
          pass=pass,
          preExt="ast",
          preOutput=dumpPre,
          postExt="ast",
          postOutput=dumpPost}

   fun run spec = let
      open CompilationMonad
      infix >>=
   in
      return (pass spec)
   end
end

structure Retokenize : sig
   val run:
      SpecDesugaredTree.dec list ->
         SpecDesugaredTree.dec list CompilationMonad.t
end = struct

   structure CM = CompilationMonad
   structure DT = SpecDesugaredTree
   open DT

   val granularity = 8 

   fun retokenize pat =
      case pat of
         NAMEDdec (n, pats, e) => NAMEDdec (n, retokenizePats pats, e)
       | TOPdec (pats, e) => TOPdec (retokenizePats pats, e)

   and retokenizePats pats = let
      fun lp (p, len, tok, pats) =
         case p of
            [] =>
               if len <> 0 orelse List.length tok <> 0
                  then raise CM.CompilationError 
               else rev pats
          | p::ps =>
               (case p of
                  [p] =>
                     let
                        val sz = DT.size p
                     in
                        if (sz + len) mod granularity = 0
                           then lp (ps, 0, [], (rev (p::tok))::pats)
                        else lp (ps, sz + len, p::tok, pats)
                     end
                | _ => raise CM.CompilationError)
   in
      lp (pats, 0, [], [])
   end

   fun dumpPre (os, spec) = DT.PP.prettyTo (os, spec)
   fun dumpPost (os, spec) = DT.PP.prettyTo (os, spec)
   fun pass decls = map retokenize decls

   val pass =
      BasicControl.mkKeepPass
         {passName="retokenizeDecodePatterns",
          registry=DesugarControl.registry,
          pass=pass,
          preExt="ast",
          preOutput=dumpPre,
          postExt="ast",
          postOutput=dumpPost}

   fun run spec = let
      open CompilationMonad
      infix >>=
   in
      return (pass spec)
   end
end

structure DesugarToplevel : sig
   val run:
      SpecDesugaredTree.dec list ->
         SpecDesugaredTree.exp CompilationMonad.t
end = struct

   structure VS = VectorSlice
   structure CM = CompilationMonad
   structure DT = SpecDesugaredTree
   structure Set = IntRedBlackSet

   open DT

   val granularity = 8 

   fun insert (map, k, i) = let
      val s =
         case StringMap.find (map, k) of
            NONE => Set.singleton i
          | SOME s => Set.add (s, i)
   in
      StringMap.insert (map, k, s)
   end

   val tok = Atom.atom "tok"
   val consume = Atom.atom "consume"

   fun freshTok () = let
      val (tab, sym) =
         VarInfo.create (!SymbolTables.varTable, tok, VarInfo.noSpan)
   in
      sym before SymbolTables.varTable := tab
   end

   fun buildEquivClass decls = let
      fun buildEquiv (i, toks, map) =
         insert (map, toWildcardPattern (VS.sub (toks, 0)), i)
   in
      VS.foldli buildEquiv StringMap.empty decls
   end

   fun desugar decls = let
     val topdecls = grabToplevel decls
   in
      DT.T.SEQexp []
   end

   and desugarCases decls = let
      val equiv = buildEquivClass decls
      val empty = DT.T.SEQexp []
   in
      empty 
   end

   and consumeTok () = let
      val tok = freshTok()
      val consume =
       DT.T.IDexp
         (VarInfo.lookup
            (!SymbolTables.varTable, consume))
   in
      DT.T.BINDseqexp (tok, consume)
   end

   fun dumpPre (os, spec) = DT.PP.prettyTo (os, spec)
   fun dumpPost (os, exp) = Pretty.prettyTo (os, DT.T.PP.exp exp)
   fun pass decls = desugar decls

   val pass =
      BasicControl.mkKeepPass
         {passName="desugarToplevelDecodeDeclarations",
          registry=DesugarControl.registry,
          pass=pass,
          preExt="ast",
          preOutput=dumpPre,
          postExt="ast",
          postOutput=dumpPost}

   fun run spec = let
      open CompilationMonad
      infix >>=
   in
      return (pass spec)
   end
end

structure DesugarDecodePatterns : sig
   val run:
      SpecAbstractTree.specification ->
         SpecDesugaredTree.exp CompilationMonad.t
end = struct

   structure CM = CompilationMonad
   structure DT = SpecDesugaredTree
   structure AT = SpecAbstractTree

   open CM
   infix >>=

   fun all s = 
      Detokenize.run s >>=
      Retokenize.run >>=
      DesugarToplevel.run

   fun dumpPre (os, (_, spec)) = AT.PP.prettyTo (os, spec)
   fun dumpPost (os, exp) = Pretty.prettyTo (os, DT.T.PP.exp exp)
   fun pass (s, spec) = CM.run s (all spec)

   val desugar =
      BasicControl.mkKeepPass
         {passName="desugarDecodePatterns",
          registry=DesugarControl.registry,
          pass=pass,
          preExt="ast",
          preOutput=dumpPre,
          postExt="ast",
          postOutput=dumpPost}

   fun run spec =
      getState >>= (fn s =>
      return (desugar (s, spec)))
end
