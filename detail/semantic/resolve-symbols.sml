
(**
 * ## Resolve Symbols
 *
 * Annotate AST with symbol identifiers.
 *)
structure ResolveSymbols : sig
   val run:
      SpecParseTree.specification ->
         SpecAbstractTree.specification CompilationMonad.t
   val startScope : unit -> unit
end = struct

   structure PT = SpecParseTree
   structure AST = SpecAbstractTree
   structure VI = VarInfo
   structure FI = FieldInfo
   structure CI = ConInfo
   structure TI = TypeInfo
   structure ST = SymbolTables

   exception NotImplemented

   infix >>= >>

   type specialize_map =
      ({ uses : SymSet.set, forwards : AtomSet.set} AtomMap.map) SymMap.map
   
   fun smapToString sm =
      let
         fun showAtomMap am =
            List.foldl (fn ((a,{uses=us, forwards=fs}), str) =>
               "\n  var " ^ Atom.toString a ^ ": " ^
               List.foldl (fn (sym,str) => str ^
                  SymbolTable.getString(!SymbolTables.varTable, sym) ^ ", ")
                  "" (SymSet.listItems us) ^
               "forwarded by " ^
               List.foldl (fn (a,str) => Atom.toString a ^ ", " ^ str)
                  "" (AtomSet.listItems fs) ^
               str
            ) "" (AtomMap.listItemsi am)
      in
         List.foldl (fn ((sym,am),str) => str ^
            "\ndecoder " ^ SymbolTable.getString(!SymbolTables.varTable, sym) ^
            showAtomMap am) "" (SymMap.listItemsi sm)
      end
   
   fun resolveErr errStrm (pos, msg) = Error.errorAt(errStrm, (pos, pos), msg)
   val parseErr = Error.parseError SpecTokens.toString
   fun convMark conv {span, tree} = {span=span, tree=conv span tree}
   fun startScope () = ST.varTable := VI.push (!ST.varTable)
   fun endScope () = ST.varTable := VI.pop (!ST.varTable)
   fun startScopeRefs refs = ST.varTable := VI.pushWithReferences (!ST.varTable, refs)
   fun endScopeRefs () = let val (st,refs) = VI.popWithReferences (!ST.varTable)
                         in (ST.varTable := st; refs) end

   fun resolveSymbolPass (errStrm, ast) = let

      fun newSym (table, create, lookup, str) (span, atom) = let
         val (newTable, id) = create (!table, atom, span)
      in
         (table := newTable; id)
      end
         handle SymbolAlreadyDefined =>
            (Error.errorAt
               (errStrm,
                span,
                ["duplicate ", str, " declaration ", Atom.toString(atom)])
            ;lookup (!table, atom))

      val newVar = newSym (ST.varTable, VI.create, VI.lookup, "variable")
      val newCon = newSym (ST.conTable, CI.create, CI.lookup, "constructor")
      val newType = newSym (ST.typeTable, TI.create, TI.lookup, "type")
      val newTSyn = newSym (ST.typeTable, TI.create, TI.lookup, "type synonym")

      fun newField (span, atom) = let
         val (newTable, id) = FI.create (!ST.fieldTable, atom, span)
      in
         (ST.fieldTable := newTable; id)
      end
         handle SymbolAlreadyDefined =>
            FI.lookup (!ST.fieldTable, atom)

      fun useSym (table, create, find, str) (_, {tree=atom, span}) =
         case find (!table, atom) of
            SOME id => id
          | NONE =>
               (Error.errorAt
                  (errStrm,
                   span,
                   [str, " '", Atom.toString(atom), "' is not defined "])
               ;let
                  val (newTable, id) = create (!table, atom, span)
                in
                  (table := newTable; id)
                end)

      val useVar = useSym (ST.varTable, VI.create, VI.find, "variable")
      val useCon = useSym (ST.conTable, CI.create, CI.find, "constructor")
      val useType = useSym (ST.typeTable, TI.create, TI.find, "type")

      fun useField (_, {tree=atom, span}) = let
         val (newTable, id) = FI.create (!ST.fieldTable, atom, span)
      in
         (ST.fieldTable := newTable; id)
      end
         handle SymbolAlreadyDefined =>
            FI.lookup (!ST.fieldTable, atom)

      (* define a first traversal that registers:
       *   - type synonyms
       *   - datatype declarations including constructors
       *   - toplevel val bindings
       *   - bitpat var binding per decoder
       *   - uses of specializing variable in each decoder
       *)
      val specDec = ref (SymMap.empty : specialize_map)
      
      type patternVarMap = (SymbolTable.references SpanMap.map) SymMap.map
      
      val patternVarRef = ref (SymMap.empty : patternVarMap)

      fun regDecl s decl =
         case decl of
            PT.MARKdecl {span, tree} => regDecl span tree
          | PT.DECODEdecl (n, pats, wc, _) => regDecode (s, n, pats, wc)
          | PT.LETRECdecl (n, _, _) => ignore (newVar (s,n))
          | PT.DATATYPEdecl (n, ds) => (regTy s n; app (regCon s) ds)
          | PT.TYPEdecl (n, _) => regTy s n 
          | _ => ()

      and regTy s n =
         case VI.find (!ST.typeTable, n) of
            NONE => ignore (newType (s, n))
          | _ => ()

      and regCon s (c, _) = ignore (newCon (s, c))

      and regDecode (s, n, pats, wc) =
         let
            val decSymId = case VI.find (!ST.varTable, n) of
                  NONE => newVar (s, n)
                | SOME id => id
            val _ = startScope ()
            val am = case SymMap.find (!specDec, decSymId) of
                  SOME am => am
                | NONE => AtomMap.empty
            val am = List.foldl (regDecodepat s) am pats
            val am = List.foldl (regWithclause s) am wc
            val _ = specDec := SymMap.insert (!specDec, decSymId, am)
            val refs = endScopeRefs ()
            val pV = !patternVarRef
            val sM = case SymMap.find (pV, decSymId) of
                        SOME sM => sM
                      | NONE => SpanMap.empty
            val sM = SpanMap.insert (sM,s,refs)
            val pV = SymMap.insert (pV,decSymId,sM)
          in
             (patternVarRef := pV; ())
         end

      and regDecodepat s (d,am) =
         case d of
            PT.MARKdecodepat {span, tree} => regDecodepat span (tree,am)
          | PT.TOKENdecodepat pat => regToken s (pat,am)
          | PT.BITdecodepat pats => List.foldl (regBitpat s) am pats

      and regWithclause s (d,am) =
         case d of
            PT.MARKwithclause {span, tree} => regWithclause span (tree,am)
          | PT.WITHwithclause (v,bits) =>
               AtomMap.insert (am, v, case AtomMap.find (am,v) of
                        SOME {uses=us, forwards=fs} =>
                           {uses=SymSet.add (us,newVar (s,v)), forwards=fs}
                      | NONE => {uses = SymSet.singleton (newVar (s,v)),
                                 forwards = AtomSet.empty})

      and regBitpat s (d,am) =
         case d of
            PT.MARKbitpat {span, tree} => regBitpat span (tree,am)
          | PT.BITVECbitpat (v,_) =>
               AtomMap.insert (am, v, case AtomMap.find (am,v) of
                        SOME {uses=us, forwards=fs} =>
                           {uses=SymSet.add (us,newVar (s,v)), forwards=fs}
                      | NONE => {uses = SymSet.singleton (newVar (s,v)),
                                 forwards = AtomSet.empty})
          | _ => am

      and regToken s (d,am) =
         case d of
            PT.MARKtokpat {span, tree} => regToken span (tree,am)
          | PT.TOKtokpat _ => am
          | PT.NAMEDtokpat ({span, tree=decName},sps) =>
            let
               fun fwds (PT.MARKspecial {span, tree}, am) = fwds (tree,am)
                 | fwds (PT.BINDspecial _, am) = am
                 | fwds (PT.FORWARDspecial {span, tree=v}, am) =
                   AtomMap.insert (am, v, case AtomMap.find (am,v) of
                            SOME {uses=us, forwards=fs} =>
                               {uses=us, forwards=AtomSet.add (fs,decName)}
                          | NONE => {uses = SymSet.empty,
                                     forwards = AtomSet.singleton decName})
             in
               List.foldl fwds am sps
            end
      (* define a second traversal that is a full translation of the tree *)
      fun convDecl s d =
         case d of
            PT.MARKdecl m => AST.MARKdecl (convMark convDecl m)
          | PT.INCLUDEdecl str => AST.INCLUDEdecl str
          | PT.EXPORTdecl es => AST.EXPORTdecl (map (fn v => useVar (s, v)) es)
          | PT.GRANULARITYdecl i => AST.GRANULARITYdecl i
          | PT.TYPEdecl (tb, t) =>
               AST.TYPEdecl (useType (s,{span=s, tree=tb}), convTy s t)
          | PT.DATATYPEdecl (tb, l) =>
               AST.DATATYPEdecl
                  (useType (s, {span=s, tree=tb}), List.map (convCondecl s) l)
          | PT.DECODEdecl dd => AST.DECODEdecl (convDecodeDecl s dd)
          | PT.LETRECdecl vd => AST.LETRECdecl (convLetrecDecl s vd)

      and convDecodeDecl s d =
         case d of
            (v, ps, wc, Sum.INL e) =>
               let
                  val vSym = VI.lookup (!ST.varTable, v)
                  val sM = SymMap.lookup (!patternVarRef, vSym)
                  val _ = startScopeRefs (SpanMap.lookup (sM,s))

                  val res =
                     (vSym,
                      List.map (convDecodepat s) ps,
                      List.map (convWithclause s) wc,
                      Sum.INL (convExp s e))
                  val _ = endScope ()
               in
                  res
               end
         | (v, ps, wc, Sum.INR es) =>
               let
                  val vSym = VI.lookup (!ST.varTable, v)
                  val sM = SymMap.lookup (!patternVarRef, vSym)
                  val _ = startScopeRefs (SpanMap.lookup (sM,s))
                  val res =
                     (vSym,
                      List.map (convDecodepat s) ps,
                      List.map (convWithclause s) wc,
                      Sum.INR
                        (List.map
                           (fn (e1, e2) => (convExp s e1, convExp s e2))
                           es))
                  val _ = endScope ()
               in
                  res
               end

      and convLetrecDecl s (v, l, e) = let
         val id = VI.lookup (!ST.varTable, v)
         val _ = startScope ()
         val l = List.map (fn v => newVar (s,v)) l
         val e = convExp s e
         val _ = endScope ()
      in
         (id, l, e)
      end

      and convCondecl s (c, to) =
         (useCon (s, {span=s, tree=c}), case to of NONE => NONE | SOME t => SOME (convTy s t))

      and convTy s t =
         case t of
            PT.MARKty m => AST.MARKty (convMark convTy m)
          | PT.BITty i => AST.BITty i
          | PT.NAMEDty n => AST.NAMEDty (useType (s,n))
          | PT.RECORDty fs =>
               AST.RECORDty
                  (List.map (fn (f,t) => (newField (s,f), convTy s t)) fs)

      and convExp s e =
         case e of
            PT.MARKexp m => AST.MARKexp (convMark convExp m)
          | PT.LETRECexp (l, e) =>
               let
                  val _ = startScope ()
                  val _ = List.map (fn (n,_,_) => newVar (s,n)) l
                  val l = List.map (convLetrecDecl s) l
                  val r = convExp s e
                  val _ = endScope ()
               in
                  AST.LETRECexp (l, r)
               end
          | PT.IFexp (iff, thenn, elsee) =>
               AST.IFexp (convExp s iff, convExp s thenn, convExp s elsee)
          | PT.CASEexp (e, l) =>
               AST.CASEexp (convExp s e, List.map (convMatch s) l)
          | PT.BINARYexp (e1, opid, e2) =>
               AST.BINARYexp
                  (convExp s e1, convInfixop s opid, convExp s e2)
          | PT.APPLYexp (e1,e2) =>
               AST.APPLYexp (convExp s e1, convExp s e2)
          | PT.RECORDexp l =>
               AST.RECORDexp
                  (List.map (fn (f,e) => (newField (s,f), convExp s e)) l)
          | PT.SELECTexp f => AST.SELECTexp (useField (s,f))
          | PT.UPDATEexp fs =>
               AST.UPDATEexp
                  (List.map (fn (f,e) => (newField (s,f), convExp s e)) fs)
          | PT.LITexp lit => AST.LITexp (convLit s lit)
          | PT.SEQexp l => AST.SEQexp (convSeqexp s l)
          | PT.IDexp v => AST.IDexp (useVar (s,v))
          | PT.CONexp c => AST.CONexp (useCon (s,c))
          | PT.FNexp (v, e) => AST.FNexp (newVar (s,v), convExp s e)

      and convInfixop s e =
         case e of
            PT.MARKinfixop m => AST.MARKinfixop (convMark convInfixop m)
          | PT.OPinfixop opid => AST.OPinfixop (useVar (s,{span=s, tree=opid}))

      and convSeqexp s ss =
         case ss of
            [] => []
         | PT.MARKseqexp {span, tree}::l => convSeqexp span (tree :: l)
         | PT.ACTIONseqexp e::l => AST.ACTIONseqexp (convExp s e) :: convSeqexp s l
         | PT.BINDseqexp (v, e)::l =>
               let
                  val rhs = convExp s e
                  val _ = startScope ()
                  val lhs = newVar (s,v)
                  val rem = convSeqexp s l
                  val _ = endScope ()
               in
                  AST.BINDseqexp (lhs, rhs) :: rem
               end

      and convWithclause s wc =
         case wc of
            PT.MARKwithclause m =>
               AST.MARKwithclause (convMark convWithclause m)
          | PT.WITHwithclause (v,bits) =>
               (*note: definition registered earlier*)
               AST.WITHwithclause (VI.lookup (!ST.varTable, v), bits)

      and convDecodepat s p =
         case p of
            PT.MARKdecodepat m => AST.MARKdecodepat (convMark convDecodepat m)
          | PT.TOKENdecodepat t => AST.TOKENdecodepat (convTokpat s t)
          | PT.BITdecodepat l => AST.BITdecodepat (List.map (convBitpat s) l)

      and convBitpat s p =
         case p of
            PT.MARKbitpat m => AST.MARKbitpat (convMark convBitpat m)
          | PT.BITSTRbitpat str => AST.BITSTRbitpat str
          | PT.NAMEDbitpat v => AST.NAMEDbitpat (useVar (s,v))
          (*note: definition registered earlier*)   
          | PT.BITVECbitpat (v,size) => AST.BITVECbitpat (VI.lookup (!ST.varTable, v), size)

      and convTokpat s p =
         case p of
            PT.MARKtokpat m => AST.MARKtokpat (convMark convTokpat m)
          | PT.TOKtokpat i => AST.TOKtokpat i
          | PT.NAMEDtokpat (v,sps) =>
            let
               val errRef = ref false
               fun insBinding bpat (sym,bindings) =
                  if List.exists (fn (s,_) => SymbolTable.eq_symid(s,sym))
                     bindings
                  then
                     (Error.errorAt
                           (errStrm, s,
                            ["recursive specialization with variable ",
                            SymbolTable.getString(!SymbolTables.varTable, sym)])
                     ;errRef := true
                     ;bindings)
                  else
                     (sym,bpat)::bindings
               fun expandBindVar (s,v,am,bpat,bindings) =
                  (TextIO.print ("looking up " ^ Atom.toString(v) ^ "\n")
                  ;case AtomMap.find (am,v) of
                     NONE => 
                        (Error.warningAt
                           (errStrm, s,
                            ["specialization variable ", Atom.toString(v),
                            " never used"])
                        ;[])
                   | SOME {uses = uf, forwards = fs} =>
                     List.foldl (expandFwdVar (s,v,bpat))
                        (List.foldl
                           (insBinding bpat)
                           bindings
                           (SymSet.listItems uf)
                        )
                        (AtomSet.listItems fs)
                  )
               and expandFwdVar (s,v,bpat) (decName,bindings) =
                  let
                     val decNameSymId = useVar(s,{tree=decName,span=s})
                     val am = case SymMap.find (!specDec,decNameSymId) of
                        NONE => AtomMap.empty
                      | SOME am => am
                  in
                     if !errRef then bindings else
                        expandBindVar (s,v,am,bpat,bindings)
                  end

               val decSymId = useVar (s,v)
               val am = case SymMap.find (!specDec,decSymId) of
                     NONE => AtomMap.empty
                   | SOME am => am
               fun convSpecial (p,bindings) =
                  case p of
                     PT.MARKspecial {tree, span} => convSpecial (tree,bindings)
                   | PT.BINDspecial ({tree=v, span=s},bpat) =>
                     expandBindVar (s,v,am,bpat,bindings)
                   | PT.FORWARDspecial v => []
               val bindings = List.foldl convSpecial [] sps
            in
               AST.NAMEDtokpat (decSymId, List.map AST.BINDspecial bindings)
            end
      
      and convMatch s (p, e) =
         let
            val _ = startScope ()
            val p = convPat s p
            val e = convExp s e
            val _ = endScope ()
         in
            (p,e)
         end
      and convPat s p = 
         case p of
            PT.MARKpat m => AST.MARKpat (convMark convPat m)
          | PT.LITpat lit => AST.LITpat (convLit s lit)
          | PT.IDpat v => AST.IDpat (newVar (s,v))
          | PT.CONpat (c, SOME p) => AST.CONpat (useCon (s,c), SOME (convPat s p))
          | PT.CONpat (c, NONE) => AST.CONpat (useCon (s,c), NONE)
          | PT.WILDpat => AST.WILDpat

      and convLit s l =
         case l of
            PT.INTlit i => AST.INTlit i
          | PT.FLTlit f => AST.FLTlit f
          | PT.STRlit str => AST.STRlit str
          | PT.VEClit str => AST.VEClit str

   in
      (Primitives.registerPrimitives ()
      ;convMark (fn s => List.map (regDecl s)) ast
      ;TextIO.print (smapToString (!specDec))
      ;convMark (fn s => List.map (convDecl s)) ast)
   end

   val resolveSymbolPass =
      BasicControl.mkTracePassSimple
         {passName="resolveSymbols",
          pass=resolveSymbolPass}

   fun run spec = let
      open CompilationMonad
   in
      getErrorStream >>= (fn errs =>
      return (resolveSymbolPass (errs, spec)))
   end
end
