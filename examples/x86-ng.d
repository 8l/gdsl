granularity = 8
export = main decode

# Optional arguments
#
# Limit:
#   - Restricts the maximium size of the decode-stream
# Recursion-depth:
#   - Annotate the maximum number of recursion steps for
#     the given decoder. This way, we can compute an upper
#     bound for the maximum used storage for the emitted AST.
#     Additionally, the decoder may fail if during runtime
#     a recrusion depth violation occurs.
#
# limit = 120
# recursion-depth = main = 4

val decode = do
   update
      @{mode64='1',
        repne='0',
        rep='0',
        rex='0',
        rexw='0',
        rexb='0',
        rexr='0',
        rexx='0',
        opndsz='0',
        addrsz='0',
        segment=DS,
        mod='00',
        reg/opcode='000',
        rm='000',
        ptrty=32};
   p64
end

val set-opndsz = update@{opndsz='1'}
val set-repne = update@{repne='1'}
val set-rep = update@{rep='1'}

val set-CS = update@{segment=CS}
val set-DS = update@{segment=DS}
val set-ES = update@{segment=ES}
val set-FS = update@{segment=FS}
val set-GS = update@{segment=GS}
val set-SS = update@{segment=SS}
val set-addrsz = update@{addrsz='1'}

## Decoding prefixes

val /legacy-p [0x2e] = set-CS
val /legacy-p [0x36] = set-SS
val /legacy-p [0x3e] = set-DS
val /legacy-p [0x26] = set-ES
val /legacy-p [0x64] = set-FS
val /legacy-p [0x65] = set-GS
val /legacy-p [0x67] = set-addrsz

val /rex ['0100 w:1 r:1 x:1 b:1'] =
   update @{rex='1', rexw=w, rexb=b, rexx=x, rexr=r}
val clear-rex = update @{rexw='0',rexb='0',rexr='0',rexx='0'}

val p64 [0x66] = do set-opndsz; p/66 end
val p64 [0xf2] = do set-repne; p/f2 end
val p64 [0xf3] = do set-rep; p/f3 end
val p64 [/legacy-p] = p64
val p64 [/rex] = p64
val p64 [] = main

val p/66 [0xf2] = do set-repne; p/66/f2 end
val p/66 [0xf3] = do set-rep; p/66/f3 end
val p/66 [0x66] = p/66
val p/66 [] = do set-tab main; /66 end

val p/f2 [0x66] = do set-opndsz; p/f2/66 end
val p/f2 [0xf2] = p/f2
val p/f2 [0xf3] = do set-rep; p/f2/f3 end
val p/f2 [] = do set-tab main; /f2 end 

val p/f3 [0x66] = do set-opndsz; p/f3/66 end
val p/f3 [0xf2] = do set-repne; p/f3/f2 end
val p/f3 [0xf3] = p/f3
val p/f3 [] = do set-tab main; /f3 end 

val p/f2/f3 [0x66] = do set-opndsz; p/f2/f3/66 end
val p/f2/f3 [0xf2] = p/f3/f2
val p/f2/f3 [0xf3] = p/f2/f3
val p/f2/f3 [] = try-f3/f2

val p/f3/f2 [0x66] = do set-opndsz; p/f2/f3/66 end
val p/f3/f2 [0xf2] = p/f3/f2
val p/f3/f2 [0xf3] = p/f2/f3
val p/f3/f2 [] = try-f2/f3

val p/66/f2 [0x66] = p/f2/66
val p/66/f2 [0xf3] = do set-rep; p/66/f2/f3 end
val p/66/f2 [0xf2] = p/66/f2
val p/66/f2 [] = try-f2/66

val p/66/f3 [0x66] = p/f3/66
val p/66/f3 [0xf2] = do set-repne; p/66/f3/f2 end
val p/66/f3 [0xf3] = p/66/f3
val p/66/f3 [] = try-f3/66

val p/f2/66 [0x66] = p/f2/66
val p/f2/66 [0xf2] = p/66/f2
val p/f2/66 [0xf3] = do set-rep; p/f2/66/f3 end
val p/f2/66 [] = try-66/f2

val p/f3/66 [0x66] = p/f3/66
val p/f3/66 [0xf2] = do set-repne; p/f3/66/f2 end
val p/f3/66 [0xf3] = p/66/f3
val p/f3/66 [] = try-66/f3

val p/66/f2/f3 [0x66] = p/f2/f3/66
val p/66/f2/f3 [0xf2] = p/66/f3/f2
val p/66/f2/f3 [0xf3] = p/66/f2/f3
val p/66/f2/f3 [] = do try-f2/66; /f3 end

val p/66/f3/f2 [0x66] = p/f3/f2/66
val p/66/f3/f2 [0xf2] = p/66/f3/f2
val p/66/f3/f2 [0xf3] = p/66/f2/f3
val p/66/f3/f2 [] = do try-f3/66; /f2 end

val p/f3/f2/66 [0x66] = p/f3/f2/66
val p/f3/f2/66 [0xf2] = p/f3/66/f2
val p/f3/f2/66 [0xf3] = p/f2/66/f3 
val p/f3/f2/66 [] = do try-f2/f3; /66 end

val p/f2/f3/66 [0x66] = p/f2/f3/66
val p/f2/f3/66 [0xf2] = p/f3/66/f2
val p/f2/f3/66 [0xf3] = p/f2/66/f3
val p/f2/f3/66 [] = do try-f3/f2; /66 end

val p/f3/66/f2 [0x66] = p/f3/f2/66 
val p/f3/66/f2 [0xf2] = p/f3/66/f2 
val p/f3/66/f2 [0xf3] = p/66/f2/f3
val p/f3/66/f2 [] = do try-66/f3; /f2 end

val p/f2/66/f3 [0x66] = p/f2/f3/66 
val p/f2/66/f3 [0xf2] = p/66/f3/f2
val p/f2/66/f3 [0xf3] = p/f2/66/f3
val p/f2/66/f3 [] = do try-66/f2; /f3 end

val /66 [] = do
   tab <- get-tab;
   tab
end

val /f2 [] = do
   tab <- get-tab;
   tab
end

val /f3 [] = do
   tab <- get-tab;
   tab
end

val try-f3/f2 = do
   set-tab /f2;
   /f3
end

val try-f2/f3 = do
   set-tab /f3;
   /f2
end

val try-f3/66 = do
   set-tab /66;
   /f3
end

val try-66/f3 = do
   set-tab /f3;
   /66
end

val try-f2/66 = do
   set-tab /66;
   /f2
end

val try-66/f2 = do
   set-tab /f2;
   /66
end

val set-tab tab = update@{tab=tab}
val get-tab = query$tab

datatype register =
   AL
 | AH
 | AX
 | EAX
 | RAX
 | BL
 | BH
 | BX
 | EBX
 | RBX
 | CL
 | CH
 | CX
 | ECX
 | RCX
 | DL
 | DH
 | DX
 | EDX
 | RDX
 | R8B
 | R8L
 | R8D
 | R8 
 | R9B
 | R9L
 | R9D
 | R9 
 | R10B
 | R10L
 | R10D
 | R10 
 | R11B
 | R11L
 | R11D
 | R11 
 | R12B
 | R12L
 | R12D
 | R12 
 | R13B
 | R13L
 | R13D
 | R13 
 | R14B
 | R14L
 | R14D
 | R14 
 | R15B
 | R15L
 | R15D
 | R15 
 | SP
 | ESP
 | RSP
 | BP
 | EBP
 | RBP
 | SI
 | ESI
 | RSI
 | DI
 | EDI
 | RDI
 | XMM0
 | XMM1
 | XMM2
 | XMM3
 | XMM4
 | XMM5
 | XMM6
 | XMM7
 | XMM8
 | XMM9
 | XMM10
 | XMM11
 | XMM12
 | XMM13
 | XMM14
 | XMM15
 | YMM0
 | YMM1
 | YMM2
 | YMM3
 | YMM4
 | YMM5
 | YMM6
 | YMM7
 | YMM8
 | YMM9
 | YMM10
 | YMM11
 | YMM12
 | YMM13
 | YMM14
 | YMM15
 | MM0
 | MM1
 | MM2
 | MM3
 | MM4
 | MM5
 | MM6
 | MM7
 | MM8
 | MM9
 | MM10
 | MM11
 | MM12
 | MM13
 | MM14
 | MM15
 | ES
 | SS
 | DS
 | FS
 | GS
 | CS

datatype opnd =
   IMM8 of 8
 | IMM16 of 16
 | IMM32 of 32
 | IMM64 of 64
 | REG of register
 | MEM of {sz: int, segment: register, opnd: opnd}
 | SUM of {a:opnd, b:opnd}
 | SCALE of {imm:2, opnd:opnd}

datatype flowopnd =
   REL8 of 8
 | REL16 of 16
 | REL32 of 32
 | REL64 of 64
 | NEARABS of opnd
 | FARABS of opnd

datatype insn =
   ARITY0 of {tag:mnemonic}
 | ARITY1 of {tag:mnemonic,opnd1:opnd}
 | ARITY2 of {tag:mnemonic,opnd1:opnd,opnd2:opnd}
 | ARITY3 of {tag:mnemonic,opnd1:opnd,opnd2:opnd,opnd3:opnd}
 | ARITY4 of {tag:mnemonic,opnd1:opnd,opnd2:opnd,opnd3:opnd,opnd4:opnd}
 | FLOW1 of {tag:mnemonic,opnd1:flowopnd}

datatype mnemonic =
   ADD
 | CVTPD2PI
 | MASKMOVDQU
 | VMASKMOVDQU
 | MASKMOVQ
 | MAXPD
 | VMAXPD
 | MAXPS
 | VMAXPS
 | MAXSD
 | VMAXSD
 | MAXSS
 | VMAXSS
 | MFENCE
 | MINPD
 | VMINPD
 | MINPS
 | VMINPS
 | MINSD
 | VMINSD
 | MINSS
 | VMINSS
 | MONITOR
 | MOV
 | MOVAPD
 | VMOVAPD
 | MOVAPS
 | VMOVAPS
 | MOVBE
 | MOVD
 | VMOVD
 | MOVQ
 | VMOVQ
 | MOVDDUP
 | VMOVDDUP
 | MOVDQA
 | VMOVDQA
 | MOVDQU
 | VMOVDQU
 | MOVDQ2Q
 | MOVHLPS
 | VMOVHLPS
 | MOVHPD
 | VMOVHPD
 | VBMOVHPD
 | MOVHPS
 | VMOVHPS
 | VBMOVHPS
 | MOVLHPS
 | VMOVLHPS
 | MOVLPD
 | VMOVLPD
 | VBMOVLPD
 | MOVLPS
 | VMOVLPS
 | VBMOVLPS
 | MOVMSKPD
 | VMOVMSKPD
 | MOVMSKPS
 | VMOVMSKPS
 | MOVNTDQA
 | VMOVNTDQA
 | MOVNTDQ
 | VMOVNTDQ
 | MOVNTI
 | MOVNTPD
 | VMOVNTPD
 | MOVNTPS
 | VMOVNTPS
 | MOVNTQ

 | IMUL
 | IMUL_2
 | IMUL_3

 | PUSH
 | POP
 | JMP
 | CALL
 | JA
 | JAE
 | JB
 | JBE
 | JC
 | JCXZ
 | JECXZ
 | JRCXZ
 | JE
 | JG
 | JGE
 | JL
 | JLE
 | JNA
 | JNAE
 | JNB
 | JNBE
 | JNC
 | JNE
 | JNG
 | JNGE
 | JNL
 | JNLE
 | JNO
 | JNP
 | JNS
 | JNZ
 | JO
 | JP
 | JPE
 | JPO
 | JS
 | JZ
 | SETA
 | SETAE
 | SETB
 | SETBE
 | SETC
 | SETE
 | SETG
 | SETGE
 | SETL
 | SETLE
 | SETNA
 | SETNAE
 | SETNB
 | SETNBE
 | SETNC
 | SETNE
 | SETNG
 | SETNGE
 | SETNL
 | SETNLE
 | SETNO
 | SETNP
 | SETNS
 | SETNZ
 | SETO
 | SETP
 | SETPE
 | SETPO
 | SETS
 | SETZ
 | CMOVA
 | CMOVAE
 | CMOVB
 | CMOVBE
 | CMOVC
 | CMOVE
 | CMOVG
 | CMOVGE
 | CMOVL
 | CMOVLE
 | CMOVNA
 | CMOVNAE
 | CMOVNB
 | CMOVNBE
 | CMOVNC
 | CMOVNE
 | CMOVNG
 | CMOVNGE
 | CMOVNL
 | CMOVNLE
 | CMOVNO
 | CMOVNP
 | CMOVNS
 | CMOVNZ
 | CMOVO
 | CMOVP
 | CMOVPE
 | CMOVPO
 | CMOVS
 | CMOVZ
 | RET
 | RETFAR
 | RET_1
 | RETFAR_1
 | LEA
 | TEST
 | CMP
 | SAL
 | SAR
 | SHL
 | SHR
 | SUB
 | XOR
 | INC
 | MOVZX
 | MOVSX
 | OR
 | NOP
 | NOP_1

 | PHADDW
 | VPHADDW
 | PHADDD
 | VPHADDD
 | XADD

val al = return (REG AL)
val ah = return (REG AH)
val ax = return (REG AX)
val eax = return (REG EAX)
val rax = return (REG RAX)
val bl = return (REG BL)
val bh = return (REG BH)
val bx = return (REG BX)
val ebx = return (REG EBX)
val rbx = return (REG RBX)
val cl = return (REG CL)
val ch = return (REG CH)
val cx = return (REG CX)
val ecx = return (REG ECX)
val rcx = return (REG RCX)
val dl = return (REG DL)
val dh = return (REG DH)
val dx = return (REG DX)
val edx = return (REG EDX)
val rdx = return (REG RDX)
val sp = return (REG SP)
val esp = return (REG ESP)
val rsp = return (REG RSP)
val bp = return (REG BP)
val ebp = return (REG EBP)
val rbp = return (REG RBP)
val si = return (REG SI)
val esi = return (REG ESI)
val rsi = return (REG RSI)
val di = return (REG DI)
val edi = return (REG EDI)
val rdi = return (REG RDI)
val cs = return (REG CS)
val ds = return (REG DS)
val es = return (REG ES)
val fs = return (REG FS)
val gs = return (REG GS)
val ss = return (REG SS)
val mm0 = return (REG MM0)
val mm1 = return (REG MM1)
val mm2 = return (REG MM2)
val mm3 = return (REG MM3)
val mm4 = return (REG MM4)
val mm5 = return (REG MM5)
val mm6 = return (REG MM6)
val mm7 = return (REG MM7)
val mm8 = return (REG MM8)
val mm9 = return (REG MM9)
val mm10 = return (REG MM10)
val mm11 = return (REG MM11)
val mm12 = return (REG MM12)
val mm13 = return (REG MM13)
val mm14 = return (REG MM14)
val mm15 = return (REG MM15)
val xmm0 = return (REG XMM0)
val xmm1 = return (REG XMM1)
val xmm2 = return (REG XMM2)
val xmm3 = return (REG XMM3)
val xmm4 = return (REG XMM4)
val xmm5 = return (REG XMM5)
val xmm6 = return (REG XMM6)
val xmm7 = return (REG XMM7)
val xmm8 = return (REG XMM8)
val xmm9 = return (REG XMM9)
val xmm10 = return (REG XMM10)
val xmm11 = return (REG XMM11)
val xmm12 = return (REG XMM12)
val xmm13 = return (REG XMM13)
val xmm14 = return (REG XMM14)
val xmm15 = return (REG XMM15)
val ymm0 = return (REG YMM0)
val ymm1 = return (REG YMM1)
val ymm2 = return (REG YMM2)
val ymm3 = return (REG YMM3)
val ymm4 = return (REG YMM4)
val ymm5 = return (REG YMM5)
val ymm6 = return (REG YMM6)
val ymm7 = return (REG YMM7)
val ymm8 = return (REG YMM8)
val ymm9 = return (REG YMM9)
val ymm10 = return (REG YMM10)
val ymm11 = return (REG YMM11)
val ymm12 = return (REG YMM12)
val ymm13 = return (REG YMM13)
val ymm14 = return (REG YMM14)
val ymm15 = return (REG YMM15)

val imm8 ['b:8'] = return (IMM8 b)
val imm16 ['b1:8' 'b2:8'] = return (IMM16 (b2 ^ b1))
val imm32 ['b1:8' 'b2:8' 'b3:8' 'b4:8'] = return (IMM32 (b4 ^ b3 ^ b2 ^ b1))
val imm64 ['b1:8' 'b2:8' 'b3:8' 'b4:8' 'b5:8' 'b6:8' 'b7:8' 'b8:8'] =
   return (IMM64 (b8 ^ b7 ^ b6 ^ b5 ^ b4 ^ b3 ^ b2 ^ b1))

val rel8 ['b:8'] = return (REL8 b)
val rel16 ['b1:8' 'b2:8'] = return (REL16 (b2 ^ b1))
val rel32 ['b1:8' 'b2:8' 'b3:8' 'b4:8'] = return (REL32 (b4 ^ b3 ^ b2 ^ b1))
val rel64 ['b1:8' 'b2:8' 'b3:8' 'b4:8' 'b5:8' 'b6:8' 'b7:8' 'b8:8'] =
   return (REL64 (b8 ^ b7 ^ b6 ^ b5 ^ b4 ^ b3 ^ b2 ^ b1))

val & giveA giveB = do
   a <- giveA;
   b <- giveB;
   return (a andalso b)
end

val / act = do
   res <- act;
   return (not res)
end

val otherwise = return '1'

val opndsz? = query $opndsz
val addrsz? = query $addrsz
val repne? =  query $repne
val rep? = query $rep
val rexw? = query $rexw
val rex? = query $rex
val mod-mem? = do
   mod <- query $mod;
   case mod of
      '11': return '1'
    | otherwise: return '0'
   end
end
val mod-reg? = / mod-mem?
val mode64? = query $mode64

## Convert a bit-vectors to registers

val reg8 n =
   case n of
      '0000': REG AL
    | '0001': REG CL
    | '0010': REG DL
    | '0011': REG BL
    | '0100': REG AH
    | '0101': REG CH
    | '0110': REG DH
    | '0111': REG BH
    | '1000': REG R8B
    | '1001': REG R9B
    | '1010': REG R10B
    | '1011': REG R11B
    | '1100': REG R12B
    | '1101': REG R13B
    | '1110': REG R14B
    | '1111': REG R15B
   end

val reg8-lower n = reg8 ('0' ^ n)
val reg8-higher n = reg8 ('1' ^ n)
val reg8-rex rex = if rex then reg8-higher else reg8-lower

val reg16 n =
   case n of
      '0000': REG AX
    | '0001': REG CX
    | '0010': REG DX
    | '0011': REG BX
    | '0100': REG SP
    | '0101': REG BP
    | '0110': REG SI
    | '0111': REG DI
    | '1000': REG R8L
    | '1001': REG R9L
    | '1010': REG R10L
    | '1011': REG R11L
    | '1100': REG R12L
    | '1101': REG R13L
    | '1110': REG R14L
    | '1111': REG R15L
   end

val reg16-lower n = reg16 ('0' ^ n)
val reg16-higher n = reg16 ('1' ^ n)
val reg16-rex rex = if rex then reg16-higher else reg16-lower

val reg32 n =
   case n of
      '0000': REG EAX
    | '0001': REG ECX
    | '0010': REG EDX
    | '0011': REG EBX
    | '0100': REG ESP
    | '0101': REG EBP
    | '0110': REG ESI
    | '0111': REG EDI
    | '1000': REG R8D
    | '1001': REG R9D
    | '1010': REG R10D
    | '1011': REG R11D
    | '1100': REG R12D
    | '1101': REG R13D
    | '1110': REG R14D
    | '1111': REG R15D
   end

val reg32-lower n = reg32 ('0' ^ n)
val reg32-higher n = reg32 ('1' ^ n)
val reg32-rex rex = if rex then reg32-higher else reg32-lower

val reg64 n =
   case n of
      '0000': REG RAX
    | '0001': REG RCX
    | '0010': REG RDX
    | '0011': REG RBX
    | '0100': REG RSP
    | '0101': REG RBP
    | '0110': REG RSI
    | '0111': REG RDI
    | '1000': REG R8
    | '1001': REG R9
    | '1010': REG R10
    | '1011': REG R11
    | '1100': REG R12
    | '1101': REG R13
    | '1110': REG R14
    | '1111': REG R15
   end

val reg64-lower n = reg64 ('0' ^ n)
val reg64-higher n = reg64 ('1' ^ n)
val reg64-rex rex = if rex then reg64-higher else reg64-lower

val sreg3 n =
   case n of
      '000': REG ES
    | '001': REG CS
    | '010': REG SS
    | '011': REG DS
    | '100': REG FS
    | '101': REG GS
#| '110': reserved
#| '111': reserved
   end

val sreg3? rex = sreg3

val mm n =
   case n of
      '0000': REG MM0
    | '0001': REG MM1
    | '0010': REG MM2
    | '0011': REG MM3
    | '0100': REG MM4
    | '0101': REG MM5
    | '0110': REG MM6
    | '0111': REG MM7
    | '1000': REG MM8
    | '1001': REG MM9
    | '1010': REG MM10
    | '1011': REG MM11
    | '1100': REG MM12
    | '1101': REG MM13
    | '1110': REG MM14
    | '1111': REG MM15
   end

val mm-lower n = mm ('0' ^ n)
val mm-higher n = mm ('1' ^ n)
val mm-rex rex = if rex then mm-higher else mm-lower

val xmm n =
   case n of
      '0000': REG XMM0
    | '0001': REG XMM1
    | '0010': REG XMM2
    | '0011': REG XMM3
    | '0100': REG XMM4
    | '0101': REG XMM5
    | '0110': REG XMM6
    | '0111': REG XMM7
    | '1000': REG XMM8
    | '1001': REG XMM9
    | '1010': REG XMM10
    | '1011': REG XMM11
    | '1100': REG XMM12
    | '1101': REG XMM13
    | '1110': REG XMM14
    | '1111': REG XMM15
   end

val xmm-lower n = xmm ('0' ^ n)
val xmm-higher n = xmm ('1' ^ n)
val xmm-rex rex = if rex then xmm-higher else xmm-lower

val ymm n =
   case n of
      '0000': REG YMM0
    | '0001': REG YMM1
    | '0010': REG YMM2
    | '0011': REG YMM3
    | '0100': REG YMM4
    | '0101': REG YMM5
    | '0110': REG YMM6
    | '0111': REG YMM7
    | '1000': REG YMM8
    | '1001': REG YMM9
    | '1010': REG YMM10
    | '1011': REG YMM11
    | '1100': REG YMM12
    | '1101': REG YMM13
    | '1110': REG YMM14
    | '1111': REG YMM15
   end

val ymm-lower n = ymm ('0' ^ n)
val ymm-higher n = ymm ('1' ^ n)
val ymm-rex rex = if rex then ymm-higher else ymm-lower

# Deslice the mod/rm byte and put it into the the state

val /0 ['mod:2 000 rm:3'] = update @{mod=mod, rm=rm, reg/opcode='000'}
val /1 ['mod:2 001 rm:3'] = update @{mod=mod, rm=rm, reg/opcode='001'}
val /2 ['mod:2 010 rm:3'] = update @{mod=mod, rm=rm, reg/opcode='010'}
val /3 ['mod:2 011 rm:3'] = update @{mod=mod, rm=rm, reg/opcode='011'}
val /4 ['mod:2 100 rm:3'] = update @{mod=mod, rm=rm, reg/opcode='100'}
val /5 ['mod:2 101 rm:3'] = update @{mod=mod, rm=rm, reg/opcode='101'}
val /6 ['mod:2 110 rm:3'] = update @{mod=mod, rm=rm, reg/opcode='110'}
val /7 ['mod:2 111 rm:3'] = update @{mod=mod, rm=rm, reg/opcode='111'}
val /r ['mod:2 reg/opcode:3 rm:3'] = update @{mod=mod, reg/opcode=reg/opcode, rm=rm}

## Decoding the SIB byte
#    TODO: this is only for 32bit addressing

val sib-without-index reg = do
   mod <- query $mod;
   rexb <- query $rexb;
   case mod of
      '00': imm32
    | '01': return (reg rexb '101') # rBP
    | '10': return (reg rexb '101') # rBP
   end
end

val sib-without-base reg scale index = do
   rexx <- query $rexx;
   scaled <- return (SCALE{imm=scale, opnd=reg rexx index});
   mod <- query $mod;
   rexb <- query $rexb;
   case mod of
      '00': 
         do
            i <- imm32;
            return (SUM{a=scaled, b=i})
         end
    | _ : return (SUM{a=scaled, b=reg rexb '101'}) # rBP
   end
end

val sib-with-index-and-base reg s i b = do
   rexx <- query $rexx;
   rexb <- query $rexb;
   case i of
      '100':
         case b of
            '101': sib-without-index reg
          | _: return (reg rexb b)
         end
    | _:
         case b of
            '101': sib-without-base reg s i
          | _: return (SUM{a=SCALE{imm=s, opnd=reg rexx i}, b=reg rexb b})
         end
   end
end

val sib ['scale:2 index:3 base:3']
 | addrsz? = sib-with-index-and-base reg16-rex scale index base
 | mode64? = sib-with-index-and-base reg64-rex scale index base
 | otherwise = sib-with-index-and-base reg32-rex scale index base

## Decoding the mod/rm byte

val addrsz = do
   sz <- query $addrsz;
   case sz of
      '1': return 16
    | '0': return 32
   end
end

val mem op = do
   sz <- query $ptrty;
   seg <- query $segment;
   return (MEM {sz=sz, segment=seg, opnd=op})
end

val r/m-with-sib reg = do
   sibOpnd <- sib;
   mod <- query $mod;
   case mod of
      '00': mem sibOpnd
    | '01':
         do
            i <- imm8;
            mem (SUM{a=sibOpnd, b=i})
         end
    | '10':
         do
            i <- imm32;
            mem (SUM{a=sibOpnd, b=i})
         end
   end
end

val r/m-without-sib reg addr-reg = do
   mod <- query $mod;
   rm <- query $rm;
   case mod of
      '00':
         case rm of
            '101':
               do
                  i <- imm32;
                  mem i
               end
          | _ : mem (addr-reg rm)
         end
    | '01':
         do
            i <- imm8;
            mem (SUM{a=addr-reg rm, b=i})
         end
    | '10':
         do
            i <- imm32;
            mem (SUM{a=addr-reg rm, b=i})
         end
   end
end

val addrReg = do
   addrsz <- query $addrsz;
   case addrsz of
      '0': return reg64-rex
    | '1': return reg32-rex
   end
end

val r/m ptrTy reg = do
   update@{ptrty=ptrTy};
   mod <- query $mod;
   rm <- query $rm;
   rexb <- query $rexb;
   addr-reg <- addrReg;
   case mod of
      '11': return (reg rexb rm)
    | _:
         case rm of
            '100': r/m-with-sib (reg rexb)
          | _ : r/m-without-sib (reg rexb) (addr-reg rexb)
         end
   end
end

val r/m8 = r/m 8 reg8-rex
val r/m16 = r/m 16 reg16-rex
val r/m32 = r/m 32 reg32-rex
val r/m64 = r/m 64 reg64-rex
val mm/m64 = r/m 64 mm-rex
val xmm/m128 = r/m 128 xmm-rex
val xmm/m64 = r/m 64 xmm-rex
val xmm/m32 = r/m 32 xmm-rex
val ymm/m256 = r/m 256 ymm-rex

val reg/nomem reg = do
   mod <- query $mod;
   case mod of
      '11': r/m 0 reg
   end
end

val xmm/nomem128 = reg/nomem xmm-rex
val mm/nomem64 = reg/nomem mm-rex

val m r/m = do
   mod <- query $mod;
   case mod of
      '00': r/m
    | '01': r/m
    | '10': r/m
   end
#   if (unsigned (not mod)) > 0 then r/m else r/m
end

val m16 = m r/m16
val m32 = m r/m32
val m64 = m r/m64
val m128 = m xmm/m128
val m256 = m ymm/m256

val r/rexb reg = do
   mod <- query $rexb;
   r <- query $reg/opcode;
   return (reg mod r)
end

val r/rexr reg = do
   mod <- query $rexr;
   r <- query $reg/opcode;
   return (reg mod r)
end

val r8 = r/rexr reg8-rex
val r16 = r/rexr reg16-rex
val r32 = r/rexr reg32-rex
val r64 = r/rexr reg64-rex
val r8/rexb = r/rexb reg8-rex
val r16/rexb = r/rexb reg16-rex
val r32/rexb = r/rexb reg32-rex
val r64/rexb = r/rexb reg64-rex
val mm64 = r/rexb mm-rex
val xmm128 = r/rexr xmm-rex
val ymm256 = r/rexr ymm-rex

#TODO: set correct `ptrty` for `moffs*`

val moffs8 = do
   i <- imm8;
   mem i
end

val moffs16 = do
   i <- imm16;
   mem i
end

val moffs32 = do
   i <- imm32;
   mem i
end

val moffs64 = do
   i <- imm64;
   mem i
end

val arity0 cons = return (ARITY0 {tag=cons})

val unop cons giveOp1 = do
  op1 <- giveOp1;
  return (ARITY1 {tag=cons,opnd1=op1})
end

val binop cons giveOp1 giveOp2 = do
   op1 <- giveOp1;
   op2 <- giveOp2;
   return (ARITY2 {tag=cons,opnd1=op1,opnd2=op2})
end

val ternop cons giveOp1 giveOp2 giveOp3 = do
   op1 <- giveOp1;
   op2 <- giveOp2;
   op3 <- giveOp3;
   return (ARITY3 {tag=cons,opnd1=op1,opnd2=op2,opnd3=op3})
end

val near-abs cons giveOp = do
   op <- giveOp;
   return (FLOW1 {tag=cons,opnd1=NEARABS {opnd1=op}})
end

val near-rel cons giveOp = do
   op <- giveOp;
   return (FLOW1 {tag=cons,opnd1=op})
end

val far-abs cons giveOp = do
   op <- giveOp;
   return (FLOW1 {tag=cons,opnd1=FARABS {opnd1=op}})
end

val one = return (IMM8 '00000001')

### CALL 3-112 Vol. 2A
val /66 [0xe8] = near-rel CALL rel16
val main [0xe8] = near-rel CALL rel32
val main [0xff /2] = near-abs CALL r/m64

### LEA 3-579 Vol. 2A
val /66 [0x8d /r]
 | addrsz? = binop LEA r16 r/m16
 | otherwise = binop LEA r16 r/m32
val main [0x8d /r]
 | rexw? & addrsz? = binop LEA r64 r/m32
 | rexw? = binop LEA r64 r/m64
 | addrsz? = binop LEA r32 r/m16
 | otherwise = binop LEA r32 r/m32

### INC 3-501 Vol. 2A
val main [0xfe /0] = unop INC r/m8
val /66 [0xff /0] = unop INC r/m16
val main [0xff /0]
 | rexw? = unop INC r/m64
 | otherwise = unop INC r/m32

### SAL/SAR/SHL/SHR 4-353 Vol. 2B
#### SAL/SHL
val main [0xd0 /4] = binop SHL r/m8 one
val main [0xd2 /4] = binop SHL r/m8 cl
val main [0xc0 /4] = binop SHL r/m8 imm8
val /66 [0xd1 /4] = binop SHL r/m16 one
val /66 [0xd3 /4] = binop SHL r/m16 cl
val /66 [0xc1 /4] = binop SHL r/m16 imm8
val main [0xd1 /4]
 | rexw? = binop SHL r/m64 one
 | otherwise = binop SHL r/m32 one
val main [0xd3 /4]
 | rexw? = binop SHL r/m64 cl
 | otherwise = binop SHL r/m32 cl
val main [0xc1 /4]
 | rexw? = binop SHL r/m64 imm8
 | otherwise = binop SHL r/m32 imm8
#### SAR
val main [0xd0 /7] = binop SAR r/m8 one
val main [0xd2 /7] = binop SAR r/m8 cl
val main [0xc0 /7] = binop SAR r/m8 imm8
val /66 [0xd1 /7] = binop SAR r/m16 one
val /66 [0xd3 /7] = binop SAR r/m16 cl
val /66 [0xc1 /7] = binop SAR r/m16 imm8
val main [0xd1 /7]
 | rexw? = binop SAR r/m64 one
 | otherwise = binop SAR r/m32 one
val main [0xd3 /7]
 | rexw? = binop SAR r/m64 cl
 | otherwise = binop SAR r/m32 cl
val main [0xc1 /7]
 | rexw? = binop SAR r/m64 imm8
 | otherwise = binop SAR r/m32 imm8
#### SHR
val main [0xd0 /5] = binop SHR r/m8 one
val main [0xd2 /5] = binop SHR r/m8 cl
val main [0xc0 /5] = binop SHR r/m8 imm8
val /66 [0xd1 /5] = binop SHR r/m16 one
val /66 [0xd3 /5] = binop SHR r/m16 cl
val /66 [0xc1 /5] = binop SHR r/m16 imm8
val main [0xd1 /5]
 | rexw? = binop SHR r/m64 one
 | otherwise = binop SHR r/m32 one
val main [0xd3 /5]
 | rexw? = binop SHR r/m64 cl
 | otherwise = binop SHR r/m32 cl
val main [0xc1 /5] 
 | rexw? = binop SHR r/m64 imm8
 | otherwise = binop SHR r/m32 imm8

### TEST 4-451 Vol. 2B
val main [0xa8] = binop TEST al imm8
val /66 [0xa9] = binop TEST ax imm16
val main [0xa9]
 | rexw? = binop TEST rax imm32
 | otherwise = binop TEST eax imm32
val main [0xf6 /0] = binop TEST r/m8 imm8
val /66 [0xf7 /0] = binop TEST r/m16 imm16
val main [0xf7 /0]
 | rexw? = binop TEST r/m64 imm32
 | otherwise = binop TEST r/m32 imm32
val main [0x84 /r] = binop TEST r/m8 r8
val /66 [0x85 /r] = binop TEST r/m16 r16
val main [0x85 /r]
 | rexw? = binop TEST r/m64 r64
 | otherwise = binop TEST r/m32 r32

### CMP 3-150 Vol. 2A
val main [0x3c] = binop CMP al imm8
val /66 [0x3d] = binop CMP ax imm16
val main [0x3d]
 | rexw? = binop CMP rax imm32
 | otherwise = binop CMP eax imm32
val main [0x80 /7] = binop CMP r/m8 imm8
val /66 [0x81 /7] = binop CMP r/m16 imm16
val main [0x81 /7]
 | rexw? = binop CMP r/m64 imm32
 | otherwise = binop CMP r/m32 imm32
val /66 [0x83 /7] = binop CMP r/m16 imm8
val main [0x83 /7]
 | rexw? = binop CMP r/m64 imm8
 | otherwise = binop CMP r/m32 imm8
val main [0x38 /r] = binop CMP r/m8 r8
val /66 [0x39 /r] = binop CMP r/m16 r16
val main [0x39 /r]
 | rexw? = binop CMP r/m64 r64
 | otherwise = binop CMP r/m32 r32
val main [0x3A /r] = binop CMP r8 r/m8
val /66 [0x3B /r] = binop CMP r16 r/m16
val main [0x3B /r]
 | rexw? = binop CMP r64 r/m64
 | otherwise = binop CMP r32 r/m32

### NOP 4-12 Vol. 2B
val main [0x90] = arity0 NOP
val /66 [0x90] = arity0 NOP
val /66 [0x0f 0x1f /0] = unop NOP_1 r/m16
val main [0x0f 0x1f /0] = unop NOP_1 r/m32

### RET 4-321 Vol. 2B
val main [0xc3] = arity0 RET
val main [0xcb] = arity0 RETFAR
val main [0xc2] = unop RET_1 imm16
val main [0xca] = unop RETFAR_1 imm16

### IMUL 3-494 Vol. 2A
val main [0xf6 /5] = unop IMUL r/m8
val /66 [0xf7 /5] = unop IMUL r/m16
val main [0xf7 /5]
 | rexw? = unop IMUL r/m64
 | otherwise = unop IMUL r/m32
val /66 [0x0f 0xaf /r] = binop IMUL_2 r16 r/m16
val main [0x0f 0xaf /r]
 | rexw? = binop IMUL_2 r64 r/m64
 | otherwise = binop IMUL_2 r32 r/m32
val /66 [0x6b /r] = ternop IMUL_3 r16 r/m16 imm8
val main [0x6b /r]
 | rexw? = ternop IMUL_3 r64 r/m64 imm8
 | otherwise = ternop IMUL_3 r32 r/m32 imm8
val /66 [0x69 /r] = ternop IMUL_3 r16 r/m16 imm16
val main [0x69 /r]
 | rexw? = ternop IMUL_3 r64 r/m64 imm32
 | otherwise = ternop IMUL_3 r32 r/m32 imm32

### MOVZX 3-739 Vol. 2A
val /66 [0x0f 0xb6 /r] = binop MOVZX r16 r/m8
val main [0x0f 0xb6 /r]
 | rexw? = binop MOVZX r64 r/m8
 | otherwise = binop MOVZX r32 r/m8
val main [0x0f 0xb7 /r]
 | rexw? = binop MOVZX r64 r/m16
 | otherwise = binop MOVZX r32 r/m16

### CMOVcc 3-143 Vol. 2A
val /66 [0x0f 0x47 /r] = binop CMOVA r16 r/m16
val main [0x0f 0x47 /r]
 | rexw? = binop CMOVA r64 r/m64
 | otherwise = binop CMOVA r32 r/m32
val /66 [0x0f 0x43 /r] = binop CMOVAE r16 r/m16
val main [0x0f 0x43 /r]
 | rexw? = binop CMOVAE r64 r/m64
 | otherwise = binop CMOVAE r32 r/m32
val /66 [0x0f 0x42 /r] = binop CMOVB r16 r/m16
val main [0x0f 0x42 /r]
 | rexw? = binop CMOVB r64 r/m64
 | otherwise = binop CMOVB r32 r/m32
val /66 [0x0f 0x46 /r] = binop CMOVBE r16 r/m16
val main [0x0f 0x46 /r]
 | rexw? = binop CMOVBE r64 r/m64
 | otherwise = binop CMOVBE r32 r/m32
val /66 [0x0f 0x44 /r] = binop CMOVE r16 r/m16
val main [0x0f 0x44 /r]
 | rexw? = binop CMOVE r64 r/m64
 | otherwise = binop CMOVE r32 r/m32
val /66 [0x0f 0x4f /r] = binop CMOVG r16 r/m16
val main [0x0f 0x4f /r]
 | rexw? = binop CMOVG r64 r/m64
 | otherwise = binop CMOVG r32 r/m32
val /66 [0x0f 0x4d /r] = binop CMOVGE r16 r/m16
val main [0x0f 0x4d /r]
 | rexw? = binop CMOVGE r64 r/m64
 | otherwise = binop CMOVGE r32 r/m32
val /66 [0x0f 0x4c /r] = binop CMOVL r16 r/m16
val main [0x0f 0x4c /r]
 | rexw? = binop CMOVL r64 r/m64
 | otherwise = binop CMOVL r32 r/m32
val /66 [0x0f 0x4e /r] = binop CMOVLE r16 r/m16
val main [0x0f 0x4e /r]
 | rexw? = binop CMOVLE r64 r/m64
 | otherwise = binop CMOVLE r32 r/m32
val /66 [0x0f 0x45 /r] = binop CMOVNE r16 r/m16
val main [0x0f 0x45 /r]
 | rexw? = binop CMOVNE r64 r/m64
 | otherwise = binop CMOVNE r32 r/m32
val /66 [0x0f 0x41 /r] = binop CMOVNO r16 r/m16
val main [0x0f 0x41 /r]
 | rexw? = binop CMOVNO r64 r/m64
 | otherwise = binop CMOVNO r32 r/m32
val /66 [0x0f 0x4b /r] = binop CMOVNP r16 r/m16
val main [0x0f 0x4b /r]
 | rexw? = binop CMOVNP r64 r/m64
 | otherwise = binop CMOVNP r32 r/m32
val /66 [0x0f 0x49 /r] = binop CMOVNS r16 r/m16
val main [0x0f 0x49 /r]
 | rexw? = binop CMOVNS r64 r/m64
 | otherwise = binop CMOVNS r32 r/m32
val /66 [0x0f 0x40 /r] = binop CMOVO r16 r/m16
val main [0x0f 0x40 /r]
 | rexw? = binop CMOVO r64 r/m64
 | otherwise = binop CMOVO r32 r/m32
val /66 [0x0f 0x4a /r] = binop CMOVP r16 r/m16
val main [0x0f 0x4a /r]
 | rexw? = binop CMOVP r64 r/m64
 | otherwise = binop CMOVP r32 r/m32
val /66 [0x0f 0x48 /r] = binop CMOVS r16 r/m16
val main [0x0f 0x48 /r]
 | rexw? = binop CMOVS r64 r/m64
 | otherwise = binop CMOVS r32 r/m32

### Jcc 3-544 Vol. 2A
val main [0x77] = near-rel JA rel8  # JNBE
val main [0x73] = near-rel JAE rel8 # JNB, JNC
val main [0x72] = near-rel JC rel8  # JB,JNAE
val main [0x76] = near-rel JBE rel8 # JNA
val /66 [0xe3] = near-rel JCXZ rel8
val main[0xe3]
 | rexw? = near-rel JRCXZ rel8
 | otherwise = near-rel JECXZ rel8 
val main [0x74] = near-rel JE rel8  # JZ
val main [0x7f] = near-rel JG rel8  # JNLE
val main [0x7d] = near-rel JGE rel8 # JNL
val main [0x7c] = near-rel JL rel8  # JNGE
val main [0x7e] = near-rel JLE rel8 # JNG
val main [0x75] = near-rel JNE rel8 # JNZ
val main [0x71] = near-rel JNO rel8
val main [0x7b] = near-rel JNP rel8 # JPO
val main [0x79] = near-rel JNS rel8
val main [0x70] = near-rel JO rel8
val main [0x7a] = near-rel JP rel8  # JPE
val main [0x78] = near-rel JS rel8
val /66 [0x0f 0x87]
 | mode64? = near-rel JA rel32
 | otherwise = near-rel JA rel16
val main [0x0f 0x87] = near-rel JA rel32
val /66 [0x0f 0x83]
 | mode64? = near-rel JAE rel32
 | otherwise = near-rel JAE rel16
val main [0x0f 0x83] = near-rel JAE rel32
val /66 [0x0f 0x82]
 | mode64? = near-rel JB rel32
 | otherwise = near-rel JB rel16
val main [0x0f 0x82] = near-rel JB rel32
val /66 [0x0f 0x86]
 | mode64? = near-rel JBE rel32
 | otherwise = near-rel JBE rel16
val main [0x0f 0x86] = near-rel JBE rel32
val /66 [0x0f 0x84]
 | mode64? = near-rel JE rel32
 | otherwise = near-rel JE rel16
val main [0x0f 0x84] = near-rel JE rel32
val /66 [0x0f 0x8f]
 | mode64? = near-rel JG rel32
 | otherwise = near-rel JG rel16
val main [0x0f 0x8f] = near-rel JG rel32
val /66 [0x0f 0x8d]
 | mode64? = near-rel JGE rel32
 | otherwise = near-rel JGE rel16
val main [0x0f 0x8d] = near-rel JGE rel32
val /66 [0x0f 0x8c]
 | mode64? = near-rel JL rel32
 | otherwise = near-rel JL rel16
val main [0x0f 0x8c] = near-rel JL rel32
val /66 [0x0f 0x8e]
 | mode64? = near-rel JLE rel32
 | otherwise = near-rel JLE rel16
val main [0x0f 0x8e] = near-rel JLE rel32
val /66 [0x0f 0x85]
 | mode64? = near-rel JNE rel32
 | otherwise = near-rel JNE rel16
val main [0x0f 0x85] = near-rel JNE rel32
val /66 [0x0f 0x81]
 | mode64? = near-rel JNO rel32
 | otherwise = near-rel JNO rel16
val main [0x0f 0x81] = near-rel JNO rel32
val /66 [0x0f 0x8b]
 | mode64? = near-rel JNP rel32
 | otherwise = near-rel JNP rel16
val main [0x0f 0x8b] = near-rel JNP rel32
val /66 [0x0f 0x89]
 | mode64? = near-rel JNS rel32
 | otherwise = near-rel JNS rel16
val main [0x0f 0x89] = near-rel JNS rel32
val /66 [0x0f 0x80]
 | mode64? = near-rel JO rel32
 | otherwise = near-rel JO rel16
val main [0x0f 0x80] = near-rel JO rel32
val /66 [0x0f 0x8a]
 | mode64? = near-rel JP rel32
 | otherwise = near-rel JP rel16
val main [0x0f 0x8a] = near-rel JP rel32
val /66 [0x0f 0x88]
 | mode64? = near-rel JS rel32
 | otherwise = near-rel JS rel16
val main [0x0f 0x88] = near-rel JS rel32

### JMP 3-552 Vol. 2A
#TODO: jmp far
val main [0xeb] = near-rel JMP rel8
val /66 [0xe9]
 | mode64? = near-rel JMP rel32
 | otherwise = near-rel JMP rel16
val main [0xe9] = near-rel JMP rel32
val /66 [0xff /4]
 | mode64? = near-abs JMP r/m64
 | otherwise = near-abs JMP r/m16
val main [0xff /4]
 | mode64? = near-abs JMP r/m64
 | otherwise = near-abs JMP r/m32

### SETcc 4-372 Vol. 2B
val main [0x0f 0x97] = unop SETA r/m8
val main [0x0f 0x93] = unop SETAE r/m8
val main [0x0f 0x92] = unop SETB r/m8
val main [0x0f 0x96] = unop SETBE r/m8
val main [0x0f 0x94] = unop SETE r/m8
val main [0x0f 0x9f] = unop SETG r/m8
val main [0x0f 0x9d] = unop SETGE r/m8
val main [0x0f 0x9c] = unop SETL r/m8
val main [0x0f 0x9e] = unop SETLE r/m8
val main [0x0f 0x95] = unop SETNE r/m8
val main [0x0f 0x91] = unop SETNO r/m8
val main [0x0f 0x9b] = unop SETNP r/m8
val main [0x0f 0x99] = unop SETNS r/m8
val main [0x0f 0x90] = unop SETO r/m8
val main [0x0f 0x9a] = unop SETP r/m8
val main [0x0f 0x98] = unop SETS r/m8

### SUB 4-572 Vol. 2B
val main [0x2c] = binop SUB al imm8
val /66 [0x2d] = binop SUB ax imm16
val main [0x2d]
 | rexw? = binop SUB rax imm32
 | otherwise = binop SUB eax imm32
val main [0x80 /5] = binop SUB r/m8 imm8
val /66 [0x81 /5] = binop SUB r/m16 imm16
val main [0x81 /5]
 | rexw? = binop SUB r/m64 imm32
 | otherwise = binop SUB r/m32 imm32
val /66 [0x83 /5] = binop SUB r/m16 imm8
val main [0x83 /5]
 | rexw? = binop SUB r/m64 imm8
 | otherwise = binop SUB r/m32 imm8
val main [0x28 /r] = binop SUB r/m8 r8
val /66 [0x29 /r] = binop SUB r/m16 r16
val main [0x29 /r]
 | rexw? = binop SUB r/m64 r64
 | otherwise = binop SUB r/m32 r32
val main [0x2a /r] = binop SUB r8 r/m8
val /66 [0x2b /r] = binop SUB r16 r/m16
val main [0x2b /r]
 | rexw? = binop SUB r64 r/m64
 | otherwise = binop SUB r32 r/m32

### OR 4-16 Vol. 2B
val main [0x0c] = binop OR al imm8
val /66 [0x0d] = binop OR ax imm16
val main [0x0d]
 | rexw? = binop OR rax imm32
 | otherwise = binop OR eax imm32
val main [0x80 /1] = binop OR r/m8 imm8
val /66 [0x81 /1] = binop OR r/m16 imm16
val main [0x81 /1]
 | rexw? = binop OR r/m64 imm32
 | otherwise = binop OR r/m32 imm32
val /66 [0x83 /1] = binop OR r/m16 imm8
val main [0x83 /1]
 | rexw? = binop OR r/m64 imm8
 | otherwise = binop OR r/m32 imm8
val main [0x08 /r] = binop OR r/m8 r8
val /66 [0x09 /r] = binop OR r/m16 r16
val main [0x09 /r]
 | rexw? = binop OR r/m64 r64
 | otherwise = binop OR r/m32 r32
val main [0x0a /r] = binop OR r8 r/m8
val /66 [0x0b /r] = binop OR r16 r/m16
val main [0x0b /r]
 | rexw? = binop OR r64 r/m64
 | otherwise = binop OR r32 r/m32

### XOR 4-678 Vol. 2B
val main [0x34] = binop XOR al imm8
val /66 [0x35] = binop XOR ax imm16
val main [0x35]
 | rexw? = binop XOR rax imm32
 | otherwise = binop XOR eax imm32
val main [0x80 /6] = binop XOR r/m8 imm8
val /66 [0x81 /6] = binop XOR r/m16 imm16
val main [0x81 /6]
 | rexw? = binop XOR r/m64 imm32
 | otherwise = binop XOR r/m32 imm32
val /66 [0x83 /6] = binop XOR r/m16 imm8
val main [0x83 /6]
 | rexw? = binop XOR r/m64 imm8
 | otherwise = binop XOR r/m32 imm8
val main [0x30 /r] = binop XOR r/m8 r8
val /66 [0x31 /r] = binop XOR r/m16 r16
val main [0x31 /r]
 | rexw? = binop XOR r/m64 r64
 | otherwise = binop XOR r/m32 r32
val main [0x32 /r] = binop XOR r8 r/m8
val /66 [0x33 /r] = binop XOR r16 r/m16
val main [0x33 /r]
 | rexw? = binop XOR r64 r/m64
 | otherwise = binop XOR r32 r/m32

### PUSH 4-275 Vol. 2B
#TODO: correctly implement 32bit and 64bit modes
val /66 [0xff /6] = unop PUSH r/m16
val main [0xff /6] = unop PUSH r/m64
val /66 ['01010 r:3'] = do update@{reg/opcode=r}; unop PUSH r16/rexb end
val main ['01010 r:3'] = do update@{reg/opcode=r}; unop PUSH r64/rexb end
val main [0x6a] = unop PUSH imm8
val /66 [0x68] = unop PUSH imm16
val main [0x68] = unop PUSH imm32
val main [0x0e] = unop PUSH cs
val main [0x16] = unop PUSH ds
val main [0x06] = unop PUSH es
val main [0x0f 0xa0] = unop PUSH fs
val main [0x0f 0xa8] = unop PUSH gs

### POP 4-188 Vol. 2B
#TODO: correctly implement 32bit and 64bit modes
val /66 [0x8f /0] = unop POP r/m16
val main [0x8f /0] = unop POP r/m64
val /66 ['01011 r:3'] = do update@{reg/opcode=r}; unop POP r16/rexb end
val main ['01011 r:3'] = do update@{reg/opcode=r}; unop POP r64/rexb end
val main [0x1f] = unop POP ds
val main [0x07] = unop POP es
val main [0x17] = unop POP ss

### ADD Vol. 2A 3-35
val main [0x04] = binop ADD al imm8
val /66 [0x05] = binop ADD ax imm16
val main [0x05]
 | rexw? = binop ADD rax imm32
 | otherwise = binop ADD eax imm32
val main [0x80 /0] = binop ADD r/m8 imm8
val /66 [0x81 /0] = binop ADD r/m16 imm16
val main [0x81 /0]
 | rexw? = binop ADD r/m64 imm32 
 | otherwise = binop ADD r/m32 imm32
val /66 [0x83 /0] = binop ADD r/m16 imm8
val main [0x83 /0]
 | rexw? = binop ADD r/m64 imm8
 | otherwise = binop ADD r/m32 imm8
val main [0x00 /r] = binop ADD r/m8 r8
val /66 [0x01 /r] = binop ADD r/m16 r16
val main [0x01 /r]
 | rexw? = binop ADD r/m64 r64
 | otherwise = binop ADD r/m32 r32
val main [0x02 /r] = binop ADD r8 r/m8
val /66 [0x03 /r] = binop ADD r16 r/m16
val main [0x03 /r]
 | rexw? = binop ADD r64 r/m64
 | otherwise = binop ADD r32 r/m32

### CVTPD2PI Vol 2A 3-248
val cvtpdf2pi = binop CVTPD2PI
val /66 [0x0f 0x2d /r] = cvtpdf2pi mm64 xmm/m128

### MASKMOVDQU Vol. 2B 4-9
val maskmovdqu = binop MASKMOVDQU
val vmaskmovdqu = binop VMASKMOVDQU
val /66 [0x0f 0xf7 /r] = maskmovdqu xmm128 xmm/nomem128

### MASKMOVQ Vol. 2B 4-11
val maskmovq = binop MASKMOVQ
val main [0x0f 0xf7 /r] = maskmovq mm64 mm/nomem64

### MAXPD Vol. 2B 4-13
val maxpd = binop MAXPD
val vmaxpd = ternop VMAXPD
val /66 [0x0f 0x5f /r] = maxpd xmm128 xmm/m128

### MAXPS 4-16 Vol. 2B
val maxps = binop MAXPS
val vmaxps = ternop VMAXPS
val main [0x0f 0x5f /r] = maxps xmm128 xmm/m128

### MAXSD Vol. 2B 4-19
val maxsd = binop MAXSD
val vmaxsd = ternop VMAXSD
val pf2 [0x0f 0x5f /r] = maxsd xmm128 xmm/m64

### MAXSS Vol. 2B 4-21
val maxss = binop MAXSS
val vmaxss = ternop VMAXSS
val pf3 [0x0f 0x5f /r] = maxss xmm128 xmm/m32

### MFENCE Vol. 2B 4-23
val mfence = return MFENCE
val main [0x0f 0xae /6] = mfence

### MINPD Vol. 2B 4-25
val minpd = binop MINPD
val vminpd = ternop VMINPD
val /66 [0x0f 0x5d /r] = minpd xmm128 xmm/m128

### MINPS Vol. 2B 4-28
val minps = binop MINPS
val vminps = ternop VMINPS
val main [0x0f 0x5d /r] = minps xmm128 xmm/m128

### MINSD Vol. 2B 4-31
val minsd = binop MINSD
val vminsd = ternop VMINSD
val pf2 [0x0f 0x5d /r] = minsd xmm128 xmm/m64

### MINSS Vol. 2B 4-33
val minss = binop MINSS
val vminss = ternop VMINSS
val pf3 [0x0f 0x5d /r] = minss xmm128 xmm/m32

### MONITOR Vol. 2B 4-35
val monitor = return MONITOR
val main [0x0f 0xae 0x01 0xc8] = monitor

### MOV Vol 2A 3-643
val main [0x88 /r] = binop MOV r/m8 r8
val /66 [0x89 /r] = binop MOV r/m16 r16
val main [0x89 /r]
 | rexw? = binop MOV r/m64 r64
 | otherwise = binop MOV r/m32 r32
val main [0x8a /r] = binop MOV r8 r/m8
val /66 [0x8b /r] = binop MOV r16 r/m16
val main [0x8b /r]
 | rexw? = binop MOV r64 r/m32
 | otherwise = binop MOV r32 r/m32
val main [0x8c /r] = binop MOV r/m16 (r/rexb sreg3?)
val main [0x8e /r] = binop MOV (r/rexb sreg3?) r/m16
val main [0xa0] = binop MOV al moffs8 
val main [0xa1]
 | addrsz? = binop MOV ax moffs16
 | otherwise = binop MOV eax moffs32
val main [0xa2] = binop MOV moffs8 al
val main [0xa3]
 | addrsz? = binop MOV moffs16 ax
 | otherwise = binop MOV moffs32 eax
val main ['10110 r:3'] = do update@{reg/opcode=r}; binop MOV r8/rexb imm8 end
val /66 ['10111 r:3'] = do update@{reg/opcode=r}; binop MOV r16/rexb imm16 end
val main ['10111 r:3']
 | rexw? = do update@{reg/opcode=r}; binop MOV r64/rexb imm64 end
 | otherwise = do update@{reg/opcode=r}; binop MOV r32/rexb imm32 end
val main [0xc6 /0] = binop MOV r/m8 imm8
val /66 [0xc7 /0] = binop MOV r/m16 imm16
val main [0xc7 /0]
 | rexw? = binop MOV r/m64 imm32
 | otherwise = binop MOV r/m32 imm32

### MOVAPD Vol. 2B 4-52
val movapd = binop MOVAPD
val vmovapd = binop VMOVAPD
val /66 [0x0f 0x28 /r] = movapd xmm128 xmm/m128
val /66 [0x0f 0x29 /r] = movapd xmm/m128 xmm128

### MOVAPS Vol. 2B 4-55
val movaps = binop MOVAPS
val vmovaps = binop VMOVAPS
val main [0x0f 0x28 /r] = movaps xmm128 xmm/m128
val main [0x0f 0x29 /r] = movaps xmm/m128 xmm128

### MOVBE Vol. 2B 4-58
val movbe = binop MOVBE
val /66 [0x0f 0x38 0xf0 /r] = movbe r16 m16
val main [0x0f 0x38 0xf0 /r]
 | rexw? = movbe r64 m64
 | otherwise = movbe r32 m32
val /66 [0x0f 0x38 0xf1 /r] = movbe m16 r16
val main [0x0f 0x38 0xf1 /r]
 | rexw? = movbe m64 r64
 | otherwise = movbe m32 r32

### MOVD/MOVQ Vol. 2B 4-61
val movd = binop MOVD
val vmovd = binop VMOVD
val movq = binop MOVQ
val vmovq = binop VMOVQ
val main [0x0f 0x6e /r]
 | rexw? = movq mm64 r/m64
 | otherwise = movd mm64 r/m32
val main [0x0f 0x7e /r]
 | rexw? = movq r/m64 mm64
 | otherwise = movd r/m32 mm64
val /66 [0x0f 0x6e /r]
 | rexw? = movq xmm128 r/m64
 | otherwise = movd xmm128 r/m32
val /66 [0x0f 0x7e /r]
 | rexw? = movq r/m64 xmm128
 | otherwise = movd r/m32 xmm128

### MOVDDUP Vol. 2B 4-64
val movddup = binop MOVDDUP
val vmovddup = binop VMOVDDUP
val pf2 [0x0f 0x12 /r] = movddup xmm128 xmm/m64

### MOVDQA Vol. 2B 4-67
val movdqa = binop MOVDQA
val vmovdqa = binop VMOVDQA
val /66 [0x0f 0x6f /r] = movdqa xmm128 xmm/m128
val /66 [0x0f 0x7f /r] = movdqa xmm/m128 xmm128

### MOVDQU Vol. 2B 4-70
val movdqu = binop MOVDQU
val vmovdqu = binop VMOVDQU
val pf3 [0x0f 0x6f /r] = movdqu xmm128 xmm/m128
val pf3 [0x0f 0x7f /r] = movdqu xmm/m128 xmm128

### MOVDQ2Q Vol. 2B 4-73
val movdq2q = binop MOVDQ2Q
val pf2 [0x0f 0xd6 /r] = movdq2q mm64 xmm128

### MOVHLPS Vol. 2B 4-75
## CHECK collision with movlps
#val movhlps = binop MOVHLPS
#val vmovhlps = ternop VMOVHLPS
#val main [0x0f 0x12 /r] = movhlps xmm128 xmm/nomem128

### MOVHPD Vol. 2B 4-77
val movhpd = binop MOVHPD
val vmovhpd = ternop VMOVHPD
val vbmovhpd = binop VBMOVHPD
val /66 [0x0f 0x16 /r] = movhpd xmm128 m64
val /66 [0x0f 0x17 /r] = movhpd m64 xmm128

### MOVHPS Vol. 2B 4-79
val movhps = binop MOVHPS
val vmovhps = ternop VMOVHPS
val vbmovhps = binop VBMOVHPS
val main [0x0f 0x16 /r]
 | mod-mem? = movhps xmm128 m64
val main [0x0f 0x17 /r]
 | mod-mem? = movhps m64 xmm128

### MOVLHPS Vol. 2B 4-81
## CHECK collision with movhps
#val movlhps = binop MOVLHPS
#val vmovlhps = ternop VMOVLHPS
#val main [0x0f 0x16 /r]
# | mod-reg? = movlhps xmm128 xmm/nomem128

### MOVLPD Vol. 2B 4-83
val movlpd = binop MOVLPD
val vmovlpd = ternop VMOVLPD
val vbmovlpd = binop VBMOVLPD
val /66 [0x0f 0x12 /r] = movlpd xmm128 m64
val /66 [0x0f 0x13 /r] = movlpd m64 xmm128

### MOVLPS Vol. 2B 4-85
val movlps = binop MOVLPD
val vmovlps = ternop VMOVLPD
val vbmovlps = binop VBMOVLPD
val main [0x0f 0x12 /r] = movlps xmm128 m64
val main [0x0f 0x13 /r] = movlps m64 xmm128

### MOVMSKPD Vol. 2B 4-87
val movmskpd = binop MOVMSKPD
val vmovmskpd = binop VMOVMSKPD
val /66 [0x0f 0x50 /r]
 | mode64? = movmskpd r64 xmm128
 | otherwise = movmskpd r32 xmm128
(*#########################
##### ~~ VERIFY! ~~ #####
#########################*)

### MOVMSKPS Vol. 2B 4-89
val movmskps = binop MOVMSKPS
val vmovmskps = binop VMOVMSKPS
val main [0x0f 0x50 /r]
 | mode64? = movmskpd r64 xmm128
 | otherwise = movmskpd r32 xmm128
(*#########################
##### ~~ VERIFY! ~~ #####
#########################*)

### MOVNTDQA Vol. 2B 4-92
val movntdqa = binop MOVNTDQA
val vmovntdqa = binop VMOVNTDQA
val /66 [0x0f 0x38 0x2a /r] = movntdqa xmm128 m128

### MOVNTDQ Vol. 2B 4-95
val movntdq = binop MOVNTDQ
val vmovntdq = binop VMOVNTDQ
val /66 [0x0f 0xe7 /r] = movntdq m128 xmm128

### MOVNTI Vol. 2B 4-97
val movnti = binop MOVNTI
val main [0x0f 0xc3 /r]
 | rexw? = movnti m64 r64
 | otherwise = movnti m32 r32

### MOVNTPD Vol. 2B 4-99
val movntpd = binop MOVNTPD
val vmovntpd = binop VMOVNTPD
val /66 [0x0f 0x2b /r] = movntpd m128 xmm128

### MOVNTPS Vol. 2B 4-99
val movntps = binop MOVNTPD
val vmovntps = binop VMOVNTPD
val main [0x0f 0x2b /r] = movntps m128 xmm128

### MOVNTQ Vol. 2B 4-103
val movntq = binop MOVNTQ
val main [0x0f 0xe7 /r] = movntq m64 mm64

### MOVQ Vol. 2B 4-105
val main [0x0f 0x6f /r] = movq mm64 mm/m64
val main [0x0f 0x7f /r] = movq mm/m64 mm64
val pf3 [0x0f 0x7e /r] = movq xmm128 xmm/m64
val /66 [0x0f 0xd6 /r] = movq xmm/m64 xmm128

### PHADDW/PHADDD Vol. 2B 4-253
val phaddw = binop PHADDW
val vphaddw = ternop VPHADDW
val phaddd = binop PHADDD
val vphaddd = ternop VPHADDD
val /66 [0x0f 0x38 01 /r] = phaddw xmm128 xmm/m128
val main [0x0f 0x38 01 /r] = phaddw mm64 mm/m64
val /66 [0x0f 0x38 02 /r] = phaddd xmm128 xmm/m128
val main [0x0f 0x38 02 /r] = phaddd mm64 mm/m64

### XADD Vol. 2B 4-667
val xadd = binop XADD
val main [0x0f 0xc0 /r] = xadd r/m8 r8
val /66 [0x0f 0xc1 /r] = binop MOV r/m16 r16
val main [0x0f 0xc1 /r]
 | rexw? = xadd r/m64 r64
 | otherwise = binop MOV r/m32 r32

