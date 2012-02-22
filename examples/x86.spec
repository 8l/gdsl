(* Nested
 * (* multiline
 *  * comments *)
 *)

granularity = 32

datatype rex = REX of { w:1, r:1, x:1, b:1 }

# The state of the decode monad
state =
   {mode64:1=0,
    rep:1=0,
    rexw:1=0,
    opndsz:1=0,
    addrsz:1=0,
    rex:rex = REX { w = 0, r = 0,  x = 0, b = 0 }
    }

#include "x86-registers.spec"

datatype register =
   AL | AH | AX | EAX | RAX | XMM0
 | CL | CH | CX | ECX | RCX | XMM1
 | DL | DH | DX | EDX | RDX | XMM2
 | BL | BH | BX | EBX | RBX | XMM3
 | SP | ESP | RSP | XMM4
 | BP | EBP | RBP | XMM5
 | SI | ESI | RSI | XMM6
 | DI | EDI | RDI | XMM7

datatype opnd =
   REG of {sizeinbits: int, reg: register}
 | MEM of {accesssize: int, opnd: opnd}
 | IMM of {sizeinbits: int, value: int}
 | BIN of {op: string, left:opnd, right:opnd}
 | IMM8 of 8
 | IMM16 of 16
 | IMM32 of 32

type binop = {op1:opnd, op2:opnd}

datatype insn =
   MOV of binop
 | ADD of binop
 | SUB of binop
 | MUL of binop
 | DIV of binop

datatype size =
	B | W

# Example of bit-patterns
dec /0 ['mod:2 001 rm:3'] = update @{mod=mod, rm=rm, reg/opcode=1}
dec /r ['mod:2 reg/opcode:3 rm:3'] = update @{mod=mod, reg/opcode=reg/opcode, rm=rm}

val fromEnum i =
   case i of
      '0000': RAX
    | '0001': RBX

dec imm8 ['byte:8'] = return (IMM8 {value=byte})
dec imm16 ['byte1:8' 'byte2:8'] = return (IMM16 {value=byte1 ^ byte2})
dec imm32 ['byte1:8' 'byte2:8' 'byte3:8' 'byte4:8'] =
  return (IMM16 {value=byte1 ^ byte2 ^ byte3 ^ byte4})

# The 's' action reads one bit and updates the monadic state
dec s ['sizeBit:1'] = let
   val sizeBit =
      case sizeBit of
         '0': B
       | '1': W
   val someTag =
      case sizeBit of
         '0': W
       | '1': B
in
   update {size=someTag}
end

# `imm` is a monadic action that reads 8 or 16 bits, depending on the current
# state
val imm = do
   sizeTag <- query $size;
   case sizeTag of
      B: imm8
    | W: imm16
end

val regN num size =
   case num of
       '000': (case size of
	         128: XMM0
	       |  64: RAX
	       |  32: EAX
	       |  16: AX
	       |   8: AL)
     | '001': (case size of
	         128: XMM1
	       |  64: RCX
	       |  32: ECX
	       |  16: CX
	       |   8: CL)
     | '010': (case size of
	         128: XMM2
	       |  64: RDX
	       |  32: EDX
	       |  16: DX
	       |   8: DL)
     | '011': (case size of
	         128: XMM3
	       |  64: RBX
	       |  32: EBX
	       |  16: BX
	       |   8: BL)
     | '100': (case size of
	         128: XMM4
	       |  64: RSP
	       |  32: ESP
	       |  16: SP
	       |   8: AH)
     | '101': (case size of
	         128: XMM5
	       |  64: RBP
	       |  32: EBP
	       |  16: BP
	       |   8: CH)
     | '110': (case size of
	         128: XMM6
	       |  64: RSI
	       |  32: ESI
	       |  16: SI
	       |   8: DH)
     | '111': (case size of
	         128: XMM7
	       |  64: RDI
	       |  32: EDI
	       |  16: DI
	       |   8: BH)


val operandSize = do
	rex <- query $rex;
	opndsz <- query $opndsz;
	case ($w rex) of
	   '0': (case opndsz of
	   	    '0': return 32
		  | '1': return 16)
	 | '1': return 64
end

val addressSize = do
	addrsz <- query $addrsz;
	case addrsz of
	   '0': return 64
	 | '1': return 32
end

val r/m = do
   mod <- query $mod;
   rm <- query $rm;
   case mod of
#      '00': case rm of
#             ...
(*    |*) '11': return (regN rm 32)
end

val r/m16 = do
	42
end

val r16 = do
   reg <- query $reg;
   return (regN reg 32)
end

val r32 = return EAX

val r/m32 = return EAX

val r64 = return RAX

val r/m64 = return RAX

val mov a1 a2 = do
   a1 <- a1;
   a2 <- a2;
   return (MOV {op1=a1, op2=a2})
end

dec [0x80 /r]
   | opndsz = mov r/m16 r16
   | rexw = mov r/m64 r64
   | otherwise = mov r/m32 r32

dec [0x66 0xC7 /0]
   | opndsz = mov r16 imm16
   | otherwise = mov r32 imm32

dec [0x66] = do update @{opndsz=1}; continue end
dec [0x67] = do update @{addrsz=1}; continue end
