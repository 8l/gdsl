granularity = 16
# export = decode
# 
# val decode = do
#  update@{rd='',rr='',ck='',cs='',cb='',io=''};
#  /
# end

type side-effect =
   NONE
 | INCR
 | DECR

type imm =
   IMM3 of 3
 | IMM4 of 4
 | IMM6 of 6
 | IMM7 of 7
 | IMM8 of 8
 | IMM22 of 22

type operand =
   REG of register
 | REGHL of {regh:register,regl:register}
 | IOREG of io-register
 | IMM of imm
 | OPSE of {op:operand,se:side-effect}

type binop = {first:operand,second:operand}
type unop = {operand:operand}

type instruction =
   ADC of binop
 | ADD of binop
 | ADIW of binop
 | AND of binop
 | ANDI of binop
 | ASR of unop
 | BCLR of unop
 | BLD of binop
 | BRBC of binop
 | BRBS of binop
 | BREAK
 | BSET of unop
 | BST of binop
 | CALL of unop
 | CBI of binop
 | CLC
 | CLH
 | CLI
 | CLN
 | CLS
 | CLT
 | CLV
 | CLZ
 | COM of unop
 | CP of binop
 | CPC of binop
 | CPI of binop
 | CPSE of binop
 | DEC of unop
 | DES of unop
 | EICALL
 | EIJMP
 | ELPM of binop
 | EOR of binop
 | FMUL of binop
 | FMULS of binop
 | FMULSU of binop
 | ICALL
 | IJMP
 | IN of binop

type register =
   R0
 | R1
 | R2
 | R3
 | R4
 | R5
 | R6
 | R7
 | R8
 | R9
 | R10
 | R11
 | R12
 | R13
 | R14
 | R15
 | R16
 | R17
 | R18
 | R19
 | R20
 | R21
 | R22
 | R23
 | R24
 | R25
 | R26
 | R27
 | R28
 | R29
 | R30
 | R31

type io-register =
   IO0
 | IO1
 | IO2
 | IO3
 | IO4
 | IO5
 | IO6
 | IO7
 | IO8
 | IO9
 | IO10
 | IO11
 | IO12
 | IO13
 | IO14
 | IO15
 | IO16
 | IO17
 | IO18
 | IO19
 | IO20
 | IO21
 | IO22
 | IO23
 | IO24
 | IO25
 | IO26
 | IO27
 | IO28
 | IO29
 | IO30
 | IO31
 | IO32
 | IO33
 | IO34
 | IO35
 | IO36
 | IO37
 | IO38
 | IO39
 | IO40
 | IO41
 | IO42
 | IO43
 | IO44
 | IO45
 | IO46
 | IO47
 | IO48
 | IO49
 | IO50
 | IO51
 | IO52
 | IO53
 | IO54
 | IO55
 | IO56
 | IO57
 | IO58
 | IO59
 | IO60
 | IO61
 | IO62
 | IO63


val register-from-bits bits =
 case bits of
    '00000': R0
  | '00001': R1
  | '00010': R2
  | '00011': R3
  | '00100': R4
  | '00101': R5
  | '00110': R6
  | '00111': R7
  | '01000': R8
  | '01001': R9
  | '01010': R10
  | '01011': R11
  | '01100': R12
  | '01101': R13
  | '01110': R14
  | '01111': R15
  | '10000': R16
  | '10001': R17
  | '10010': R18
  | '10011': R19
  | '10100': R20
  | '10101': R21
  | '10110': R22
  | '10111': R23
  | '11000': R24
  | '11001': R25
  | '11010': R26
  | '11011': R27
  | '11100': R28
  | '11101': R29
  | '11110': R30
  | '11111': R31
 end

val io-register-from-bits bits =
 case bits of
    '000000': IO0
  | '000001': IO1
  | '000010': IO2
  | '000011': IO3
  | '000100': IO4
  | '000101': IO5
  | '000110': IO6
  | '000111': IO7
  | '001000': IO8
  | '001001': IO9
  | '001010': IO10
  | '001011': IO11
  | '001100': IO12
  | '001101': IO13
  | '001110': IO14
  | '001111': IO15
  | '010000': IO16
  | '010001': IO17
  | '010010': IO18
  | '010011': IO19
  | '010100': IO20
  | '010101': IO21
  | '010110': IO22
  | '010111': IO23
  | '011000': IO24
  | '011001': IO25
  | '011010': IO26
  | '011011': IO27
  | '011100': IO28
  | '011101': IO29
  | '011110': IO30
  | '011111': IO31
  | '100000': IO32
  | '100001': IO33
  | '100010': IO34
  | '100011': IO35
  | '100100': IO36
  | '100101': IO37
  | '100110': IO38
  | '100111': IO39
  | '101000': IO40
  | '101001': IO41
  | '101010': IO42
  | '101011': IO43
  | '101100': IO44
  | '101101': IO45
  | '101110': IO46
  | '101111': IO47
  | '110000': IO48
  | '110001': IO49
  | '110010': IO50
  | '110011': IO51
  | '110100': IO52
  | '110101': IO53
  | '110110': IO54
  | '110111': IO55
  | '111000': IO56
  | '111001': IO57
  | '111010': IO58
  | '111011': IO59
  | '111100': IO60
  | '111101': IO61
  | '111110': IO62
  | '111111': IO63
 end

val x-hl = REGHL {regh=R27,regl=R26}
val y-hl = REGHL {regh=R29,regl=R28}
val z-hl = REGHL {regh=R31,regl=R30}

val r0 = return (REG R0)

val /Z se = return (OPSE {op=z-hl,se=se})

val d ['bit:1'] = do
 rd <- query $rd;
 update@{rd=rd ^ bit}
end

val r ['bit:1'] = do
 rr <- query $rr;
 update@{rr=rr ^ bit}
end

val k ['bit:1'] = do
 ck <- query $ck;
 update@{ck=ck ^ bit}
end

val s ['bit:1'] = do
 cs <- query $cs;
 update@{cs=cs ^ bit}
end

val a ['bit:1'] = do
 io <- query $io;
 update@{io=io ^ bit}
end

val b ['bit:1'] = do
 cb <- query $cb;
 update@{cb=cb ^ bit}
end

val rd5 = do
 rd <- query $rd;
 update @{rd=''};
 return (REG (register-from-bits rd))
end

val rd4 = do
 rd <- query $rd;
 update @{rd=''};
 return (REG (register-from-bits ('1' ^ rd)))
end

val rd3 = do
 rd <- query $rd;
 update @{rd=''};
 return (REG (register-from-bits ('10' ^ rd)))
end
 
val rr5 = do
 rr <- query $rr;
 update @{rr=''};
 return (REG (register-from-bits rr))
end
 
val rr4 = do
 rr <- query $rr;
 update @{rr=''};
 return (REG (register-from-bits ('1' ^ rr)))
end
 
val rr3 = do
 rr <- query $rr;
 update @{rr=''};
 return (REG (register-from-bits ('10' ^ rr)))
end

val ck4 = do
 ck <- query $ck;
 update @{ck=''};
 return (IMM (IMM4 ck))
end

val ck6 = do
 ck <- query $ck;
 update @{ck=''};
 return (IMM (IMM6 ck))
end

val ck7 = do
 ck <- query $ck;
 update @{ck=''};
 return (IMM (IMM7 ck))
end

val ck8 = do
 ck <- query $ck;
 update @{ck=''};
 return (IMM (IMM8 ck))
end

val ck22 = do
 ck <- query $ck;
 update @{ck=''};
 return (IMM (IMM22 ck))
end

val cs3 = do
 cs <- query $cs;
 update @{cs=''};
 return (IMM (IMM3 cs))
end

val cb3 = do
 cb <- query $cb;
 update @{cb=''};
 return (IMM (IMM3 cb))
end

val io5 = do
 io <- query $io;
 update @{io=''};
 return (IOREG (io-register-from-bits ('0' ^ io)))
end

val io6 = do
 io <- query $io;
 update @{io=''};
 return (IOREG (io-register-from-bits io))
end

val rd5h-rd5l = do
 rd <- query $rd;
 rd-regl <- return (register-from-bits ('11' ^ rd ^ '0'));
 rd-regh <- return (register-from-bits ('11' ^ rd ^ '1'));
 update @{rd=''};
 return (REGHL {regh=rd-regh,regl=rd-regl})
end

val binop cons first second = do
 first <- first;
 second <- second;
 return (cons {first=first, second=second})
end

val unop cons operand = do
 operand <- operand;
 return (cons {operand=operand})
end

val nullop cons = do
 return cons
end

### ADC
###  - Add with Carry
val / ['000111 r d d d d d r r r r '] = binop ADC rd5 rr5

### ADD
###  - Add without Carry
val / ['000011 r d d d d d r r r r '] = binop ADD rd5 rr5

### ADIW
###  - Add Immediate to Word
val / ['10010110 k k d d k k k k '] = binop ADIW rd5h-rd5l ck6

### AND
###  - Logical AND
val / ['001000 r d d d d d r r r r '] = binop AND rd5 rr5

### ANDI
###  - Logical AND with Immediate
val / ['0111 k k k k d d d d k k k k '] = binop ANDI rd4 ck8

### ASR
###  - Arithmetic Shift Right
val / ['1001010 d d d d d 0101'] = unop ASR rd5

### BCLR
###  - Bit Clear in SREG
val / ['100101001 s s s 1000'] = unop BCLR cs3

### BLD
###  - Bit Load from the T Flag in SREG to a Bit in Register
val / ['1111100 d d d d d 0 b b b '] = binop BLD rd5 cb3

### BRBC
###  - Branch if Bit in SREG is Cleared
val / ['111101 k k k k k k k s s s '] = binop BRBC cs3 ck7

### BRBS
###  - Branch if Bit in SREG is Set
val / ['111100 k k k k k k k s s s '] = binop BRBS cs3 ck7

### BREAK
###  - Break
val / ['1001010110011000'] = nullop BREAK

### BSET
###  - Bit Set in SREG
val / ['100101000 s s s 1000'] = unop BSET cs3

### BST
###  - Bit Store from Bit in Register to T Flag in SREG
val / ['1111101 d d d d d 0 b b b '] = binop BST rd5 cb3

### CALL
###  - Long Call to a Subroutine
val / ['1001010 k k k k k 111 k ' 'k k k k k k k k k k k k k k k k '] = unop CALL ck22

### CBI
###  - Clear Bit in I/O Register
val / ['10011000 a a a a a b b b '] = binop CBI io5 cb3

### CLC
###  - Clear Carry Flag
val / ['1001010010001000'] = nullop CLC

### CLH
###  - Clear Half Carry Flag
val / ['1001010011011000'] = nullop CLH

### CLI
###  - Clear Global Interrupt Flag
val / ['1001010011111000'] = nullop CLI

### CLN
###  - Clear Negative Flag
val / ['1001010010101000'] = nullop CLN

### CLS
###  - Clear Signed Flag
val / ['1001010011001000'] = nullop CLS

### CLT
###  - Clear T Flag
val / ['1001010011101000'] = nullop CLT

### CLV
###  - Clear Overflow Flag
val / ['1001010010111000'] = nullop CLV

### CLZ
###  - Clear Zero Flag
val / ['1001010010011000'] = nullop CLZ

### COM
###  - One’s Complement
val / ['1001010 d d d d d 0000'] = unop COM rd5

### CP
###  - Compare
val / ['000101 r d d d d d r r r r '] = binop CP rd5 rr5

### CPC
###  - Compare with Carry
val / ['000001 r d d d d d r r r r '] = binop CPC rd5 rr5

### CPI
###  - Compare with Immediate
val / ['0011 k k k k d d d d k k k k '] = binop CPI rd4 ck8

### CPSE
###  - Compare Skip if Equal
val / ['000100 r d d d d d r r r r '] = binop CPSE rd5 rr5

### DEC
###  - Decrement
val / ['1001010 d d d d d 1010'] = unop DEC rd5

### DES
###  - Data Encryption Standard
val / ['10010100 k k k k 1011'] = unop DES ck4

### EICALL
###  - Extended Indirect Call to Subroutine
val / ['1001010100011001'] = nullop EICALL

### EIJMP
###  - Extended Indirect Jump
val / ['1001010000011001'] = nullop EIJMP

### ELPM
###  - Extended Load Program Memory
val / ['1001010111011000'] = binop ELPM r0 (/Z NONE)
val / ['1001000 d d d d d 0110'] = binop ELPM rd5 (/Z NONE)
val / ['1001000 d d d d d 0111'] = binop ELPM rd5 (/Z INCR)

### EOR
###  - Exclusive OR
val / ['001001 r d d d d d r r r r '] = binop EOR rd5 rr5

### FMUL
###  - Fractional Multiply Unsigned
val / ['000000110 d d d 1 r r r '] = binop FMUL rd3 rr3

### FMULS
###  - Fractional Multiply Signed
val / ['000000111 d d d 0 r r r '] = binop FMULS rd3 rr3

### FMULSU
###  - Fractional Multiply Signed with Unsigned
val / ['000000111 d d d 1 r r r '] = binop FMULSU rd3 rr3

### ICALL
###  - Indirect Call to Subroutine
val / ['1001010100001001'] = nullop ICALL

### IJMP
###  - Indirect Jump
val / ['1001010000001001'] = nullop IJMP

### IN
###  - Load an I/O Location to Register
val / ['10110 a a d d d d d a a a a '] = binop IN rd5 io6
