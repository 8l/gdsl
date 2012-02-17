
(**
 * ## Inlining of decode patterns.
 *
 *   - Inline named decode patterns into all use-sites.
 *   - Introducue a top-level monadic action using the named patterns
 *     right-hand sides
 *   - Insert calls to the monadic action into the rhs expression of
 *     all use-sites of the pattern
 *)
structure InlineDecodePatterns : sig
   val run: SpecParseTree.specification -> SpecParseTree.specification
end = struct

   structure Map = AtomMap
   structure T = SpecParseTree

   datatype t =
      IN of {namedpatterns: (T.decodepat list * T.exp) Map.map,
             decodedecls: T.decodedecl list}

   val empty = IN {namedpatterns=Map.empty, decodedecls= []}
   fun get s (IN t) = s t
   fun insert t k v =
      IN
         {namedpatterns= Map.insert (get#namedpatterns t, k, v),
          decodedecls= []}

   (* traverse the specification and collect all "named" patterns *)
   fun grabNamedPatterns spec = let
      open T
      fun grabFromDecodeDecl (decl, t) =
         case decl of
            MARKdecodedecl decl' => grabFromDecodeDecl (#tree decl', t)
          | NAMEDdecodedecl (name, pats, exp) => insert t name (pats, exp)
          | _ => t
      fun grabFromDecl (decl, t) =
         case decl of
            MARKdecl decl' => grabFromDecl (#tree decl', t)
          | DECODEdecl decode => grabFromDecodeDecl (decode, t)
          | _ => t
   in
      foldl grabFromDecl empty spec
   end

   fun flattenDecodePatterns t spec = let
      open T
      val map = ref (get#namedpatterns t)

      fun inline (x, exp) =
         (* TODO: handle recursive decode patterns *)
         case Map.find (!map, #tree x) of
            NONE => raise Fail "Unbound pattern reference"
          | SOME (pats, exp') =>
               let
                  val ps =
                     flattenDecodePats
                        (pats,
                         SEQexp [ACTIONseqexp exp', ACTIONseqexp exp])
               in
                  map := Map.insert (!map, #tree x, ps)
                 ;ps
               end

      and flattenTokPat (tokpat, exp) =
         case tokpat of
            MARKtokpat t' => flattenTokPat (#tree t', exp)
          | NAMEDtokpat x => inline (x, exp)
          | _ => ([TOKENdecodepat tokpat], exp)

      and flattenBitPat (bitpat, exp) =
         case bitpat of
            MARKbitpat t' => flattenBitPat (#tree t', exp)
          | NAMEDbitpat x => inline (x, exp)
          | _ => ([BITdecodepat [bitpat]], exp)

      and flattenDecodePat (decodepat, exp) =
         case decodepat of
            MARKdecodepat t' => flattenDecodePat (#tree t', exp)
          | TOKENdecodepat tokpat => flattenTokPat (tokpat, exp)
          | BITdecodepat bitpats =>
               let
                  fun lp (bitpats, exp, acc) =
                     case bitpats of
                        [] => (List.concat acc, exp)
                      | b::bs =>
                           let
                              val (ps, exp) = flattenBitPat (b, exp)
                           in
                              lp (bs, exp, ps::acc)
                           end
               in
                  lp (rev bitpats, exp, [])
               end

      and flattenDecodePats (pats, exp) = let
         fun lp (pats, exp, acc) =
            case pats of
               [] => (List.concat acc, exp)
             | p::ps =>
                  let
                     val (inlinedPats, exp) = flattenDecodePat (p, exp)
                  in
                     lp (ps, exp, inlinedPats::acc)
                  end
      in
         lp (rev pats, exp, [])
      end

      and flattenDecodeDecl decodedecl =
         case decodedecl of
            MARKdecodedecl t' => flattenDecodeDecl (#tree t')
          | DECODEdecodedecl decl => DECODEdecodedecl (flattenDecodePats decl)
          | GUARDEDdecodedecl (pats, cases) =>
               let
                  val (pats, inlineExp) = flattenDecodePats (pats, SEQexp [])
                  fun lp (cases, acc) =
                     case cases of
                        [] => rev acc
                      | (guard, exp)::cs =>
                           lp (cs,
                               (guard,
                                (SEQexp
                                    [ACTIONseqexp inlineExp,
                                     ACTIONseqexp exp]))::acc)
               in
                  GUARDEDdecodedecl (pats, lp (cases, []))
               end
          | otherwise => otherwise

      and flattenDecl decl =
         case decl of
            MARKdecl t' => flattenDecl (#tree t')
          | DECODEdecl decl => DECODEdecl (flattenDecodeDecl decl)
          | otherwise => otherwise

   in
      List.map flattenDecl spec
   end

   fun inlineDecodePatterns ({span, tree}:SpecParseTree.specification) = let
      val t = grabNamedPatterns tree
      val inlined = flattenDecodePatterns t tree
   in
      {span=span, tree=inlined}
   end

   val run =
      BasicControl.mkTracePassSimple
         {passName="inlineDecodePatterns",
          pass=inlineDecodePatterns}
end