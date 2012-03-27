
structure DesugaredTree = struct

   structure Exp = Core.Exp
   type sym = Core.sym

   structure Pat = struct
      datatype t =
         VEC of string
       | BND of sym * int
   end

   type value = Exp.decl
   type decode = Pat.t list list * Exp.t
   type spec = (value list * decode list SymMap.map) Spec.t

   (** Returns the size in bits of the given pattern `pat` *)
   fun size pat =
      case pat of
         Pat.VEC str => String.size str
       | Pat.BND (_, i) => i

   fun toWildcardPattern tokpat = let
      fun lp (pats, acc) =
         case pats of
            [] => acc
          | p::ps =>
               case p of
                  Pat.VEC str => lp (ps, acc^str)
                | Pat.BND (_, i) =>
                     lp (ps,
                         acc^String.implode (List.tabulate (i, fn _ => #".")))
   in
      lp (tokpat, "")
   end

   fun toVec xs = VectorSlice.full (Vector.fromList xs)

   structure FromAST = struct
      structure CM = CompilationMonad
      structure Pat = Core.Pat
      open SpecAbstractTree

      fun recdecl (n, ns, e) = (n, ns, exp e)

      and exp e = 
         case e of
            MARKexp t => exp (#tree t)
          | LETRECexp (vs, e) => Exp.LETREC (map recdecl vs, exp e)
          | IFexp (iff, thenn, elsee) => Exp.IF (exp iff, exp thenn, exp elsee)
          | CASEexp (e, cases) => Exp.CASE (exp e, map match cases)
          | BINARYexp (l, i, r) =>
               Exp.APP
                  (Exp.APP
                     (infixop i,
                      exp l),
                   exp r)
          | APPLYexp (e1, e2) => Exp.APP (exp e1, exp e2)
          | RECORDexp fs => Exp.RECORD (fields fs)
          | SELECTexp f => Exp.SELECT f
          | UPDATEexp fs => Exp.UPDATE (fields fs)
          | LITexp l => Exp.LIT l
          | CONexp c => Exp.CON c
          | SEQexp seq => Exp.SEQ (map seqexp seq)
          | IDexp id => Exp.ID id
          | FNexp _ => raise CM.CompilationError

      and infixop e =
         case e of
            MARKinfixop t => infixop (#tree t)
          | OPinfixop binop => Exp.ID binop

      and fields fs = map (fn (f, e) => (f, exp e)) fs

      and match (p, e) = (pat p, exp e)

      and pat p =
         case p of
            MARKpat t => pat (#tree t)
          | CONpat (s, p) => Pat.CON (s, Option.map pat p)
          | LITpat (INTlit i) => Pat.INT i
          | LITpat (VEClit i) => Pat.BIT i
          | LITpat _ => raise CM.CompilationError
          | IDpat id => Pat.ID id
          | WILDpat => Pat.WILD

      and seqexp s = 
         case s of
            MARKseqexp t => seqexp (#tree t)
          | ACTIONseqexp e => Exp.ACTION (exp e)
          | BINDseqexp (n, e) => Exp.BIND (n, exp e)
   end

   structure PP = struct
      open Layout Pretty Sum

      val var = Core.PP.var
      val exp = Core.PP.layout

      fun declarations (vs, ds) =
         align
            [align (map Core.PP.recdecl vs),
             align (decs ds)]

      and decs ds =
         List.map
            (fn (n, ds) => align (map (fn d => dec (n, d)) ds))
            (SymMap.listItemsi ds)

      and dec (n, (ps, e)) =
         align
            [seq
               [str "val", space, var n,
                list (map tokpat ps), space, str "="],
             indent 3 (exp e)]

      and tokpat pats = listex "'" "'" " " (map pat pats)
      and pat t =
         case t of
            Pat.VEC bits => str bits
          | Pat.BND (n, i) => seq [var n, str ":", str (Int.toString i)]

      val spec = Spec.PP.spec declarations
   end
end
