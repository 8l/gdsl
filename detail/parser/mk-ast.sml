
signature AST_CORE = sig
   type ty_bind
   type ty_use
   type syn_bind
   type syn_use
   type con_bind
   type con_use
   type var_bind
   type var_use
   type field_bind
   type field_use
   type op_id
   val var_bind: var_bind -> Layout.layout
   val var_use: var_use -> Layout.layout
   val ty_bind: ty_bind -> Layout.layout
   val ty_use: ty_use -> Layout.layout
   val syn_bind: syn_bind -> Layout.layout
   val syn_use: syn_use -> Layout.layout
   val con_bind: con_bind -> Layout.layout
   val con_use: con_use -> Layout.layout
   val field_bind: field_bind -> Layout.layout
   val field_use: field_use -> Layout.layout
   val op_id: op_id -> Layout.layout
end

functor MkAst (Core: AST_CORE) = struct
   (* a term marked with a source-map span *)
   type 'a mark = 'a Error.mark

   type ty_bind = Core.ty_bind
   type ty_use = Core.ty_use
   type syn_bind = Core.syn_bind
   type syn_use = Core.syn_use
   type con_bind = Core.con_bind
   type con_use = Core.con_use
   type var_bind = Core.var_bind
   type var_use = Core.var_use
   type field_bind = Core.field_bind
   type field_use = Core.field_use
   type op_id = Core.op_id

   datatype decl =
      MARKdecl of decl mark
    | INCLUDEdecl of string
    | GRANULARITYdecl of IntInf.int
    | STATEdecl of (var_bind * ty * exp) list
    | TYPEdecl of syn_bind * ty
    | DATATYPEdecl of con_bind * (con_bind * ty option) list
    | DECODEdecl of var_bind * decodepat list * (exp, (exp * exp) list) Sum.t
    | LETRECdecl of var_bind * var_bind list * exp
    | EXPORTdecl of var_use list

   and ty =
      MARKty of ty mark
    | BITty of IntInf.int
    | NAMEDty of syn_use
    | RECORDty of (field_bind * ty) list

   and exp =
      MARKexp of exp mark
    | LETRECexp of (var_bind * var_bind list * exp) list * exp
    | IFexp of exp * exp * exp
    | CASEexp of exp * (pat * exp) list
    | BINARYexp of exp * op_id * exp 
    | APPLYexp of exp * exp
    | RECORDexp of (field_bind * exp) list
    | SELECTexp of field_use 
    | UPDATEexp of (field_bind * exp) list (* functional record update "@{a=a'} *)
    | LITexp of lit
    | SEQexp of seqexp list (* monadic sequence *)
    | IDexp of var_use 
    | CONexp of con_use (* constructor *)
    | FNexp of var_bind * exp 

   and seqexp =
      MARKseqexp of seqexp mark
    | ACTIONseqexp of exp
    | BINDseqexp of var_bind * exp

   and decodepat =
      MARKdecodepat of decodepat mark
    | TOKENdecodepat of tokpat
    | BITdecodepat of bitpat list

   and bitpat =
      MARKbitpat of bitpat mark
    | BITSTRbitpat of string
    | NAMEDbitpat of var_use
    | BITVECbitpat of var_bind * IntInf.int

   and tokpat =
      MARKtokpat of tokpat mark
    | TOKtokpat of IntInf.int
    | NAMEDtokpat of var_use

   and pat =
      MARKpat of pat mark
    | LITpat of lit
    | IDpat of var_bind
    | CONpat of con_use * pat option
    | WILDpat

   and lit =
      INTlit of IntInf.int
    | FLTlit of FloatLit.float
    | STRlit of string
    | VEClit of string

   type specification = decl list mark

   structure PP = struct
      open Layout Pretty Core

      fun spec (ss:specification) = align (map decl (#tree ss))

      and decl t =
         case t of
            MARKdecl t' => decl (#tree t')
          | INCLUDEdecl inc => seq [str "include", space, str inc]
          | GRANULARITYdecl i => seq [str "granularity", space, int i]
          | EXPORTdecl es =>
               seq [str "export", space, seq (separate (map var_use es, " "))]
          | STATEdecl fs =>
               let
                  fun field (n, t, e) =
                     seq [lb, var_bind n, str ":", ty t, str "=", exp e]
               in
                  align
                     [str "state",
                      indent 3 (list (map field fs))]
               end
          | TYPEdecl (t, tyexp) =>
               seq [str "type", space, syn_bind t, space, ty tyexp]
          | DATATYPEdecl (t, decls) =>
               align
                  [seq [str "datatype", space, con_bind t],
                   indent 3 (alignPrefix (map condecl decls, "| "))]
          | DECODEdecl (n, args, Sum.INL e) =>
               align
                  [seq
                     [str "val", space, var_bind n, space,
                      seq (separate (map decodepat args, " ")), space, str "="],
                   indent 3 (exp e)]
          | DECODEdecl (n, args, Sum.INR ges) =>
               align
                  [seq
                     [str "val", space, var_bind n, space,
                      seq (separate (map decodepat args, " ")), space, str "="],
                   indent 3
                     (alignPrefix
                        (map
                           (fn (e1, e2) =>
                              seq [exp e1, space, str "=", space, exp e2])
                           ges,
                         "| "))]
          | LETRECdecl d => recdecl d

      and decodepat t =
         case t of
            MARKdecodepat t' => decodepat (#tree t')
          | BITdecodepat bp => list (map bitpat bp)
          | TOKENdecodepat tp => tokpat tp

      and bitpat t =
         case t of
            MARKbitpat t' => bitpat (#tree t')
          | BITSTRbitpat s => str s
          | NAMEDbitpat n => var_use n
          | BITVECbitpat tybp => tuple2 (var_bind, int) tybp

      and tokpat t =
         case t of
            MARKtokpat t' => tokpat (#tree t')
          | TOKtokpat tok => str (IntInf.fmt StringCvt.HEX tok)
          | NAMEDtokpat n => var_use n

      and guardedexp gexp = tuple2 (exp, exp) gexp

      and condecl (n, tyOpt) =
         case tyOpt of
            NONE => con_bind n
          | SOME t => seq [con_bind n, space, ty t]

      and ty t =
         case t of
            MARKty t' => ty (#tree t')
          | BITty i => int i
          | NAMEDty alias => Core.syn_use alias
          | RECORDty fields => list (map (tuple2 (field_bind, ty)) fields)

      and pat t =
         case t of
            MARKpat t' => pat (#tree t')
          | LITpat l => lit l
          | IDpat n => var_bind n
          | CONpat (n, SOME p) => seq [con_use n, space, pat p]
          | CONpat (n, _) => con_use n
          | WILDpat => str "_"

      and lit t =
         case t of
            INTlit i => int i
          | FLTlit f => str (FloatLit.toString f)
          | STRlit s => str s
          | VEClit s => seq [str "'", str s, str "'"]

      and exp t =
         case t of
            MARKexp t' => exp (#tree t')
          | LETRECexp (ds, e) =>
               align
                  [align [str "let", indent 3 (align (map recdecl ds))],
                   align [str "in", indent 3 (exp e)]]
          | IFexp (iff, thenn, elsee) =>
               align
                  [align
                     [seq [str "if", space, exp iff],
                      indent 3 (align [str "then", indent 3 (exp thenn)])],
                   align [str "else", indent 3 (exp elsee)]]
          | CASEexp (e, cs) =>
               align
                  [seq [str "case", space, exp e, str "of"],
                   indent 3 (alignPrefix (map casee cs, "| "))]
          | BINARYexp (e1, opid, e2) =>
               seq [op_id opid, space, exp e1, space, exp e2]
          | APPLYexp (e1, e2) => seq [exp e1, space, exp e2]
          | RECORDexp fs => listex "{" "}" "," (map field fs)
          | SELECTexp f => seq [str "$", field_use f]
          | UPDATEexp fs => seq [str "@", listex "{" "}" "," (map field fs)]
          | LITexp l => lit l
          | SEQexp ss =>
               align
                  [align
                     [str "do",
                      indent 3 (align (separateRight (map seqexp ss, ";")))],
                   str "end"]
          | IDexp id => var_use id
          | CONexp con => seq [str "`", con_use con]
          | FNexp (x, e) => seq [str "\\", var_bind x, str ".", exp e]

      and recdecl (n, args, e) =
         align
            [seq
               [str "rec", space,
                var_bind n,
                seq (separate (map var_bind args, " ")), space, str "="],
             indent 3 (exp e)]  

      and seqexp t =
         case t of
            MARKseqexp t' => seqexp (#tree t')
          | ACTIONseqexp act => exp act
          | BINDseqexp (n, e) =>
               seq [var_bind n, space, str "<-", space, exp e]

      and field (n, e) = seq [field_bind n, str "=", exp e]

      and casee (p, e) =
         align
            [seq [pat p, space, str ":"],
             indent 3 (exp e)]

      and def (nameAndArgs, body) = align [nameAndArgs, indent 2 body]

      val pretty = Pretty.pretty o spec
      fun prettyTo (os, t) = Pretty.prettyTo (os, spec t)
   end
end
