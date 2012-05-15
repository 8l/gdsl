structure SpecLex  = struct

    datatype yystart_state = 
STRING | COMMENT | BITPATNUM | BITPAT | INITIAL
    structure UserDeclarations = 
      struct



   structure T = SpecTokens
   type lex_result = T.token

   (* used for keeping track of comment depth *)
   val depth = ref 0

   (* list of string fragments to concatenate *)
   val buf : string list ref = ref []

   (* add a string to the buffer *)
   fun addStr s = (buf := s :: !buf)

   (* make a FLOAT token from a substring *)
   fun mkFloat ss = let
	   val (isNeg, rest) =
         (case Substring.getc ss of
            SOME(#"-", r) => (true, r)
		    | SOME(#"~", r) => (true, r)
		    | _ => (false, ss))
	   val (whole, rest) = Substring.splitl Char.isDigit rest
	   val rest = Substring.triml 1 rest (* remove "." *)
	   val (frac, rest) = Substring.splitl Char.isDigit rest
	   val exp =
         if Substring.isEmpty rest
		      then 0
		   else
            let
		         val rest = Substring.triml 1 rest (* remove "e" or "E" *)
		      in
		         #1(valOf(Int.scan StringCvt.DEC Substring.getc rest))
		      end
   in
	    T.FLOAT
         (FloatLit.float
            {isNeg = isNeg,
		       whole = Substring.string whole,
		       frac = Substring.string frac,
		       exp = exp})
	end

   (* scan a number from a hexidecimal string *)
   val fromHexString = valOf o (StringCvt.scanString (IntInf.scan StringCvt.HEX))
   (* FIXME: the above code doesn't work in SML/NJ; here is a work around *)
   fun fromHexString s = let
      val SOME(n, _) =
         IntInf.scan
            StringCvt.HEX
            Substring.getc
	         (Substring.triml 2 (Substring.full s))
   in
	   n
   end

   fun eof () = T.EOF

   (* count the nesting depth of "(" inside primcode blocks *)
   fun mkString() = T.STRING (String.concat(List.rev (!buf)))


      end

    local
    datatype yymatch 
      = yyNO_MATCH
      | yyMATCH of ULexBuffer.stream * action * yymatch
    withtype action = ULexBuffer.stream * yymatch -> UserDeclarations.lex_result

    val yytable : ((UTF8.wchar * UTF8.wchar * int) list * int list) Vector.vector = 
#[([(0w0,0w31,5),
(0w127,0w2147483647,5),
(0w32,0w33,6),
(0w35,0w91,6),
(0w93,0w126,6),
(0w34,0w34,7),
(0w92,0w92,8)], []), ([(0w0,0w39,15),
(0w41,0w41,15),
(0w43,0w2147483647,15),
(0w40,0w40,16),
(0w42,0w42,17)], []), ([(0w0,0w8,20),
(0w14,0w31,20),
(0w33,0w38,20),
(0w40,0w47,20),
(0w58,0w2147483647,20),
(0w9,0w13,21),
(0w32,0w32,21),
(0w39,0w39,22),
(0w48,0w57,23)], []), ([(0w0,0w8,20),
(0w14,0w31,20),
(0w33,0w38,20),
(0w40,0w45,20),
(0w50,0w57,20),
(0w59,0w63,20),
(0w91,0w96,20),
(0w123,0w123,20),
(0w125,0w2147483647,20),
(0w9,0w13,25),
(0w32,0w32,25),
(0w39,0w39,22),
(0w46,0w46,26),
(0w48,0w49,26),
(0w124,0w124,26),
(0w47,0w47,27),
(0w65,0w90,27),
(0w97,0w122,27),
(0w58,0w58,28),
(0w64,0w64,29)], []), ([(0w0,0w8,20),
(0w14,0w31,20),
(0w127,0w2147483647,20),
(0w9,0w13,32),
(0w32,0w32,32),
(0w33,0w33,33),
(0w38,0w38,33),
(0w63,0w63,33),
(0w92,0w92,33),
(0w96,0w96,33),
(0w34,0w34,34),
(0w35,0w35,35),
(0w36,0w36,36),
(0w37,0w37,37),
(0w39,0w39,38),
(0w40,0w40,39),
(0w41,0w41,40),
(0w42,0w42,41),
(0w43,0w43,42),
(0w44,0w44,43),
(0w45,0w45,44),
(0w46,0w46,45),
(0w47,0w47,46),
(0w48,0w48,47),
(0w49,0w57,48),
(0w58,0w58,49),
(0w59,0w59,50),
(0w60,0w60,51),
(0w61,0w61,52),
(0w62,0w62,53),
(0w64,0w64,54),
(0w65,0w90,55),
(0w91,0w91,56),
(0w93,0w93,57),
(0w94,0w94,58),
(0w95,0w95,59),
(0w97,0w97,60),
(0w98,0w98,61),
(0w102,0w102,61),
(0w104,0w104,61),
(0w106,0w107,61),
(0w109,0w110,61),
(0w112,0w113,61),
(0w115,0w115,61),
(0w117,0w117,61),
(0w120,0w122,61),
(0w99,0w99,62),
(0w100,0w100,63),
(0w101,0w101,64),
(0w103,0w103,65),
(0w105,0w105,66),
(0w108,0w108,67),
(0w111,0w111,68),
(0w114,0w114,69),
(0w116,0w116,70),
(0w118,0w118,71),
(0w119,0w119,72),
(0w123,0w123,73),
(0w124,0w124,74),
(0w125,0w125,75),
(0w126,0w126,76)], []), ([], [68]), ([(0w32,0w33,14),
(0w35,0w91,14),
(0w93,0w126,14)], [65, 68]), ([], [66, 68]), ([(0w0,0w33,9),
(0w35,0w47,9),
(0w58,0w91,9),
(0w93,0w96,9),
(0w99,0w101,9),
(0w103,0w109,9),
(0w111,0w113,9),
(0w115,0w115,9),
(0w117,0w117,9),
(0w119,0w2147483647,9),
(0w34,0w34,10),
(0w92,0w92,10),
(0w97,0w98,10),
(0w102,0w102,10),
(0w110,0w110,10),
(0w114,0w114,10),
(0w116,0w116,10),
(0w118,0w118,10),
(0w48,0w57,11)], [68]), ([], [67]), ([], [64, 67]), ([(0w48,0w57,12)], [67]), ([(0w48,0w57,13)], []), ([], [64]), ([(0w32,0w33,14),
(0w35,0w91,14),
(0w93,0w126,14)], [65]), ([], [71]), ([(0w42,0w42,19)], [71]), ([(0w41,0w41,18)], [71]), ([], [70]), ([], [69]), ([], [72]), ([], [51, 72]), ([], [46, 72]), ([(0w48,0w57,24)], [55, 72]), ([(0w48,0w57,24)], [55]), ([], [50, 72]), ([(0w46,0w46,31),
(0w48,0w49,31),
(0w124,0w124,31)], [48, 72]), ([(0w39,0w39,30),
(0w45,0w45,30),
(0w47,0w57,30),
(0w63,0w63,30),
(0w65,0w90,30),
(0w95,0w95,30),
(0w97,0w122,30)], [49, 72]), ([], [45, 72]), ([], [47, 72]), ([(0w39,0w39,30),
(0w45,0w45,30),
(0w47,0w57,30),
(0w63,0w63,30),
(0w65,0w90,30),
(0w95,0w95,30),
(0w97,0w122,30)], [49]), ([(0w46,0w46,31),
(0w48,0w49,31),
(0w124,0w124,31)], [48]), ([], [59, 72]), ([(0w33,0w33,77),
(0w35,0w38,77),
(0w42,0w43,77),
(0w45,0w45,77),
(0w47,0w47,77),
(0w58,0w58,77),
(0w60,0w64,77),
(0w92,0w92,77),
(0w94,0w94,77),
(0w96,0w96,77),
(0w124,0w124,77),
(0w126,0w126,77)], [54, 72]), ([], [61, 72]), ([(0w0,0w9,161),
(0w11,0w32,161),
(0w34,0w34,161),
(0w39,0w41,161),
(0w44,0w44,161),
(0w46,0w46,161),
(0w48,0w57,161),
(0w59,0w59,161),
(0w65,0w91,161),
(0w93,0w93,161),
(0w95,0w95,161),
(0w97,0w123,161),
(0w125,0w125,161),
(0w127,0w2147483647,161),
(0w10,0w10,162),
(0w33,0w33,163),
(0w35,0w38,163),
(0w42,0w43,163),
(0w45,0w45,163),
(0w47,0w47,163),
(0w58,0w58,163),
(0w60,0w64,163),
(0w92,0w92,163),
(0w94,0w94,163),
(0w96,0w96,163),
(0w124,0w124,163),
(0w126,0w126,163)], [54, 62, 72]), ([(0w33,0w33,77),
(0w35,0w38,77),
(0w42,0w43,77),
(0w45,0w45,77),
(0w47,0w47,77),
(0w58,0w58,77),
(0w60,0w64,77),
(0w92,0w92,77),
(0w94,0w94,77),
(0w96,0w96,77),
(0w124,0w124,77),
(0w126,0w126,77)], [29, 54, 72]), ([(0w33,0w33,77),
(0w35,0w38,77),
(0w42,0w43,77),
(0w45,0w45,77),
(0w47,0w47,77),
(0w58,0w58,77),
(0w60,0w64,77),
(0w92,0w92,77),
(0w94,0w94,77),
(0w96,0w96,77),
(0w124,0w124,77),
(0w126,0w126,77)], [20, 54, 72]), ([], [43, 72]), ([(0w42,0w42,160)], [36, 72]), ([], [37, 72]), ([(0w33,0w33,77),
(0w35,0w38,77),
(0w42,0w43,77),
(0w45,0w45,77),
(0w47,0w47,77),
(0w58,0w58,77),
(0w60,0w64,77),
(0w92,0w92,77),
(0w94,0w94,77),
(0w96,0w96,77),
(0w124,0w124,77),
(0w126,0w126,77)], [27, 54, 72]), ([(0w33,0w33,77),
(0w35,0w38,77),
(0w42,0w43,77),
(0w45,0w45,77),
(0w47,0w47,77),
(0w58,0w58,77),
(0w60,0w64,77),
(0w92,0w92,77),
(0w94,0w94,77),
(0w96,0w96,77),
(0w124,0w124,77),
(0w126,0w126,77)], [38, 54, 72]), ([], [31, 72]), ([(0w33,0w33,77),
(0w35,0w38,77),
(0w42,0w43,77),
(0w45,0w45,77),
(0w47,0w47,77),
(0w58,0w58,77),
(0w60,0w64,77),
(0w92,0w92,77),
(0w94,0w94,77),
(0w96,0w96,77),
(0w124,0w124,77),
(0w126,0w126,77)], [39, 54, 72]), ([], [44, 72]), ([(0w33,0w33,77),
(0w35,0w38,77),
(0w42,0w43,77),
(0w58,0w58,77),
(0w60,0w62,77),
(0w64,0w64,77),
(0w92,0w92,77),
(0w94,0w94,77),
(0w96,0w96,77),
(0w124,0w124,77),
(0w126,0w126,77),
(0w39,0w39,84),
(0w48,0w57,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w122,84),
(0w45,0w45,159),
(0w47,0w47,159),
(0w63,0w63,159)], [53, 54, 72]), ([(0w46,0w46,79),
(0w48,0w57,156),
(0w120,0w120,157)], [55, 72]), ([(0w46,0w46,79),
(0w48,0w57,156)], [55, 72]), ([(0w33,0w33,77),
(0w35,0w38,77),
(0w42,0w43,77),
(0w45,0w45,77),
(0w47,0w47,77),
(0w58,0w58,77),
(0w60,0w64,77),
(0w92,0w92,77),
(0w94,0w94,77),
(0w96,0w96,77),
(0w124,0w124,77),
(0w126,0w126,77)], [35, 54, 72]), ([], [32, 72]), ([(0w33,0w33,77),
(0w35,0w38,77),
(0w42,0w43,77),
(0w47,0w47,77),
(0w58,0w58,77),
(0w60,0w64,77),
(0w92,0w92,77),
(0w94,0w94,77),
(0w96,0w96,77),
(0w124,0w124,77),
(0w126,0w126,77),
(0w45,0w45,155)], [40, 54, 72]), ([(0w33,0w33,77),
(0w35,0w38,77),
(0w42,0w43,77),
(0w45,0w45,77),
(0w47,0w47,77),
(0w58,0w58,77),
(0w60,0w64,77),
(0w92,0w92,77),
(0w94,0w94,77),
(0w96,0w96,77),
(0w124,0w124,77),
(0w126,0w126,77)], [30, 54, 72]), ([(0w33,0w33,77),
(0w35,0w38,77),
(0w42,0w43,77),
(0w45,0w45,77),
(0w47,0w47,77),
(0w58,0w58,77),
(0w60,0w64,77),
(0w92,0w92,77),
(0w94,0w94,77),
(0w96,0w96,77),
(0w124,0w124,77),
(0w126,0w126,77)], [41, 54, 72]), ([(0w33,0w33,77),
(0w35,0w38,77),
(0w42,0w43,77),
(0w45,0w45,77),
(0w47,0w47,77),
(0w58,0w58,77),
(0w60,0w64,77),
(0w92,0w92,77),
(0w94,0w94,77),
(0w96,0w96,77),
(0w124,0w124,77),
(0w126,0w126,77)], [28, 54, 72]), ([(0w39,0w39,154),
(0w45,0w45,154),
(0w47,0w57,154),
(0w63,0w63,154),
(0w65,0w90,154),
(0w95,0w95,154),
(0w97,0w122,154)], [52, 53, 72]), ([], [22, 72]), ([], [23, 72]), ([(0w33,0w33,77),
(0w35,0w38,77),
(0w42,0w43,77),
(0w45,0w45,77),
(0w47,0w47,77),
(0w58,0w58,77),
(0w60,0w64,77),
(0w92,0w92,77),
(0w94,0w94,77),
(0w96,0w96,77),
(0w124,0w124,77),
(0w126,0w126,77)], [33, 54, 72]), ([], [26, 72]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w109,84),
(0w111,0w122,84),
(0w110,0w110,148)], [53, 72]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w122,84)], [53, 72]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w98,0w122,84),
(0w97,0w97,145)], [53, 72]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w98,0w104,84),
(0w106,0w110,84),
(0w112,0w122,84),
(0w97,0w97,135),
(0w105,0w105,136),
(0w111,0w111,137)], [53, 72]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w107,84),
(0w109,0w109,84),
(0w111,0w119,84),
(0w121,0w122,84),
(0w108,0w108,125),
(0w110,0w110,126),
(0w120,0w120,127)], [53, 72]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w113,84),
(0w115,0w122,84),
(0w114,0w114,115)], [53, 72]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w101,84),
(0w103,0w109,84),
(0w111,0w122,84),
(0w102,0w102,108),
(0w110,0w110,109)], [53, 72]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w100,84),
(0w102,0w122,84),
(0w101,0w101,106)], [53, 72]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w101,84),
(0w103,0w113,84),
(0w115,0w122,84),
(0w102,0w102,100),
(0w114,0w114,101)], [53, 72]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w98,0w122,84),
(0w97,0w97,96)], [53, 72]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w103,84),
(0w105,0w120,84),
(0w122,0w122,84),
(0w104,0w104,90),
(0w121,0w121,91)], [53, 72]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w98,0w122,84),
(0w97,0w97,88)], [53, 72]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w104,84),
(0w106,0w122,84),
(0w105,0w105,85)], [53, 72]), ([], [24, 72]), ([(0w33,0w33,77),
(0w35,0w38,77),
(0w42,0w43,77),
(0w45,0w45,77),
(0w47,0w47,77),
(0w58,0w58,77),
(0w60,0w64,77),
(0w92,0w92,77),
(0w94,0w94,77),
(0w96,0w96,77),
(0w124,0w124,77),
(0w126,0w126,77)], [34, 54, 72]), ([], [25, 72]), ([(0w33,0w33,77),
(0w35,0w38,77),
(0w42,0w43,77),
(0w45,0w45,77),
(0w47,0w47,77),
(0w58,0w58,77),
(0w60,0w64,77),
(0w92,0w92,77),
(0w94,0w94,77),
(0w96,0w96,77),
(0w124,0w124,77),
(0w126,0w126,77),
(0w48,0w57,78)], [42, 54, 72]), ([(0w33,0w33,77),
(0w35,0w38,77),
(0w42,0w43,77),
(0w45,0w45,77),
(0w47,0w47,77),
(0w58,0w58,77),
(0w60,0w64,77),
(0w92,0w92,77),
(0w94,0w94,77),
(0w96,0w96,77),
(0w124,0w124,77),
(0w126,0w126,77)], [54]), ([(0w46,0w46,79),
(0w48,0w57,78)], [56]), ([(0w48,0w57,80)], []), ([(0w48,0w57,80),
(0w69,0w69,81),
(0w101,0w101,81)], [57]), ([(0w43,0w43,82),
(0w126,0w126,82),
(0w48,0w57,83)], []), ([(0w48,0w57,83)], []), ([(0w48,0w57,83)], [57]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w122,84)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w115,84),
(0w117,0w122,84),
(0w116,0w116,86)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w103,84),
(0w105,0w122,84),
(0w104,0w104,87)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w122,84)], [1, 53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w107,84),
(0w109,0w122,84),
(0w108,0w108,89)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w122,84)], [12, 53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w100,84),
(0w102,0w122,84),
(0w101,0w101,94)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w111,84),
(0w113,0w122,84),
(0w112,0w112,92)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w100,84),
(0w102,0w122,84),
(0w101,0w101,93)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w122,84)], [5, 53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w109,84),
(0w111,0w122,84),
(0w110,0w110,95)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w122,84)], [8, 53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w104,84),
(0w106,0w122,84),
(0w105,0w105,97)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w114,84),
(0w116,0w122,84),
(0w115,0w115,98)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w100,84),
(0w102,0w122,84),
(0w101,0w101,99)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w122,84)], [6, 53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w122,84)], [21, 53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w100,84),
(0w102,0w122,84),
(0w101,0w101,102)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w107,84),
(0w109,0w122,84),
(0w108,0w108,103)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w114,84),
(0w116,0w122,84),
(0w115,0w115,104)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w100,84),
(0w102,0w122,84),
(0w101,0w101,105)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w122,84)], [18, 53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w115,84),
(0w117,0w122,84),
(0w116,0w116,107)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w122,84)], [11, 53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w122,84)], [7, 53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w98,84),
(0w100,0w122,84),
(0w99,0w99,110)], [15, 53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w107,84),
(0w109,0w122,84),
(0w108,0w108,111)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w116,84),
(0w118,0w122,84),
(0w117,0w117,112)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w99,84),
(0w101,0w122,84),
(0w100,0w100,113)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w100,84),
(0w102,0w122,84),
(0w101,0w101,114)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w122,84)], [2, 53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w98,0w122,84),
(0w97,0w97,116)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w109,84),
(0w111,0w122,84),
(0w110,0w110,117)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w116,84),
(0w118,0w122,84),
(0w117,0w117,118)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w107,84),
(0w109,0w122,84),
(0w108,0w108,119)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w98,0w122,84),
(0w97,0w97,120)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w113,84),
(0w115,0w122,84),
(0w114,0w114,121)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w104,84),
(0w106,0w122,84),
(0w105,0w105,122)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w115,84),
(0w117,0w122,84),
(0w116,0w116,123)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w120,84),
(0w122,0w122,84),
(0w121,0w121,124)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w122,84)], [0, 53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w114,84),
(0w116,0w122,84),
(0w115,0w115,133)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w99,84),
(0w101,0w122,84),
(0w100,0w100,132)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w111,84),
(0w113,0w122,84),
(0w112,0w112,128)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w110,84),
(0w112,0w122,84),
(0w111,0w111,129)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w113,84),
(0w115,0w122,84),
(0w114,0w114,130)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w115,84),
(0w117,0w122,84),
(0w116,0w116,131)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w122,84)], [3, 53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w122,84)], [13, 53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w100,84),
(0w102,0w122,84),
(0w101,0w101,134)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w122,84)], [9, 53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w115,84),
(0w117,0w122,84),
(0w116,0w116,139)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w117,84),
(0w119,0w122,84),
(0w118,0w118,138)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w122,84)], [14, 53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w122,84)], [16, 53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w98,0w122,84),
(0w97,0w97,140)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w115,84),
(0w117,0w122,84),
(0w116,0w116,141)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w120,84),
(0w122,0w122,84),
(0w121,0w121,142)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w111,84),
(0w113,0w122,84),
(0w112,0w112,143)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w100,84),
(0w102,0w122,84),
(0w101,0w101,144)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w122,84)], [4, 53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w114,84),
(0w116,0w122,84),
(0w115,0w115,146)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w100,84),
(0w102,0w122,84),
(0w101,0w101,147)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w122,84)], [10, 53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w99,84),
(0w101,0w122,84),
(0w100,0w100,149)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w98,0w122,84),
(0w97,0w97,150)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w107,84),
(0w109,0w122,84),
(0w108,0w108,151)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w114,84),
(0w116,0w122,84),
(0w115,0w115,152)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w110,84),
(0w112,0w122,84),
(0w111,0w111,153)], [53]), ([(0w39,0w39,84),
(0w45,0w45,84),
(0w47,0w57,84),
(0w63,0w63,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w122,84)], [17, 53]), ([(0w39,0w39,154),
(0w45,0w45,154),
(0w47,0w57,154),
(0w63,0w63,154),
(0w65,0w90,154),
(0w95,0w95,154),
(0w97,0w122,154)], [52, 53]), ([(0w33,0w33,77),
(0w35,0w38,77),
(0w42,0w43,77),
(0w45,0w45,77),
(0w47,0w47,77),
(0w58,0w58,77),
(0w60,0w64,77),
(0w92,0w92,77),
(0w94,0w94,77),
(0w96,0w96,77),
(0w124,0w124,77),
(0w126,0w126,77)], [19, 54]), ([(0w46,0w46,79),
(0w48,0w57,156)], [55]), ([(0w48,0w57,158),
(0w65,0w70,158),
(0w97,0w102,158)], []), ([(0w48,0w57,158),
(0w65,0w70,158),
(0w97,0w102,158)], [58]), ([(0w33,0w33,77),
(0w35,0w38,77),
(0w42,0w43,77),
(0w58,0w58,77),
(0w60,0w62,77),
(0w64,0w64,77),
(0w92,0w92,77),
(0w94,0w94,77),
(0w96,0w96,77),
(0w124,0w124,77),
(0w126,0w126,77),
(0w39,0w39,84),
(0w48,0w57,84),
(0w65,0w90,84),
(0w95,0w95,84),
(0w97,0w122,84),
(0w45,0w45,159),
(0w47,0w47,159),
(0w63,0w63,159)], [53, 54]), ([], [60]), ([(0w0,0w9,161),
(0w11,0w2147483647,161)], [62]), ([], [63]), ([(0w0,0w9,161),
(0w11,0w32,161),
(0w34,0w34,161),
(0w39,0w41,161),
(0w44,0w44,161),
(0w46,0w46,161),
(0w48,0w57,161),
(0w59,0w59,161),
(0w65,0w91,161),
(0w93,0w93,161),
(0w95,0w95,161),
(0w97,0w123,161),
(0w125,0w125,161),
(0w127,0w2147483647,161),
(0w33,0w33,163),
(0w35,0w38,163),
(0w42,0w43,163),
(0w45,0w45,163),
(0w47,0w47,163),
(0w58,0w58,163),
(0w60,0w64,163),
(0w92,0w92,163),
(0w94,0w94,163),
(0w96,0w96,163),
(0w124,0w124,163),
(0w126,0w126,163)], [54, 62])]
    fun yystreamify' p input = ULexBuffer.mkStream (p, input)

    fun yystreamifyReader' p readFn strm = let
          val s = ref strm
	  fun iter(strm, n, accum) = 
	        if n > 1024 then (String.implode (rev accum), strm)
		else (case readFn strm
		       of NONE => (String.implode (rev accum), strm)
			| SOME(c, strm') => iter (strm', n+1, c::accum))
          fun input() = let
	        val (data, strm) = iter(!s, 0, [])
	        in
	          s := strm;
		  data
	        end
          in
            yystreamify' p input
          end

    fun yystreamifyInstream' p strm = yystreamify' p (fn ()=>TextIO.input strm)

    fun innerLex 
(yyarg as  lexErr)(yystrm_, yyss_, yysm) = let
        (* current start state *)
          val yyss = ref yyss_
	  fun YYBEGIN ss = (yyss := ss)
	(* current input stream *)
          val yystrm = ref yystrm_
	  fun yysetStrm strm = yystrm := strm
	  fun yygetPos() = ULexBuffer.getpos (!yystrm)
	  fun yystreamify input = yystreamify' (yygetPos()) input
	  fun yystreamifyReader readFn strm = yystreamifyReader' (yygetPos()) readFn strm
	  fun yystreamifyInstream strm = yystreamifyInstream' (yygetPos()) strm
        (* start position of token -- can be updated via skip() *)
	  val yystartPos = ref (yygetPos())
	(* get one char of input *)
	  fun yygetc strm = (case UTF8.getu ULexBuffer.getc strm
                of (SOME (0w10, s')) => 
		     (AntlrStreamPos.markNewLine yysm (ULexBuffer.getpos strm);
		      SOME (0w10, s'))
		 | x => x)
          fun yygetList getc strm = let
            val get1 = UTF8.getu getc
            fun iter (strm, accum) = 
	        (case get1 strm
	          of NONE => rev accum
	           | SOME (w, strm') => iter (strm', w::accum)
	         (* end case *))
          in
            iter (strm, [])
          end
	(* create yytext *)
	  fun yymksubstr(strm) = ULexBuffer.subtract (strm, !yystrm)
	  fun yymktext(strm) = Substring.string (yymksubstr strm)
	  fun yymkunicode(strm) = yygetList Substring.getc (yymksubstr strm)
          open UserDeclarations
          fun lex () = let
            fun yystuck (yyNO_MATCH) = raise Fail "lexer reached a stuck state"
	      | yystuck (yyMATCH (strm, action, old)) = 
		  action (strm, old)
	    val yypos = yygetPos()
	    fun yygetlineNo strm = AntlrStreamPos.lineNo yysm (ULexBuffer.getpos strm)
	    fun yygetcolNo  strm = AntlrStreamPos.colNo  yysm (ULexBuffer.getpos strm)
	    fun yyactsToMatches (strm, [],	  oldMatches) = oldMatches
	      | yyactsToMatches (strm, act::acts, oldMatches) = 
		  yyMATCH (strm, act, yyactsToMatches (strm, acts, oldMatches))
	    fun yygo actTable = 
		(fn (~1, _, oldMatches) => yystuck oldMatches
		  | (curState, strm, oldMatches) => let
		      val (transitions, finals') = Vector.sub (yytable, curState)
		      val finals = map (fn i => Vector.sub (actTable, i)) finals'
		      fun tryfinal() = 
		            yystuck (yyactsToMatches (strm, finals, oldMatches))
		      fun find (c, []) = NONE
			| find (c, (c1, c2, s)::ts) = 
		            if c1 <= c andalso c <= c2 then SOME s
			    else find (c, ts)
		      in case yygetc strm
			  of SOME(c, strm') => 
			       (case find (c, transitions)
				 of NONE => tryfinal()
				  | SOME n => 
				      yygo actTable
					(n, strm', 
					 yyactsToMatches (strm, finals, oldMatches)))
			   | NONE => tryfinal()
		      end)
	    val yylastwasnref = ref (ULexBuffer.lastWasNL (!yystrm))
	    fun continue() = let val yylastwasn = !yylastwasnref in
let
fun yyAction0 (strm, lastMatch : yymatch) = (yystrm := strm;  T.KW_granularity)
fun yyAction1 (strm, lastMatch : yymatch) = (yystrm := strm;  T.KW_with)
fun yyAction2 (strm, lastMatch : yymatch) = (yystrm := strm;  T.KW_include)
fun yyAction3 (strm, lastMatch : yymatch) = (yystrm := strm;  T.KW_export)
fun yyAction4 (strm, lastMatch : yymatch) = (yystrm := strm;  T.KW_datatype)
fun yyAction5 (strm, lastMatch : yymatch) = (yystrm := strm;  T.KW_type)
fun yyAction6 (strm, lastMatch : yymatch) = (yystrm := strm;  T.KW_raise)
fun yyAction7 (strm, lastMatch : yymatch) = (yystrm := strm;  T.KW_if)
fun yyAction8 (strm, lastMatch : yymatch) = (yystrm := strm;  T.KW_then)
fun yyAction9 (strm, lastMatch : yymatch) = (yystrm := strm;  T.KW_else)
fun yyAction10 (strm, lastMatch : yymatch) = (yystrm := strm;  T.KW_case)
fun yyAction11 (strm, lastMatch : yymatch) = (yystrm := strm;  T.KW_let)
fun yyAction12 (strm, lastMatch : yymatch) = (yystrm := strm;  T.KW_val)
fun yyAction13 (strm, lastMatch : yymatch) = (yystrm := strm;  T.KW_end)
fun yyAction14 (strm, lastMatch : yymatch) = (yystrm := strm;  T.KW_do)
fun yyAction15 (strm, lastMatch : yymatch) = (yystrm := strm;  T.KW_in)
fun yyAction16 (strm, lastMatch : yymatch) = (yystrm := strm;  T.KW_div)
fun yyAction17 (strm, lastMatch : yymatch) = (yystrm := strm;  T.KW_and)
fun yyAction18 (strm, lastMatch : yymatch) = (yystrm := strm;  T.KW_or)
fun yyAction19 (strm, lastMatch : yymatch) = (yystrm := strm;  T.BIND)
fun yyAction20 (strm, lastMatch : yymatch) = (yystrm := strm;  T.KW_mod)
fun yyAction21 (strm, lastMatch : yymatch) = (yystrm := strm;  T.KW_of)
fun yyAction22 (strm, lastMatch : yymatch) = (yystrm := strm;  T.LB)
fun yyAction23 (strm, lastMatch : yymatch) = (yystrm := strm;  T.RB)
fun yyAction24 (strm, lastMatch : yymatch) = (yystrm := strm;  T.LCB)
fun yyAction25 (strm, lastMatch : yymatch) = (yystrm := strm;  T.RCB)
fun yyAction26 (strm, lastMatch : yymatch) = (yystrm := strm;  T.WILD)
fun yyAction27 (strm, lastMatch : yymatch) = (yystrm := strm;  T.TIMES)
fun yyAction28 (strm, lastMatch : yymatch) = (yystrm := strm;  T.WITH)
fun yyAction29 (strm, lastMatch : yymatch) = (yystrm := strm;  T.SELECT)
fun yyAction30 (strm, lastMatch : yymatch) = (yystrm := strm;  T.EQ)
fun yyAction31 (strm, lastMatch : yymatch) = (yystrm := strm;  T.COMMA)
fun yyAction32 (strm, lastMatch : yymatch) = (yystrm := strm;  T.SEMI)
fun yyAction33 (strm, lastMatch : yymatch) = (yystrm := strm;  T.CONCAT)
fun yyAction34 (strm, lastMatch : yymatch) = (yystrm := strm;  T.BAR)
fun yyAction35 (strm, lastMatch : yymatch) = (yystrm := strm;  T.COLON)
fun yyAction36 (strm, lastMatch : yymatch) = (yystrm := strm;  T.LP)
fun yyAction37 (strm, lastMatch : yymatch) = (yystrm := strm;  T.RP)
fun yyAction38 (strm, lastMatch : yymatch) = (yystrm := strm;  T.PLUS)
fun yyAction39 (strm, lastMatch : yymatch) = (yystrm := strm;  T.MINUS)
fun yyAction40 (strm, lastMatch : yymatch) = (yystrm := strm;  T.LESSTHAN)
fun yyAction41 (strm, lastMatch : yymatch) = (yystrm := strm;  T.GREATERTHAN)
fun yyAction42 (strm, lastMatch : yymatch) = (yystrm := strm;  T.TILDE)
fun yyAction43 (strm, lastMatch : yymatch) = (yystrm := strm;
       YYBEGIN BITPAT; T.TICK)
fun yyAction44 (strm, lastMatch : yymatch) = (yystrm := strm;  T.DOT)
fun yyAction45 (strm, lastMatch : yymatch) = (yystrm := strm;
       YYBEGIN BITPATNUM; T.COLON)
fun yyAction46 (strm, lastMatch : yymatch) = (yystrm := strm;
       YYBEGIN INITIAL; T.TICK)
fun yyAction47 (strm, lastMatch : yymatch) = (yystrm := strm;  T.WITH)
fun yyAction48 (strm, lastMatch : yymatch) = let
      val yytext = yymktext(strm)
      in
        yystrm := strm;  T.BITSTR yytext
      end
fun yyAction49 (strm, lastMatch : yymatch) = let
      val yytext = yymktext(strm)
      in
        yystrm := strm;  T.ID (Atom.atom yytext)
      end
fun yyAction50 (strm, lastMatch : yymatch) = (yystrm := strm;  skip ())
fun yyAction51 (strm, lastMatch : yymatch) = (yystrm := strm;
       YYBEGIN BITPAT; skip())
fun yyAction52 (strm, lastMatch : yymatch) = let
      val yytext = yymktext(strm)
      in
        yystrm := strm;  T.CONS (Atom.atom yytext)
      end
fun yyAction53 (strm, lastMatch : yymatch) = let
      val yytext = yymktext(strm)
      in
        yystrm := strm;  T.ID (Atom.atom yytext)
      end
fun yyAction54 (strm, lastMatch : yymatch) = let
      val yytext = yymktext(strm)
      in
        yystrm := strm;  T.SYMBOL (Atom.atom yytext)
      end
fun yyAction55 (strm, lastMatch : yymatch) = let
      val yytext = yymktext(strm)
      in
        yystrm := strm;  T.POSINT(valOf (IntInf.fromString yytext))
      end
fun yyAction56 (strm, lastMatch : yymatch) = let
      val yytext = yymktext(strm)
      in
        yystrm := strm;  T.NEGINT(valOf (IntInf.fromString yytext))
      end
fun yyAction57 (strm, lastMatch : yymatch) = let
      val yysubstr = yymksubstr(strm)
      in
        yystrm := strm;  mkFloat yysubstr
      end
fun yyAction58 (strm, lastMatch : yymatch) = let
      val yytext = yymktext(strm)
      in
        yystrm := strm;  T.POSINT(fromHexString yytext)
      end
fun yyAction59 (strm, lastMatch : yymatch) = (yystrm := strm;  skip ())
fun yyAction60 (strm, lastMatch : yymatch) = (yystrm := strm;
       YYBEGIN COMMENT; depth := 1; skip())
fun yyAction61 (strm, lastMatch : yymatch) = (yystrm := strm;
       YYBEGIN STRING; skip())
fun yyAction62 (strm, lastMatch : yymatch) = (yystrm := strm;  skip())
fun yyAction63 (strm, lastMatch : yymatch) = (yystrm := strm;  skip())
fun yyAction64 (strm, lastMatch : yymatch) = let
      val yytext = yymktext(strm)
      in
        yystrm := strm;  addStr(valOf(String.fromString yytext)); continue()
      end
fun yyAction65 (strm, lastMatch : yymatch) = let
      val yytext = yymktext(strm)
      in
        yystrm := strm;  addStr yytext; continue()
      end
fun yyAction66 (strm, lastMatch : yymatch) = (yystrm := strm;
       YYBEGIN INITIAL; mkString())
fun yyAction67 (strm, lastMatch : yymatch) = let
      val yytext = yymktext(strm)
      in
        yystrm := strm;
        
   lexErr
      (yypos,
       ["bad escape character `", String.toString yytext,
		  "' in string literal"])
   ;continue()
      end
fun yyAction68 (strm, lastMatch : yymatch) = let
      val yytext = yymktext(strm)
      in
        yystrm := strm;
        
   lexErr
      (yypos,
       ["bad character `", String.toString yytext,
		  "' in string literal"])
   ;continue()
      end
fun yyAction69 (strm, lastMatch : yymatch) = (yystrm := strm;
      
   depth := !depth + 1
	;skip())
fun yyAction70 (strm, lastMatch : yymatch) = (yystrm := strm;
      
   depth := !depth - 1
   ;if (!depth = 0) then YYBEGIN INITIAL else ()
	;skip ())
fun yyAction71 (strm, lastMatch : yymatch) = (yystrm := strm;  skip ())
fun yyAction72 (strm, lastMatch : yymatch) = let
      val yytext = yymktext(strm)
      in
        yystrm := strm;
        
   lexErr
      (yypos,
       ["bad character `", String.toString yytext, "'"])
   ;continue()
      end
val yyactTable = Vector.fromList([yyAction0, yyAction1, yyAction2, yyAction3,
  yyAction4, yyAction5, yyAction6, yyAction7, yyAction8, yyAction9, yyAction10,
  yyAction11, yyAction12, yyAction13, yyAction14, yyAction15, yyAction16,
  yyAction17, yyAction18, yyAction19, yyAction20, yyAction21, yyAction22,
  yyAction23, yyAction24, yyAction25, yyAction26, yyAction27, yyAction28,
  yyAction29, yyAction30, yyAction31, yyAction32, yyAction33, yyAction34,
  yyAction35, yyAction36, yyAction37, yyAction38, yyAction39, yyAction40,
  yyAction41, yyAction42, yyAction43, yyAction44, yyAction45, yyAction46,
  yyAction47, yyAction48, yyAction49, yyAction50, yyAction51, yyAction52,
  yyAction53, yyAction54, yyAction55, yyAction56, yyAction57, yyAction58,
  yyAction59, yyAction60, yyAction61, yyAction62, yyAction63, yyAction64,
  yyAction65, yyAction66, yyAction67, yyAction68, yyAction69, yyAction70,
  yyAction71, yyAction72])
in
  if ULexBuffer.eof(!(yystrm))
    then let
      val yycolno = ref(yygetcolNo(!(yystrm)))
      val yylineno = ref(yygetlineNo(!(yystrm)))
      in
        (case (!(yyss))
         of _ => (UserDeclarations.eof())
        (* end case *))
      end
    else (case (!(yyss))
       of STRING => yygo yyactTable (0, !(yystrm), yyNO_MATCH)
        | COMMENT => yygo yyactTable (1, !(yystrm), yyNO_MATCH)
        | BITPATNUM => yygo yyactTable (2, !(yystrm), yyNO_MATCH)
        | BITPAT => yygo yyactTable (3, !(yystrm), yyNO_MATCH)
        | INITIAL => yygo yyactTable (4, !(yystrm), yyNO_MATCH)
      (* end case *))
end
end
            and skip() = (yystartPos := yygetPos(); 
			  yylastwasnref := ULexBuffer.lastWasNL (!yystrm);
			  continue())
	    in (continue(), (!yystartPos, yygetPos()), !yystrm, !yyss) end
          in 
            lex()
          end
  in
    type pos = AntlrStreamPos.pos
    type span = AntlrStreamPos.span
    type tok = UserDeclarations.lex_result

    datatype prestrm = STRM of ULexBuffer.stream * 
		(yystart_state * tok * span * prestrm * yystart_state) option ref
    type strm = (prestrm * yystart_state)

    fun lex sm 
(yyarg as  lexErr)(STRM (yystrm, memo), ss) = (case !memo
	  of NONE => let
	     val (tok, span, yystrm', ss') = innerLex 
yyarg(yystrm, ss, sm)
	     val strm' = STRM (yystrm', ref NONE);
	     in 
	       memo := SOME (ss, tok, span, strm', ss');
	       (tok, span, (strm', ss'))
	     end
	   | SOME (ss', tok, span, strm', ss'') => 
	       if ss = ss' then
		 (tok, span, (strm', ss''))
	       else (
		 memo := NONE;
		 lex sm 
yyarg(STRM (yystrm, memo), ss))
         (* end case *))

    fun streamify input = (STRM (yystreamify' 0 input, ref NONE), INITIAL)
    fun streamifyReader readFn strm = (STRM (yystreamifyReader' 0 readFn strm, ref NONE), 
				       INITIAL)
    fun streamifyInstream strm = (STRM (yystreamifyInstream' 0 strm, ref NONE), 
				  INITIAL)

    fun getPos (STRM (strm, _), _) = ULexBuffer.getpos strm

  end
end
