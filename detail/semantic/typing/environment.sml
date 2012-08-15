structure Environment : sig
   type environment

   structure SpanMap : ORD_MAP where type Key.ord_key = Error.span

   structure SymbolSet : ORD_SET where type Key.ord_key = SymbolTable.symid
   
   val primitiveEnvironment : (SymbolTable.symid *
                               Types.texp *
                               (BooleanDomain.bfun -> BooleanDomain.bfun) *
                               (Types.texp option)) list *
                               SizeConstraint.size_constraint list ->
                               environment
   
   val pushSingle : VarInfo.symid * Types.texp * environment -> environment
   
   (*add a group of bindings to the current environment, each element in a
   binding is identified by its symbol, the flag is true if the symbol
   is a decoder function*)
   val pushGroup : (VarInfo.symid * bool) list * environment ->
                  environment
   (*remove a binding group from the stack; the flag is true if the outermost
   scope should be kept, the result is a list of error messages about
   ambiguous type variables*)
   val popGroup : environment * bool ->
                  (Error.span * string) list * environment
   
   (*ask for all the symbols in the binding group*)
   val getGroupSyms : environment -> VarInfo.symid list
   
   val pushTop : environment -> environment
   
   (*pushes the given type onto the stack, if the flag is true, type variables
   are renamed*)
   val pushType : bool * Types.texp * environment -> environment

   val pushMonadType : Types.texp * environment -> environment
   
   (* push the width of a decode onto the stack*)
   val pushWidth : VarInfo.symid * environment -> environment

   (* For a function from a type containing several type variables to an
   algoebraic data type, generate implications from the arguments of the
   algebraic data type to the argument of this function. *)
   val genConstructorFlow : (bool * environment) -> environment
   
    (*given an occurrence of a symbol at a position, push its type onto the
    stack; arguments are the symbol to look up, the position it occurred and a
    Boolean flag indicating if this usage should be recorded (True) or if an
    existing type should be used (False) *)
   val pushSymbol : VarInfo.symid * Error.span * bool * environment -> environment

   (*like pushSymbol, but also checks nested definitions that have already
   been type checked, a usage is never recorded; returns the number of
   frames that have been pushed before the symbol was pushed*)
   val pushSymbolNested : VarInfo.symid * Error.span * environment ->
      (int * environment)

   val getUsages : VarInfo.symid * environment -> Error.span list
   
   val getContextOfUsage : VarInfo.symid * Error.span * environment ->
                           VarInfo.symid

   val getCtxt : environment -> VarInfo.symid list

      (*stack: [...,t] -> [...] and type of f for call-site s is set to t*)
   val popToUsage : VarInfo.symid * Error.span * environment -> environment

   (*stack: [...] -> [...,t] where t is type of usage of f at call-site s*)
   val pushUsage : VarInfo.symid * Error.span * environment -> environment
   
   (*stack: [...] -> [..., x:a], 'a' fresh; primed version also returns 'a'*)
   val pushLambdaVar' : VarInfo.symid * environment -> (Types.texp * environment)
   val pushLambdaVar : VarInfo.symid * environment -> environment
   
   (*stack: [..., t0, t1, ... tn] -> [..., {f1:t1, ... fn:tn, t0:...}]*)
   val reduceToRecord : (BooleanDomain.bvar * FieldInfo.symid) list *
                        environment -> environment

   (*stack: [..., tn, ..., t2, t1, t0] -> [..., SUM (tn,..t0)]*)
   val reduceToSum : int * environment -> environment
   
   (*stack: [...,t1,t2,...,tn] -> [...,(t1, ... t n-1) -> tn]*)
   val reduceToFunction : environment * int -> environment
   
   (*stack: [...,t1 -> t2] -> [...t2]*)
   val reduceToResult : environment -> environment

   (*stack: [..., tn, ..., t2, t1, t0] -> [..., t0]*)
   val return : int * environment -> environment

   val popKappa : environment -> environment

   (*stack: [...,t] -> [...] and type of function f is set to t*)
   val popToFunction : VarInfo.symid * environment -> environment

   (*push the name of the function into the current context (the context
   determines in which function calls to unknown functions are recorded)*)
   val enterFunction : VarInfo.symid * environment -> environment

   (*pop the name of the given function from the current context*)
   val leaveFunction : VarInfo.symid * environment -> environment
   
   (*unset the type of function f, if the function type was set, return an
   environment in which the function type was pushed*)
   val clearFunction : VarInfo.symid * environment ->
         environment option * environment
   
   val forceNoInputs : VarInfo.symid * VarInfo.symid list *
                     environment -> VarInfo.symid list

    (*apply the Boolean function*)
   val meetBoolean : (BooleanDomain.bfun -> BooleanDomain.bfun) *
         environment -> environment

   val meetSizeConstraint : (SizeConstraint.size_constraint_set ->
                             SizeConstraint.size_constraint_set) *
                             environment -> environment

   val meetFlow : environment * environment -> environment
   val meet : environment * environment -> environment

   (*returns the set of substitutions for the first environment, this is empty
   if the the first environment is more specific (smaller) than the second*)
   val subseteq : environment * environment -> Substitutions.Substs

   (*query all function symbols in binding groups that would be modified by
   the given substitutions*)
   val affectedFunctions : Substitutions.Substs * environment -> SymbolSet.set

   val toString : environment -> string
   val toStringSI : environment * TVar.varmap -> string * TVar.varmap
   val topToString : environment -> string
   val topToStringSI : environment * TVar.varmap -> string * TVar.varmap
   val kappaToString : environment -> string
   val kappaToStringSI : environment * TVar.varmap -> string * TVar.varmap
   val funTypeToStringSI  : environment * VarInfo.symid * TVar.varmap ->
                            string * TVar.varmap
end = struct
   structure ST = SymbolTable
   structure BD = BooleanDomain
   structure SC = SizeConstraint
   structure SpanMap = SpanMap
   open Types
   open Substitutions

   (*any error that is not due to unification*)
   exception InferenceBug
   
   datatype binding
      = KAPPA of {
         ty : texp
      } | SINGLE of {
         name : ST.symid,
         ty : texp
      } | GROUP of {
         name : ST.symid,
         (*the type of this function, NONE if not yet known*)
         ty : (texp * BD.bfun) option,
         (*this is SOME (CONST w) if this is a decode function with pattern width w*)
         width : texp option,
         uses : (ST.symid * texp) SpanMap.map,
         (*a tree of nested binding groups*)
         nested : binding list
      } list
   
   datatype bind_info
      = SIMPLE of { ty : texp }
      | COMPOUND of { ty : (texp * BD.bfun) option, width : texp option,
                      uses : (ST.symid * texp) SpanMap.map,
                      nested : binding list }

   (*a scope contains one of the bindings above and some additional
   information that make substitution and join cheaper*)
   structure Scope : sig
      type scope
      type constraints
      val getFlow : constraints -> BooleanDomain.bfun
      val setFlow : BooleanDomain.bfun -> constraints -> constraints
      val getSize : constraints -> SC.size_constraint_set
      val setSize : SC.size_constraint_set -> constraints -> constraints
      val getCtxt : constraints -> VarInfo.symid list
      val getCurFun : constraints -> VarInfo.symid
      val setCtxt : VarInfo.symid list -> constraints -> constraints

      type environment = scope list * constraints
      val initial : binding * SC.size_constraint_set -> environment
      val wrap : binding * environment -> environment
      val wrapWithVars : binding * TVar.set * environment ->
                         environment
      val unwrap : environment -> (binding * environment)
      val unwrapDifferent : environment * environment ->
            (binding * binding) option * environment * environment
      val getVars : environment -> TVar.set
      val getBVars : environment -> BD.bvarset
      val getVarsUses : ST.symid * environment -> TVar.set * BD.bvarset
      val getMonoVars : environment -> TVar.set * BD.bvarset
      val lookup : ST.symid * environment -> TVar.set * bind_info
      val update : ST.symid  *
                   (bind_info * constraints -> bind_info * constraints) *
                   environment-> environment
      val toString : scope * TVar.varmap -> string * TVar.varmap
   end = struct
      type scope = {
         bindInfo : binding,
         typeVars : TVar.set,
         boolVars : BD.bvarset,
         version : int
      }
      type constraints = {
         flowInfo : BD.bfun,
         sizeInfo : SC.size_constraint_set,
         context : VarInfo.symid list
      }
      
      fun getFlow { flowInfo = fi, sizeInfo, context } = fi
      fun setFlow fi { flowInfo = _, sizeInfo = si, context = ctxt } =
         { flowInfo = fi, sizeInfo = si, context = ctxt }
      fun getSize { flowInfo, sizeInfo = si, context } = si
      fun setSize si { flowInfo = fi, sizeInfo = _, context = ctxt } =
         { flowInfo = fi, sizeInfo = si, context = ctxt }
      fun getCtxt { flowInfo, sizeInfo, context = ctxt } = ctxt
      fun getCurFun { flowInfo, sizeInfo, context = ctxt } = case ctxt of
           (curFun :: _) => curFun
         | [] => raise InferenceBug
      fun setCtxt ctxt { flowInfo = fi, sizeInfo = si, context = _ } =
         { flowInfo = fi, sizeInfo = si, context = ctxt }

      type environment = scope list * constraints
   
      val verCounter = ref 1
      fun nextVersion () =  let
           val v = !verCounter
         in
           (verCounter := v+1; v)
         end             

      fun prevTVars [] = TVar.empty
        | prevTVars ({bindInfo, typeVars = tv, boolVars, version}::_) = tv

      fun varsOfBinding (KAPPA {ty=t}, set) = texpVarset (t,set)
        | varsOfBinding (SINGLE {name, ty=t}, set) = texpVarset (t,set)
        | varsOfBinding (GROUP bs, set) = let
           fun vsOpt (SOME t,set) = texpVarset (t,set)
             | vsOpt (NONE,set) = set
           fun bvsOpt (SOME (t,_),set) = texpVarset (t,set)
             | bvsOpt (NONE,set) = set
           fun getUsesVars ((ctxt',t),set) = texpVarset (t,set)
           fun getBindVars ({name=n, ty=t, width=w, uses, nested},set) =
               List.foldl getUsesVars
                  (bvsOpt (t, vsOpt (w,set)))
                  (SpanMap.listItems uses)
        in
           List.foldl getBindVars set bs
        end

      fun prevBVars [] = BD.emptySet
        | prevBVars ({bindInfo, typeVars, boolVars = bv, version}::_) = bv

      val texpBVarset = texpBVarset (fn ((_,v),vs) => BD.addToSet (v,vs))

      fun bvarsOfBinding (KAPPA {ty}, ctxt, set) = texpBVarset (ty,set)
        | bvarsOfBinding (SINGLE {name, ty}, ctxt, set) = texpBVarset (ty,set)
        | bvarsOfBinding (GROUP bs, ctxt, set) =
         let
            fun getUsesVars ((site,t),set) =
               if List.exists (fn sym => ST.eq_symid (sym,site)) ctxt then
                  texpBVarset (t,set)
               else
                  set
            fun getBindVars ({name=n, ty=tOpt, width, uses, nested},set) =
               List.foldl getUsesVars
                  (if List.exists (fn sym => ST.eq_symid (sym,n)) ctxt
                   then case tOpt of
                     NONE => set | SOME (t,_) => texpBVarset (t,set)
                   else set)
                  (SpanMap.listItems uses)

         in
            List.foldl getBindVars set bs
         end

      fun getMonoVars (bis,_) = List.foldl
        (fn ({bindInfo = bi, typeVars, boolVars, version},(vSet,bSet)) => 
         case bi of
              KAPPA { ty = t } => (texpVarset (t,vSet), texpBVarset (t,bSet))
            | SINGLE { ty = t,... } => (texpVarset (t,vSet), texpBVarset (t,bSet))
            | GROUP _ => (vSet,bSet))
        (TVar.empty, BD.emptySet) bis

      fun getVarsUses (sym, (scs,_)) =
         let
            fun getUsesVars ((site,t),(vSet,bSet)) =
               if ST.eq_symid (sym,site) then
                  (texpVarset (t,vSet), texpBVarset (t,bSet))
               else
                  (vSet,bSet)
            fun getWidthVars (NONE, set) = set
              | getWidthVars (SOME w, (vSet,bSet)) = (texpVarset (w,vSet),bSet)
            fun getBindVars ({name, ty, width = wOpt, uses, nested},set) =
               List.foldl getUsesVars (getWidthVars (wOpt, set))
                  (SpanMap.listItems uses)
            fun getGroupVars ({bindInfo = bi, typeVars, boolVars, version},set) =
               case bi of
                    KAPPA {ty} => set
                  | SINGLE {name, ty} => set
                  | GROUP bs => List.foldl getBindVars set bs
         in
            List.foldl getGroupVars (TVar.empty, BD.emptySet) scs
         end

      fun initial (b, scs) =
         ([{
            bindInfo = b,
            typeVars = varsOfBinding (b, TVar.empty),
            boolVars = BD.emptySet,
            version = 0
          }], {
            flowInfo = BD.empty,
            sizeInfo = scs,
            context = []
          })
      fun wrap (b, (scs, state)) =
         ({
            bindInfo = b,
            typeVars = varsOfBinding (b, prevTVars scs),
            boolVars = bvarsOfBinding (b, getCtxt state, prevBVars scs),
            version = nextVersion ()
         }::scs,state)
      fun wrapWithVars (b, tVars, (scs, state)) =
         ({
            bindInfo = b,
            typeVars = (*varsOfBinding (b, prevTVars scs)*)tVars,
            boolVars = bvarsOfBinding (b, getCtxt state, prevBVars scs),
            version = nextVersion ()
         }::scs,state)
      fun unwrap ({bindInfo = bi, typeVars, boolVars, version} :: scs, state) =
            (bi, (scs, state))
        | unwrap ([], state) = raise InferenceBug
      fun unwrapDifferent
            ((all1 as ({bindInfo = bi1, typeVars = _, boolVars = _, version = v1 : int}::scs1,
             cons1))
            ,(all2 as ({bindInfo = bi2, typeVars = _, boolVars = _, version = v2 : int}::scs2,
             cons2))) =
            if v1=v2 then (NONE, all1, all2)
            else (SOME (bi1,bi2),(scs1,cons1),(scs2,cons2))
        | unwrapDifferent (all1 as ([], _), all2 as ([], _)) =
            (NONE, all1, all2)
        | unwrapDifferent (_, _) = raise InferenceBug
      
      fun getVars (scs, state) = prevTVars scs

      fun getBVars (scs, state) = prevBVars scs

      fun lookup (sym, (scs, cons)) =
         let
            fun l [] = (TextIO.print ("urk, tried to lookup non-existent symbol " ^ SymbolTable.getString(!SymbolTables.varTable, sym) ^ "\n")
                       ;raise InferenceBug)
              | l ({bindInfo = KAPPA _, typeVars, boolVars, version}::scs) = l scs
              | l ({bindInfo = SINGLE {name, ty}, typeVars, boolVars, version}::scs) =
                  if ST.eq_symid (sym,name) then
                     (prevTVars scs, SIMPLE { ty = ty})
                  else l scs
              | l ({bindInfo = GROUP bs, typeVars, boolVars, version}::scs) =
                  let fun lG other [] = l scs
                        | lG other ((b as {name, ty, width, uses, nested})::bs) =
                           if ST.eq_symid (sym,name) then
                              (prevTVars scs,
                              COMPOUND { ty = ty, width = width, uses = uses, nested = nested })
                           else lG (b :: other) bs
                  in
                     lG [] bs
                  end
         in
            l scs
         end

      fun update (sym, action, env) =
         let
            fun tryUpdate (KAPPA _, cons) = NONE
              | tryUpdate (SINGLE {name, ty}, cons) =
                if ST.eq_symid (sym,name) then
                  let
                     val (SIMPLE {ty}, cons) = action (SIMPLE {ty = ty}, cons)
                  in
                     SOME (SINGLE {name = name, ty = ty}, cons)
                  end
                else NONE
              | tryUpdate (GROUP bs, cons) =
               let fun upd (otherBs, []) = NONE
                     | upd (otherBs, (b as {name, ty, width, uses, nested})::bs) =
                        if ST.eq_symid (sym,name) then
                           let val (COMPOUND { ty = ty, width = width,
                                               uses = uses, nested = nested}, cons) =
                                   action (COMPOUND { ty = ty, width = width,
                                                      uses = uses, nested = nested}, cons)
                           in
                              SOME (GROUP (List.revAppend (otherBs,
                                          {name = name, ty = ty,
                                           width = width, uses = uses,
                                           nested = nested} :: bs))
                                   ,cons)
                           end
                        else upd (b::otherBs, bs)
               in
                  upd ([],bs)
               end
            fun unravel (bs, env) = case unwrap env of
               (b, env as (scs, cons)) =>
                  (case tryUpdate (b, cons) of
                       NONE => unravel (b::bs, env)
                     | SOME (b,cons) => List.foldl wrap (scs, cons) (b::bs) )
         in
            unravel ([], env)
         end

      fun showVarsVer (typeVars,boolVars,ver,si) =
         let
            val (vsStr, si) = TVar.setToString (typeVars,si)
            val bsStr = BD.setToString boolVars
         in
            ("ver=" ^ Int.toString(ver) ^
             (*", bvars = " ^ bsStr ^ *) ", vars=" ^ vsStr ^ "\n", si)
         end

      fun toString ({bindInfo = bi, typeVars, boolVars, version}, si) =
            let
               val (scStr, si) = showVarsVer (typeVars, boolVars, version, si)
               val (biStr, si) = showBindInfoSI (bi,si)
            in
               (scStr ^ biStr, si)
            end
      and showBindInfoSI (KAPPA {ty}, si) =
            let
               val (tStr, si) = showTypeSI (ty,si)
            in
               ("KAPPA : " ^ tStr, si)
            end
        | showBindInfoSI (SINGLE {name, ty}, si) =
            let
               val (tStr, si) = showTypeSI (ty,si)
            in
               ("SYMBOL " ^ ST.getString(!SymbolTables.varTable, name) ^
                " : " ^ tStr, si)
            end
        | showBindInfoSI (GROUP bs, si) =
            let
               fun prTyOpt (NONE, str, si) = ("", si)
                 | prTyOpt (SOME t, str, si) = let
                    val (tStr, si) = showTypeSI (t, si)
                 in
                     (str ^ tStr, si)
                 end
               fun prBTyOpt (NONE, str, si) = ("", si)
                 | prBTyOpt (SOME (t,bFun), str, si) = let
                    val (tStr, si) = showTypeSI (t, si)
                    val bStr = if concisePrint then "" else
                               ", flow:" ^ BD.showBFun bFun
                 in
                     (str ^ tStr ^ bStr, si)
                 end
               fun printU (({span=(p1,p2),file=_}, (ctxt, t)), (str, sep, si)) =
                  let
                     val (tStr, si) = showTypeSI (t, si)
                  in
                     (str ^
                      sep ^ Int.toString(Position.toInt p1) ^
                      "-" ^ Int.toString(Position.toInt p2) ^
                      "@" ^ ST.getString(!SymbolTables.varTable, ctxt) ^
                      ":" ^ tStr
                     ,"\n\tuse at ", si)
                  end
               fun printB ({name,ty,width,uses,nested}, (str, si)) =
                  let
                     val (tStr, si) = prBTyOpt (ty, " : ", si)
                     val (wStr, si) = prTyOpt (width, ", width = ", si)
                     val (uStr, _, si) = 
                           List.foldl printU ("", "\n\tuse at ", si)
                                      (SpanMap.listItemsi uses)
                     fun showBindInfosSI n (b :: bs,si) =
                        let
                           val (bStr, si) = showBindInfoSI (b,si)
                           fun spaces n = if n<=0 then "" else "  " ^ spaces (n-1)
                           val sStr = spaces n
                           val (bsStr, si) = showBindInfosSI (n+1) (bs, si)
                           val fs1 = Substring.fields (fn c => c= #"\n") (Substring.full bStr)
                           val fs2 = Substring.fields (fn c => c= #"\n") (Substring.full bsStr)
                        in
                           (List.foldl
                              (fn (f,str) => str ^ sStr ^ Substring.string f ^ "\n")
                              "\n" (fs1 @ fs2),
                            si)
                        end
                       | showBindInfosSI n ([], si) = ("", si)
                     val (nStr, si) = showBindInfosSI 1 (nested,si)
                  in
                    (str ^
                     "\n  " ^ ST.getString(!SymbolTables.varTable, name) ^
                     tStr ^ wStr ^ nStr ^ uStr
                    ,si)
                  end
                val (bsStr, si) = List.foldr printB ("", si) bs
            in
               ("GROUP" ^ bsStr, si)
            end
               
   end
   
   type environment = Scope.environment

   fun primitiveEnvironment (l,scs) = Scope.initial
      (GROUP (List.map (fn (s,t,bFunGen,ow) =>
         {name = s, ty = SOME (t,bFunGen BD.empty),
          width = ow, uses = SpanMap.empty, nested = []}) l),
       scs)
   
   fun pushSingle (sym, t, env) = Scope.wrap (SINGLE {name = sym, ty = t},env)
   
   structure SymbolSet = RedBlackSetFn (
      struct
         type ord_key = SymbolTable.symid
         val compare = SymbolTable.compare_symid
      end)
          
   fun pushGroup (syms, env) = 
      let
         val (funs, nonFuns) = List.partition (fn (s,dec) => not dec) syms
         val funDefs = List.map
            (fn (s,_) => {name = s, ty = NONE, width = NONE,
                          uses = SpanMap.empty, nested = []})
            funs
         val nonFunSyms =
            SymbolSet.listItems (SymbolSet.fromList (List.map (fn (s,_) => s) nonFuns))
         val nonFunDefs = List.map
            (fn s => {name = s, ty = NONE, width =
              SOME (VAR (TVar.freshTVar (), BD.freshBVar ())),
              uses = SpanMap.empty, nested = []}) nonFunSyms
      in                                                                    
         Scope.wrap (GROUP (funDefs @ nonFunDefs), env)
      end                                    

   fun popGroup (env, true) = (case Scope.unwrap env of
        (KAPPA {ty=t}, env) =>
         let
           val (badUses, env) = popGroup (env, false)
         in
            (badUses, Scope.wrap (KAPPA {ty=t}, env))
         end
       | _ => raise InferenceBug)
     | popGroup (env, false) = case Scope.unwrap env of
        (GROUP bs, env) =>
         let
            val remVars = Scope.getVars env
            val (scs, state) = env
            (*figure out if there are any function usages that have unresolved
            type variables that relate to sizes*)
            val curVars = SC.getVarset (Scope.getSize state)
            val unbounded = TVar.difference (curVars,remVars)
            (*val _ = TextIO.print ("unbounded vars: " ^ #1 (TVar.setToString (unbounded,TVar.emptyShowInfo)) ^ "\n")*)
            val siRef = ref TVar.emptyShowInfo
            fun showUse (n, (ctxt,t)) =
               let
                  val nStr = SymbolTable.getString(!SymbolTables.varTable, n)
                  val (tStr, si) = showTypeSI (t, !siRef)
                  val vs = texpVarset (t,TVar.empty)
                  val (cStr, si) = SC.toStringSI (Scope.getSize state, SOME vs, si)
               in
                  (siRef := si
                  ; nStr ^ " : " ^ tStr ^ " has ambiguous vector sizes" ^
                     (if String.size cStr=0 then "" else " where " ^ cStr))
               end
            val unbounded = List.foldl (fn
                  ({name,ty=SOME (t,_),width,uses,nested},vs) =>
                     TVar.difference (vs, texpVarset (t,TVar.empty))
                  | (_,vs) => vs)
                  unbounded bs
            val badSizes = List.concat (
               List.map (fn {name = n,ty,width,uses = us,nested} =>
                  List.map (fn (sp,t) => (sp, showUse (n, t))) (
                     SpanMap.listItemsi (
                        SpanMap.filter (fn (_,t) =>
                           not (TVar.isEmpty (TVar.intersection
                              (texpVarset (t,TVar.empty), unbounded)))
                           ) us))) bs)
            (*project out variables from the size and Boolean domains that are
            no longer needed*)
            val sCons = SC.filter (remVars, Scope.getSize state)
            val env = (scs, Scope.setSize sCons state)
            
            (*in case we are inside a function, store this group in the nested
            field of the function entry*)
            val inScope = SymSet.fromList (Scope.getCtxt state)
            val bs = List.filter
                        (fn {name, ty, width, uses = us, nested} =>
                           List.exists (fn (f,_) => SymSet.member (inScope,f))
                              (SpanMap.listItems us)
                        ) bs
            fun action group (COMPOUND {ty, width, uses, nested},cons) =
               (COMPOUND {ty = ty, width = width,
                uses = uses, nested = group :: nested}, cons)
              | action ns _ = raise InferenceBug
            val env = if List.null bs then env else
               Scope.update (Scope.getCurFun state, action (GROUP bs), env)
         in
            (badSizes, env)
         end
      | _ => raise InferenceBug

   fun getGroupSyms env = case Scope.unwrap env of
        (GROUP bs, env) => List.map #name bs
      | _ => raise InferenceBug

   fun pushTop env = 
      let
         val a = TVar.freshTVar ()
         val b = BD.freshBVar ()
      in
         Scope.wrap (KAPPA {ty = VAR (a,b)}, env)
      end

   fun pushType (true, t, (scs, state)) =
      let
         val (t,bFun,sCons) = instantiateType (TVar.empty,t,TVar.empty,
                                               Scope.getFlow state,
                                               Scope.getSize state)
      in
         (Scope.wrap (KAPPA {ty = t}, (scs, Scope.setSize sCons (
                                             Scope.setFlow bFun state))))
      end
     | pushType (false, t, env) = Scope.wrap (KAPPA {ty = t}, env)

   fun pushMonadType (t, (scs, state)) =
      let
         val tvar = TVar.freshTVar ()
         val fromBVar = BD.freshBVar ()
         val toBVar = BD.freshBVar ()
         val fromVar = VAR (tvar, fromBVar)
         val toVar = VAR (tvar, toBVar)
         val bFun = BD.meetVarImpliesVar (fromBVar, toBVar) (Scope.getFlow state)
         val (t,bFun,sCons) = instantiateType (texpVarset(t,TVar.empty),t,
                                               TVar.empty,
                                               bFun,
                                               Scope.getSize state)
      in
         Scope.wrap (KAPPA {ty = MONAD (t, fromVar, toVar)},
                     (scs, Scope.setSize sCons (Scope.setFlow bFun state)))
      end

   fun pushWidth (sym, env) =
      (case Scope.lookup (sym,env) of
          (_, COMPOUND {ty, width = SOME t, uses, nested}) =>
            Scope.wrap (KAPPA {ty = t}, env)
        | _ => raise (UnificationFailure (
            SymbolTable.getString(!SymbolTables.varTable, sym) ^
            " is not a decoder"))
      )

   exception LookupNeedsToAddUse

   fun eq_span ((p1s,p1e), (p2s,p2e)) =
      Position.toInt p1s=Position.toInt p2s andalso
      Position.toInt p1e=Position.toInt p2e

   fun toStringSI ((scs, state),si) = 
      let
         fun showCons (s, (str, si)) =
            let
               val (bStr, si) = Scope.toString (s, si)
            in
               (bStr ^ "\n" ^ str, si)
            end
         val (sStr, si) = SC.toStringSI (Scope.getSize state, NONE, si)
         val (envConsStr, si) =
            List.foldr showCons ("sizes: " ^ sStr ^ "\n", si) scs
         fun showCtxt [] = "top level"
           | showCtxt [f] = ST.getString(!SymbolTables.varTable, f)
           | showCtxt (f::fs) = showCtxt [f] ^ ";" ^ showCtxt fs
      in
         ("environment at " ^ showCtxt (Scope.getCtxt state) ^ "\n" ^
          envConsStr ^ BD.showBFun (Scope.getFlow state) ^ "\n", si)
      end

   fun toString env =
      let
         val (str, _) = toStringSI (env,TVar.emptyShowInfo)
      in
         str
      end
   
   fun topToStringSI (env, si) =
      let
         fun tts acc (sc :: scs, state) =
            (case Scope.unwrap (sc :: scs, state) of
                 (GROUP _, (_, state)) => toStringSI ((acc @ [sc], state), si)
               | (_, env) => tts (acc @ [sc]) env) 
           | tts acc ([], state) = toStringSI ((acc, state), si)
      in
         tts [] env
      end

   fun topToString env =
      let
         val (str, _) = topToStringSI (env,TVar.emptyShowInfo)
      in
         str
      end

   fun kappaToStringSI (env, si) = (case Scope.unwrap env of
        (KAPPA {ty = t}, _) =>
         let
            val (tStr, si) = showTypeSI (t,si)
         in
            (tStr ^ "\n", si)
         end
      | _ => raise InferenceBug
   )

   fun kappaToString env =
      let
         val (str, _) = kappaToStringSI (env,TVar.emptyShowInfo)
      in
         str
      end

   fun funTypeToStringSI (env, f, si) = (case Scope.lookup (f,env) of
        (_, COMPOUND { ty = SOME (t,_), width, uses, nested }) =>
            showTypeSI (t,si)
      | _ => raise InferenceBug
   )

   fun reduceBooleanFormula (sym,t,setType,reduceToMono,env) =
      let
         (*we need to restrict the size of the Boolean formula in two
         ways: first, for the function we need all Boolean variables
         in its type, all lambda- and kappa-bound types in the
         environment as well as all the uses of other functions that
         occur in it; secondly, the analysis must continue with a
         Boolean formula that contians the Boolean variables of all
         lambda- and kappa-bound types in the environment. Since the
         latter is usually an empty environment (namely for all
         top-level functions), we first calculate the set of Boolean
         variables in kappa- and lambda-bound types and use that for
         the Boolean formula of the function; then we project onto
         the variables in kappa- and lambda-bound types*)
         val texpBVarset = texpBVarset (fn ((_,v),vs) => BD.addToSet (v,vs))

         val (monoTVars, monoBVars) = Scope.getMonoVars env
         val (usesTVars, usesBVars) = Scope.getVarsUses (sym, env)
         val funBVars = BD.union (texpBVarset (t,usesBVars),
                           BD.union (monoBVars, usesBVars))
                           
         val (scs, state) = env
         val bFun = BD.projectOnto (funBVars,Scope.getFlow state)
         val bFunRem = if reduceToMono then BD.projectOnto (monoBVars,bFun)
                       else bFun
         (*val _ = TextIO.print ("projecting for " ^ SymbolTable.getString(!SymbolTables.varTable, sym) ^ ": " ^ showType t ^ " onto " ^ BD.setToString funBVars ^ ", mono " ^ BD.setToString monoBVars ^"\n")*)
         val groupTVars = texpVarset (t,Scope.getVars env)
         val sCons = SC.filter (groupTVars, Scope.getSize state)
         val state = Scope.setSize sCons (Scope.setFlow bFunRem state)
         val env = Scope.update (sym, setType (t,bFun), (scs, state))
      in
         env
      end

   fun affectedFunctions (substs, env) =
      let
         fun aF (ss, substs, ([], _)) = ss
           | aF (ss, substs, env) =
               if isEmpty substs then ss else aFB ss (Scope.unwrap env)
         and aFB ss (GROUP l,env) =
            let
               fun aFL (ss, []) =
                   aF (ss, substsFilter (substs, Scope.getVars env), env)
                 | aFL (ss, {name = n, ty, width, uses = us, nested = ns} :: l) =
                     List.foldl (fn (b,ss) => aFB ss (b,env))
                     (if List.all (fn (_,t) => isEmpty
                              (substsFilter (substs, texpVarset (t,TVar.empty))))
                           (SpanMap.listItems us)
                     then aFL (ss, l)
                     else aFL (SymbolSet.add' (n, ss), l)
                     ) ns
            in
               aFL (ss, l)
            end
           | aFB ss (_, env) =
               aF (ss, substsFilter (substs, Scope.getVars env), env)
      in
         aF (SymbolSet.empty, substs, env)
      end

   fun affectedField (bVars, env as (scs,state)) =
      let
         fun aF (_, SOME f) = SOME f
           | aF (([],_), NONE) = NONE
           | aF (env, NONE) = case Scope.unwrap env of
              (KAPPA {ty = t}, env) =>
               aF (env, fieldOfBVar (bVars, t))
            | (SINGLE {name, ty = t}, env) => aF (env, fieldOfBVar (bVars, t))
            | (GROUP l, env) =>
            let
               fun findField ((_,t), SOME f) = SOME f
                 | findField ((_,t), NONE) = fieldOfBVar (bVars, t)
               fun aFL {name, ty = tOpt, width, uses, nested} =
                  List.foldl findField
                     (case tOpt of
                          NONE => NONE
                        | SOME (t,_) => fieldOfBVar (bVars, t))
                     (SpanMap.listItems uses)
            in
               aF (env, case List.mapPartial aFL l of
                       [] => NONE
                     | (f :: _) => SOME f)
            end
      in
         aF (env, NONE)
      end

   fun flowError (bVar, fOpt, envs) =
      let
         val fOpt = List.foldl (fn (env,res) => case res of
                       SOME f => SOME f
                     | NONE => affectedField (bVar, env)) fOpt envs
         val fStr = case fOpt of
                 NONE => "some field" ^ " with vars " ^ BD.setToString bVar
               | SOME f => "field " ^
                  SymbolTable.getString(!SymbolTables.fieldTable, f)
      in
         raise UnificationFailure (fStr ^ " cannot flow here")
      end

   fun meetBoolean (update, env as (scs, state)) =
      (scs, Scope.setFlow (update (Scope.getFlow state)) state)
         handle (BD.Unsatisfiable bVar) => flowError (bVar, NONE, [env])

   fun meetSizeConstraint (update, (scs, state)) =
      (scs, Scope.setSize (update (Scope.getSize state)) state)

   fun genConstructorFlow (contra, env) = case Scope.unwrap env of
        (KAPPA {ty=FUN ([t], ALG (_,vs))}, _) =>
         let
            val dtVars = List.map (fn v => case v of
                             VAR p => p
                           | _ => raise InferenceBug) vs
            val flow = texpConstructorFlow dtVars contra t
            val env = meetBoolean (fn bFun => BD.meet (flow,bFun), env)
         in
            env
         end
      | _ => raise InferenceBug

   fun pushSymbol (sym, span, recordUsage, env) =
      (case Scope.lookup (sym,env) of
          (_, SIMPLE {ty = t}) =>
         let
            val tNew = setFlagsToTop t
            val env = Scope.wrap (KAPPA {ty = tNew}, env)
            val l1 = texpBVarset (op ::) (t, [])
            val l2 = texpBVarset (op ::) (tNew, [])
            fun genImpl ((contra1,f1),(contra2,f2),bf) =
               if contra1<>contra2 then raise InferenceBug else
               if contra1 then
                  BD.meetVarImpliesVar (f2,f1) bf
               else
                  BD.meetVarImpliesVar (f1,f2) bf
         in
            meetBoolean (fn bFun => ListPair.foldlEq genImpl bFun (l2, l1), env)
         end
        | (tvs, COMPOUND {ty = SOME (t,bFunFun), width = w, uses, nested}) =>
         let
            val (scs,state) = env
            val bFun = BD.meet (bFunFun, Scope.getFlow state)
            val decVars = case w of
                 SOME t => texpVarset (t,TVar.empty)
               | NONE => TVar.empty
            val (t,bFun,sCons) = instantiateType (tvs, t, decVars, bFun, Scope.getSize state)
            val env = (scs, Scope.setFlow bFun (Scope.setSize sCons state))
            (*we need to record the usage sites of all functions (primitives,
            really) that have explicit size constraints in order to be able
            to later generate error messages for ambiguous uses of these
            functions*)
            fun action (COMPOUND {ty, width, uses, nested},cons) =
               (COMPOUND {ty = ty, width = width,
                uses = SpanMap.insert (uses, span, (Scope.getCurFun state, t)),
                nested = nested}, cons)
              | action _ = raise InferenceBug
            val env =
               if not recordUsage andalso
                  TVar.isEmpty (TVar.intersection (decVars, SC.getVarset (Scope.getSize state)))
               then env
               else Scope.update (sym, action, env)
         in
            Scope.wrap (KAPPA {ty = t}, env)
         end
        | (_, COMPOUND {ty = NONE, width, uses, nested}) =>
          (case SpanMap.find (uses, span) of
               SOME (_,t) => Scope.wrap (KAPPA {ty = t}, env)
             | NONE =>
             let
                val (scs,state) = env
                val res = freshVar ()
                fun action (COMPOUND {ty, width, uses, nested},cons) =
                     (COMPOUND {ty = ty, width = width,
                      uses = SpanMap.insert (uses, span, (Scope.getCurFun state,res)),
                      nested = nested}, cons)
                  | action _ = raise InferenceBug
                val env = Scope.update (sym, action, env)
             in
                Scope.wrap (KAPPA {ty = res}, env)
             end
          )
      )

   fun pushSymbolNested (sym, span, env as (scs, state)) =
      case Scope.getCtxt state of
           [] => (0,pushSymbol (sym, span, false, env))
         | (curFun :: _) =>
      let
         val nested = case Scope.lookup (curFun, env) of
              (_, COMPOUND {ty, width, uses, nested}) => nested
            | _ => raise InferenceBug
         val _ = TextIO.print ("checking " ^ Int.toString (List.length nested) ^ " nested groups\n")
         fun findSymInGroups (n, ns, env) =
            List.foldl
               (fn (g,res) => case res of
                    SOME r => SOME r
                  | NONE => findSymInGroup (n+1,g,Scope.wrap (g, env)))
               NONE ns
         and findSymInGroup (n,GROUP bs,env) =
            if List.exists (fn {name, ty, width, uses, nested} =>
                           SymbolTable.eq_symid (sym,name)) bs
               then SOME
                  (n, pushSymbol (sym, span, false, env))
               else List.foldl (fn (b,res) => case res of
                    SOME r => SOME r
                  | NONE => findSymInGroups (n, #nested b, env)
               ) NONE bs
           | findSymInGroup (n,_,env) = raise InferenceBug
      in
         case findSymInGroups (0, nested, env) of
              NONE => (0,pushSymbol (sym, span, false, env))
            | SOME r => r
      end

   fun getUsages (sym, env) = (case Scope.lookup (sym, env) of
           (_, SIMPLE {ty}) => []
         | (_, COMPOUND {ty, width, uses = us, nested}) => SpanMap.listKeys us
         )

   fun getContextOfUsage (sym, span, env) = (case Scope.lookup (sym, env) of
           (_, SIMPLE {ty}) => raise InferenceBug
         | (_, COMPOUND {ty, width, uses = us, nested}) => 
           #1 (SpanMap.lookup (us, span))
         )

   fun pushUsage (sym, span, env) = (case Scope.lookup (sym, env) of
           (_, SIMPLE {ty}) => raise InferenceBug
         | (_, COMPOUND {ty, width, uses = us, nested}) =>
            let
               val (fid, t) = SpanMap.lookup (us, span)
               (*fun gatherBFun (f,bFun) =
                  case List.find (fn (f',_) => ST.eq_symid (f,f')) funList of
                       SOME (_, VALUE { symFlow = bFun', ... }) =>
                        BD.meet (bFun',bFun)
                     | SOME (_, DECODE { symFlow = bFun', ... }) =>
                        BD.meet (bFun',bFun)
                     | NONE => bFun
               fun addUsageBFun bFun = List.foldl gatherBFun bFun fs
               val env = meetBoolean (addUsageBFun, env)*)
            in
               Scope.wrap (KAPPA {ty = t}, env)
            end
         )

   fun getCtxt (scs, state) = Scope.getCtxt state

   fun popToUsage (sym, span, env) = (case Scope.unwrap env of
        (KAPPA {ty = tUse}, env) =>
         let
            val funRef = ref (NONE : SymbolTable.symid option)
            fun setUsage (COMPOUND {ty, width, uses = us, nested}, cons) =
               (case SpanMap.find (us,span) of
                    NONE => raise InferenceBug
                  | SOME (fid, _) =>
                     (funRef := SOME fid;
                     (COMPOUND {
                        ty = ty, width = width,
                        uses = SpanMap.insert (us,span,(fid,tUse)),
                        nested = nested
                     }, cons))
               )
              | setUsage _ = raise InferenceBug
            val env = Scope.update (sym, setUsage, env)
            fun setType t (COMPOUND {ty = _, width, uses, nested}, cons) =
                  (COMPOUND {ty = SOME t, width = width, uses = uses, nested = nested},
                   cons)
              | setType t _ = raise InferenceBug
            val fid = case !funRef of
                 SOME fid => fid
               | NONE => raise InferenceBug
            val env = case Scope.lookup (fid,env) of
                 (_, COMPOUND { ty = SOME (t,_), width, uses, nested}) =>
                  reduceBooleanFormula (fid,t,setType,true,env)
               | _ => raise InferenceBug
         in
            env
         end
     | _ => raise InferenceBug)

   fun pushLambdaVar' (sym, env) =
      let
         val t = VAR (TVar.freshTVar (), BD.freshBVar ())
      in
         (t, Scope.wrap (SINGLE {name = sym, ty = t}, env))
      end

   fun pushLambdaVar (sym, env) =
      let
         val t = VAR (TVar.freshTVar (), BD.freshBVar ())
      in
         Scope.wrap (SINGLE {name = sym, ty = t}, env)
      end

   fun reduceToRecord (bns, env) =
      let
         fun genFields (fs, [], env) = (case Scope.unwrap env of
                 (KAPPA {ty=VAR (tv,bv)}, env) =>
                  Scope.wrap (KAPPA {ty = RECORD (tv, bv, fs)}, env)
               | _ => raise InferenceBug
            )
           | genFields (fs, (bVar, fName) :: bns, env) =
               (case Scope.unwrap env of
                    (KAPPA {ty=t}, env) =>
                        genFields (insertField (
                           RField { name = fName, fty = t, exists = bVar},
                           fs), bns, env)
                  | _ => raise InferenceBug)
      in
         genFields ([], bns, env)
      end

   fun reduceToSum (n, env) =
      let
         fun rTS (n, vars, const, env) = if n>0 then
               case Scope.unwrap env of
                    (KAPPA {ty = CONST c}, env) => rTS (n-1, vars, c+const, env)
                  | (KAPPA {ty = VAR (v,_)}, env) => rTS (n-1, v::vars, const, env)
                  | _ => raise InferenceBug
            else case vars of
                 [] => Scope.wrap (KAPPA {ty = CONST const}, env)
               | [v] => Scope.wrap (KAPPA {ty = VAR (v, BD.freshBVar ())}, env)
               | vs =>
                  let
                     val v = TVar.freshTVar ()
                     val scs = SC.fromList [SC.equality (v, vs, const)]
                     val env = meetSizeConstraint
                                 (fn scs' => SC.merge (scs,scs'), env)
                     (*val (scsStr,si) = SC.toStringSI (scs, NONE, TVar.emptyShowInfo)
                     val (eStr, si) = topToStringSI (env, si)
                     val _ = TextIO.print ("reduceToSum: " ^ scsStr ^ ", resulting in\n" ^ eStr ^ "\n")*)
                  in
                     Scope.wrap (KAPPA { ty = VAR (v, BD.freshBVar ())}, env)
                  end
      in
         rTS (n, [], 0, env)
      end

   fun reduceToFunction (env,nArgs) =
      if nArgs=0 then env else
      let
         val (tRes, env) = case Scope.unwrap env of
                             (KAPPA {ty = t}, env) => (t,env)
                           | (SINGLE {name, ty = t}, env) => (t,env)
                           | _ => raise InferenceBug
         fun getArgs (tys,n,env) = if n=0 then (tys,env) else
            case Scope.unwrap env of
                 (KAPPA {ty = t}, env) => getArgs (t :: tys,n-1,env)
               | (SINGLE {name, ty = t}, env) => getArgs (t :: tys,n-1,env)
               | _ => raise InferenceBug
         val (tArgs,env) = getArgs ([],nArgs,env)
      in
         Scope.wrap (KAPPA {ty = FUN (tArgs,tRes)}, env)
      end

   fun reduceToResult env = case Scope.unwrap env of
           (KAPPA {ty = FUN (t1,t2)}, env) =>
            Scope.wrap (KAPPA {ty = t2}, env)
         | _ => raise InferenceBug

   fun applySubsts (substs, ei, bFun, directed, newUses1, newUses2, env1, env2) =
      let
         val substs = substsFilter (substs, TVar.union (Scope.getVars env1,
                                                        Scope.getVars env2))
         fun substBinding (KAPPA {ty=t}, newUses, ei) =
            (case applySubstsToExp substs (t,ei) of (t,ei) =>
               (KAPPA {ty = t}, TVar.empty, newUses, ei))
           | substBinding (SINGLE {name = n, ty = t}, newUses, ei) =
            (case applySubstsToExp substs (t,ei) of (t,ei) =>
               (SINGLE {name = n, ty = t}, TVar.empty, newUses, ei))
           | substBinding (GROUP bs, newUses, ei) =
               let
                  val eiRef = ref ei
                  val varSet = ref TVar.empty
                  val usesRef = ref newUses
                  fun optSubst (SOME t) =
                     (case applySubstsToExp substs (t,!eiRef) of (t,ei) =>
                        (eiRef := ei; SOME t))
                    | optSubst NONE = NONE
                  fun optBSubst (SOME (t,bFun)) =
                     (case applySubstsToExp substs (t,!eiRef) of (t,ei) =>
                        (eiRef := ei; SOME (t,bFun)))
                    | optBSubst NONE = NONE
                  fun usesSubst (ctxt,t) =
                     (case applySubstsToExp substs (t,!eiRef) of (t,ei) =>
                        (eiRef := ei; (ctxt,t)))
                  fun substB {name = n, ty = t, width = w, uses = us, nested = ns} =
                     {name = n, ty = optBSubst t, width = optSubst w,
                      uses = SpanMap.map usesSubst
                        (case SymMap.find (newUses,n) of
                          NONE => us
                        | SOME nUs =>
                           let
                              val _ = usesRef := #1 (SymMap.remove (!usesRef,n))
                              val _ = varSet :=
                                 List.foldl (fn ((_,(_,t)),set) =>
                                             texpVarset (t,set)) (!varSet) nUs
                           in
                              List.foldl SpanMap.insert' us nUs
                           end),
                      nested = List.map (fn b =>
                        case substBinding (b, !usesRef, !eiRef) of
                           (b, _, us, ei) => (*ns1 and ns2 have same set of uses, varset is empty*)
                              (usesRef := us
                              ;eiRef := ei
                              ;b)) ns
                     }
               in
                  (GROUP (List.map substB bs), !varSet, !usesRef, !eiRef)
               end
         fun genImpl (t1,t2) ((contra1,f1), (contra2,f2),bFun) =
            if contra1<>contra2 then
               let
                  val (e1Str, si) = kappaToStringSI (env1,TVar.emptyShowInfo)
                  val (e2Str, si) = kappaToStringSI (env2,si)
                  val (t1Str, si) = showTypeSI (t1,si)
                  val (t2Str, si) = showTypeSI (t2,si)
                  val (mStr, si) = showSubstsSI (mgu (t1,t2,emptySubsts), si)
                  val _ = TextIO.print ("cannot gen impl flow from\n" ^ e1Str ^ "to\n" ^ e2Str ^ "with types\n" ^ t1Str ^ "\nand\n" ^ t2Str ^ "\nsince mgu = " ^ mStr ^ "\n")
               in
                  raise InferenceBug
               end
            else if BD.eq(f1,f2) then bFun else
            let
               (*val _ = TextIO.print ("add directed flow: " ^ BD.showVar f1 ^
                  (if contra1 then "<-" else "->") ^ BD.showVar f2 ^ "\n")*)
            in
               if contra1 then BD.meetVarImpliesVar (f2,f1) bFun
               else BD.meetVarImpliesVar (f1,f2) bFun
            end
         fun flowForType (t1,t2,bFun) =
            if directed then
               (t1,
                ListPair.foldlEq (genImpl (t1,t2)) bFun
                  (texpBVarset (op ::) (t1, []), texpBVarset (op ::) (t2, []))
                  handle (BD.Unsatisfiable bVar) => flowError (bVar, NONE, [env1,env2]))
            else
            let
               (*val _ = TextIO.print ("forcing bVars to be equal:" ^
                  ListPair.foldlEq (fn (f1,f2,str) => str ^ " " ^ BD.showVar f1 ^ "=" ^ BD.showVar f2) ""
                  (texpBVarset (fn ((_,f),fs) => f::fs) (t1, []),
                   texpBVarset (fn ((_,f),fs) => f::fs) (t2, [])) ^ "\n")*)
            in
               (t1,
                ListPair.foldlEq BD.meetEqual bFun
                  (texpBVarset (fn ((_,f),fs) => f::fs) (t1, []),
                   texpBVarset (fn ((_,f),fs) => f::fs) (t2, [])))
            end
         fun uniteFlowInfo (KAPPA {ty=t1}, KAPPA {ty=t2}, bFun) =
               let
                  val (t,bFun) = flowForType (t1,t2,bFun)
               in
                  (KAPPA {ty=t}, bFun)
               end
           | uniteFlowInfo (SINGLE {ty=t1, name = n1}, SINGLE {ty=t2, name = n2}, bFun) =
               let
                  val (t,bFun) = flowForType (t1,t2,bFun)
               in
                  (SINGLE {ty=t, name = n2}, bFun)
               end
           | uniteFlowInfo (GROUP bs1, GROUP bs2, bFun) =
               let
                  fun flowOpt (SOME t1,SOME t2,bFun) =
                     let
                        val (t,bFun) = flowForType (t1,t2,bFun)
                     in
                        (SOME t, bFun)
                     end
                    | flowOpt (NONE,NONE,bFun) = (NONE, bFun)
                    | flowOpt _ = raise InferenceBug
                  fun bflowOpt (SOME (t1,flow),SOME (t2,_),bFun) =
                     let
                        val (t,bFun) = flowForType (t1,t2,bFun)
                     in
                        (SOME (t,flow), bFun)
                     end
                    | bflowOpt (NONE,NONE,bFun) = (NONE, bFun)
                    | bflowOpt _ = raise InferenceBug
                  fun genUsesFlow ((span,(ctxt,t1)),(_,(_,t2)),(sm,bFun)) =
                     let
                        val (t,bFun) = flowForType (t1,t2,bFun)
                     in
                        (SpanMap.insert (sm, span, (ctxt,t)), bFun)
                     end
                  fun genBindFlow ({name = n1, ty=t1, width=w1, uses = us1, nested = ns1},
                                   {name = n2, ty=t2, width=w2, uses = us2, nested = ns2},(bs,bFun)) =
                     let
                        val (t,bFun) = bflowOpt (t1,t2,bFun)
                        val (w,bFun) = flowOpt (w1,w2,bFun)
                        val (us,bFun) = ListPair.foldr genUsesFlow (SpanMap.empty,bFun)
                                 (SpanMap.listItemsi us1,SpanMap.listItemsi us2)
                        fun foldAcc f (x::xs,acc) =
                           let
                              val (x,acc) = f (x,acc)
                              val (xs,acc) = foldAcc f (xs, acc)
                           in
                              (x::xs,acc)
                           end
                           | foldAcc f ([], acc) = ([],acc)
                        val (ns,bFun) = foldAcc (fn ((b1,b2),bFun) =>
                                                 uniteFlowInfo (b1,b2,bFun))
                                           (ListPair.zip (ns1,ns2),bFun)
                     in
                        ({name = n1, ty = t, width = w, uses = us, nested = ns} :: bs, bFun)
                     end
                  val (bs,bFun) = ListPair.foldr genBindFlow ([], bFun) (bs1,bs2)
               in
                 (GROUP bs, bFun)
               end
           | uniteFlowInfo _ = raise InferenceBug
      in
         if isEmpty substs andalso SymMap.isEmpty newUses1 andalso
            SymMap.isEmpty newUses2 then (ei, bFun, env1) else
            let
               val curVars = Scope.getVars env1
               val (b1, env1) = Scope.unwrap env1
               val (b2, env2) = Scope.unwrap env2
               val (b1', extraVars, newUses1, ei) = substBinding (b1, newUses1, ei)
               val (b2', _,         newUses2, ei) = substBinding (b2, newUses2, ei)
               val (b,bFun) = uniteFlowInfo (b1', b2', bFun)
               val (ei, bFun, env) =
                     applySubsts (substs, ei, bFun, false, newUses1, newUses2, env1, env2)
               val newVars =
                     applySubstsToVarset (substs, TVar.union (extraVars, curVars))
            in
               (ei, bFun, Scope.wrapWithVars (b, newVars, env))
            end
      end

   fun return (n,env) =
      let
         val (t, env) = Scope.unwrap env
         fun popN (n,env) = if n<=0 then env else
            let
               val (_, env) = Scope.unwrap env
            in
               popN (n-1, env)
            end
      in
         Scope.wrap (t, popN (n,env))
      end
      

   fun popKappa env = case Scope.unwrap env of
        (KAPPA {ty}, env) => env
      | _ => raise InferenceBug

   fun popToFunction (sym, env) =
      let
         (*val _ = TextIO.print ("popToFunction " ^ SymbolTable.getString(!SymbolTables.varTable, sym) ^ ":\n" ^ toString env)*)
         fun setType t (COMPOUND {ty = NONE, width, uses, nested}, cons) =
               (COMPOUND {ty = SOME t, width = width, uses = uses, nested = nested},
                cons)
           | setType t _ = (TextIO.print ("popToFunction " ^ SymbolTable.getString(!SymbolTables.varTable, sym) ^ ":\n" ^ toString env); raise InferenceBug)
      in
         case Scope.unwrap env of
              (KAPPA {ty=t}, (scs,state)) =>
              (
(*let
   fun checkField bVar =
      (case BD.meetVarZero bVar (Scope.getFlow state) of _ => true)
      handle (BD.Unsatisfiable bVars) => false
   val _ = if SymbolTable.toInt sym <> 82 then () else
      case t of
         MONAD (_,RECORD (_,_,fs),_) =>
            (case List.find (fn (RField { name = fid, ...}) => SymbolTable.toInt fid = 31) fs of
              NONE => ()
            | SOME (RField { exists = bVar, ... }) =>
             if checkField bVar then () else
             TextIO.print ("HERE!\n")
            )
       | _ => ()
in () end;*)
               reduceBooleanFormula (sym,t,setType,true, (scs, state))
              )
            | _ => raise InferenceBug
      end

   fun enterFunction (sym, (scs,state)) =
      (scs, Scope.setCtxt (sym :: Scope.getCtxt state) state)

   fun leaveFunction (sym, (scs,state)) =
      case Scope.getCtxt state of
           (fid :: fids) =>
            if SymbolTable.eq_symid(fid,sym) then (scs, Scope.setCtxt fids state)
            else raise InferenceBug
         | [] => raise InferenceBug

   fun clearFunction (sym, env) =
      let
         val tOptRef = ref (NONE : (texp * BD.bfun) option)
         fun resetType (COMPOUND {ty = tOpt, width, uses, nested}, cons) =
               (tOptRef := tOpt
               ;(COMPOUND {ty = NONE, width = width, uses = uses, nested = nested}, cons))
           | resetType _ = raise InferenceBug
         val (scs,state) = Scope.update (sym, resetType, env)
         val env = (scs,state)
         val envOpt = case !tOptRef of
              NONE => NONE
            | SOME (ty,flow) =>
               SOME (meetBoolean (
                     fn bFun => BD.meet (flow,bFun),
                     Scope.wrap (KAPPA { ty = ty },env)))
      in
         (envOpt, env)
      end
   
   fun forceNoInputs (sym, fields, env) = case Scope.lookup (sym,env) of
               (_,COMPOUND {ty = SOME (t,bFun), width, uses, nested}) =>
               let
                  val fs = case t of
                       (MONAD (r,RECORD (_,_,fs),out)) => fs
                     | FUN (args,_) =>
                        List.foldl (fn (arg,fs) => case arg of
                             RECORD (_,_,fs') => fs' @ fs
                           | _ => fs) [] args
                     | _ => []
                  fun checkField bVar =
                     (case BD.meetVarZero bVar bFun of _ => true)
                     handle (BD.Unsatisfiable bVars) => false
               in
                  List.foldl (fn (RField { name = f, fty, exists = bVar},fs) =>
                     if List.exists (fn s => SymbolTable.eq_symid(s,f)) fields
                     then fs
                     else if checkField bVar then fs else f :: fs)
                  [] fs
               end
             | (_,COMPOUND {ty = NONE, width, uses, nested}) => []  (*allow type errors*)
             | _ => raise InferenceBug

   fun unify (env1, env2, newUses1, newUses2, substs) =
      (case Scope.unwrapDifferent (env1, env2) of
           (SOME (KAPPA {ty = t1}, KAPPA {ty = t2}), env1, env2) =>
            unify (env1, env2, newUses1, newUses2, mgu (t1,t2,substs))
         | (SOME (SINGLE {ty = t1, ...}, SINGLE {ty = t2, ...}), env1, env2) =>
            unify (env1, env2, newUses1, newUses2, mgu (t1,t2,substs))
         | (SOME (GROUP bs1, GROUP bs2), env1, env2) =>
            let
               fun mguOpt (SOME t1, SOME t2, substs) = mgu (t1,t2,substs)
                 | mguOpt (NONE, NONE, substs) = substs
                 | mguOpt (_, _, _) = raise InferenceBug
               fun mguBOpt (SOME (t1,_), SOME (t2,_), substs) = mgu (t1,t2,substs)
                 | mguBOpt (NONE, NONE, substs) = substs
                 | mguBOpt (_, _, _) = raise InferenceBug
               fun mguUses ((s1,(ctxt1,t1)) :: us1, (s2,(ctxt2,t2)) :: us2,
                           nUs1, nUs2, substs) =
                  (case SymbolTable.compare_span (s1,s2) of
                       EQUAL => mguUses (us1, us2, nUs1, nUs2, mgu (t1,t2,substs))
                     | LESS => mguUses (us1, (s2,(ctxt2,t2)) :: us2,
                        nUs1, (s1,(ctxt1,t1)) :: nUs2, substs)
                     | GREATER => mguUses ((s1,(ctxt1,t1)) :: us1, us2,
                        (s2,(ctxt2,t2)) :: nUs1, nUs2, substs)
                  )
                  | mguUses (us1, us2, nUs1, nUs2, substs) =
                     (us2 @ nUs1, us1 @ nUs2, substs)
               fun uB (({name = n1, ty = t1, width = w1, uses = u1, nested = _},
                        {name = n2, ty = t2, width = w2, uses = u2, nested = _}),
                        (newUses1, newUses2, substs)) =
                  if not (ST.eq_symid (n1,n2)) then raise InferenceBug else
                  case mguUses (SpanMap.listItemsi u1, SpanMap.listItemsi u2,
                               [], [],
                               mguBOpt (t1, t2, mguOpt (w1, w2, substs))) of
                    ([],[], substs) => (newUses1, newUses2, substs)
                  | (nUs1,[], substs) =>
                     (SymMap.insert (newUses1,n1,nUs1), newUses2, substs)
                  | ([],nUs2, substs) =>
                     (newUses1, SymMap.insert (newUses2,n2,nUs2), substs)
                  | (nUs1,nUs2, substs) =>
                     (SymMap.insert (newUses1,n1,nUs1),
                      SymMap.insert (newUses2,n2,nUs2), substs)
               (*val _ = if List.length bs1=List.length bs2 then () else
                     TextIO.print ("*************** mgu of\n" ^ topToString (Scope.wrap (GROUP bs1,env1)) ^ "\ndoes not match\n" ^ topToString (Scope.wrap (GROUP bs2,env2)))*)
               val (newUses1, newUses2, substs) =
                  List.foldl uB (newUses1, newUses2, substs) (ListPair.zipEq (bs1,bs2))
            in
               unify (env1, env2, newUses1, newUses2, substs)
            end      
         | (NONE, env1, env2) => (newUses1, newUses2, substs)
         | (SOME _, _, _) => raise InferenceBug
      )

   fun meetGeneral (env1, env2, directed) =
      let

         (*val (e1Str,si) = topToStringSI (env1, TVar.emptyShowInfo)
         val (e2Str,si) = topToStringSI (env2, si)
         val kind = if directed then "directed" else "equalizing"
         val _ = TextIO.print ("**** meet " ^ kind ^ ":\n" ^ e1Str ^ "++++ intersected with\n" ^ e2Str)*)

         val (newUses1, newUses2, substs) =
            unify (env1, env2, SymMap.empty, SymMap.empty, emptySubsts)
         (*val (scs, cons) = env1
         val (_, cons') = env2
         val _ = if cons<>cons' then raise InferenceBug else ()
         val (bFun, sCons) = !cons
         val bFun = applyExpandInfo ei bFun
            handle (BD.Unsatisfiable bVar) =>
               flowError (bVar, NONE, [env1,env2])
         val _ = cons := (bFun, sCons)
         val env1 = (scs,cons)*)
      
         val (_, state1) = env1
         val (_, state2) = env2
         val sCons = SC.merge (Scope.getSize state1,Scope.getSize state2)
         val (sCons, substs) = applySizeConstraints (sCons, substs)

         val (ei, bFunFlow, env) =
            applySubsts (substs, emptyExpandInfo, BD.empty, directed, 
                         newUses1, newUses2, env1, env2)
         
         val bVars1 = Scope.getBVars env1
         val bVars2 = Scope.getBVars env2
         val bVars = BD.union (bVars1,bVars2)
         val bVars = expandInfoGetBVars (ei, bVars)
         val bFun = BD.meet (Scope.getFlow state1, Scope.getFlow state2)
         (*val _ = TextIO.print ("meet of Boolean function:\n" ^ BD.showBFun (Scope.getFlow state1) ^
                              "\nand\n" ^ BD.showBFun (Scope.getFlow state2) ^ 
                              "\nis\n" ^ BD.showBFun bFun ^ "\n")*)


         val bFun = BD.projectOnto (bVars, bFun)
         val bFun = applyExpandInfo ei bFun
            handle (BD.Unsatisfiable bVar) =>
               flowError (bVar, NONE, [env,env1,env2])
         val bFun = BD.meet (bFunFlow, bFun)
            handle (BD.Unsatisfiable bVar) =>
               flowError (bVar, NONE, [env,env1,env2])
         val (scs,state) = env
         val env = (scs,Scope.setSize sCons (Scope.setFlow bFun state))

         (*val (envStr,si) = topToStringSI (env, si)
         val (eStr, si) = showExpandInfoSI (ei,si)
         val (sStr,si) = showSubstsSI (substs,si)
         val _ = TextIO.print ("applying substitution " ^ sStr ^ " to\n" ^ e1Str ^ "and\n" ^ e2Str ^ 
                  "resulting in\n" ^ envStr ^ 
                  "thereby projecting onto " ^ BD.setToString bVars ^
                  "\nadding flow " ^ BD.showBFun bFunFlow ^
                  "\nand expanding\n" ^ eStr ^ "yielding " ^ BD.showBFun bFun ^ "\n")*)
      in
         env
      end

   fun meetFlow (env1,env2) = meetGeneral (env1,env2,true)

   fun meet (env1,env2) = meetGeneral (env1,env2,false)
   
   fun subseteq (env1, env2) =
      let
         val (_, _, substs) =
            unify (env1, env2, SymMap.empty, SymMap.empty, emptySubsts)
         (*val si = TVar.emptyShowInfo
         val (e1Str, si) = toStringSI (env1, si)
         val (e2Str, si) = toStringSI (env2, si)
         val (sStr, si) = showSubstsSI (substs, si)*)
         val substs = substsFilter (substs, Scope.getVars env1)
         (*val _ = TextIO.print ("+++++ substitution " ^ sStr ^ " indicates" ^
                  (if isEmpty substs then "" else " not") ^
                  " stable in env1:\n" ^ e1Str ^ "and env2:\n" ^ e2Str)*)
      in
         substs
      end

end
