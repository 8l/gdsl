
#include "dis.h"

__unwrapped_obj heap[__RT_HEAP_SIZE] __attribute__((aligned(8)));
__objref hp = &heap[__RT_HEAP_SIZE];

@fieldnames@

@tagnames@

@prototypes@

struct __unwrapped_immediate __unwrapped_UNIT =
   {.header.tag = __NIL};
struct __unwrapped_bv __unwrapped_TRUE =
   {.header.tag = __BV,
    .sz = 1,
    .vec = 1};
struct __unwrapped_bv __unwrapped_FALSE =
   {.header.tag = __BV,
    .sz = 1,
    .vec = 0};

__obj __UNIT = __WRAP(&__unwrapped_UNIT);
__obj __TRUE = __WRAP(&__unwrapped_TRUE);
__obj __FALSE = __WRAP(&__unwrapped_FALSE);

void __fatal (char *fmt, ...) {
  va_list ap;
  va_start(ap, fmt);
  fprintf(stderr,"ERROR:");
  vfprintf(stderr, fmt, ap);
  fprintf(stderr, "\n");
  va_end(ap);
  abort();
}

__obj __and (__obj a_, __obj b_) {
  __word a = a_->bv.vec;
  __word b = b_->bv.vec;
  __word sz = a_->bv.sz;
  __LOCAL0(x);
    __BV_BEGIN(x,sz);
    __BV_INIT(a & b);
    __BV_END(x,sz);
  return (x);
}

__obj __concat (__obj a_, __obj b_) {
  __word a = a_->bv.vec;
  __word b = b_->bv.vec;
  __word szOfA = a_->bv.sz;
  __word szOfB = b_->bv.sz;
  __word sz = szOfA + szOfB;
  __LOCAL0(x);
    __BV_BEGIN(x,sz);
    __BV_INIT((a << szOfB) | b);
    __BV_END(x,sz);
  return (x);
}

__obj __equal (__obj a_, __obj b_) {
  __word a = a_->bv.vec;
  __word b = b_->bv.vec;
  __LOCAL(x, a == b ? __TRUE : __FALSE); 
  return (x);
}

__obj __not (__obj a_) {
  __word a = a_->bv.vec;
  __word sz = a_->bv.sz;
  __LOCAL0(x);
    __BV_BEGIN(x,sz);
    __BV_INIT(~a & ((1 << sz)-1));
    __BV_END(x,sz);
  return (x);
}

__obj __raise (__obj o) {
  printf("raising: ");
  __println(o);
  __fatal("<error>");
  return (o);
}

__obj __unconsume (__obj s) {
  __LOCAL(blob, __RECORD_SELECT(s,___blob));
  __char* buf = blob->blob.blob;
  __word sz = blob->blob.sz;
  __LOCAL0(blobb);
    __BLOB_BEGIN(blobb);
    __BLOB_INIT(buf-1,sz+1);
    __BLOB_END(blobb);
  __LOCAL0(ss);
    __RECORD_BEGIN_UPDATE(ss,s);
    __RECORD_UPDATE(___blob,blobb);
    __RECORD_END_UPDATE(ss);
  __LOCAL0(a);
    __RECORD_BEGIN(a,2);
    __RECORD_ADD(___1,__UNIT);
    __RECORD_ADD(___2,ss);
    __RECORD_END(a,2);
  return (a);
}

__obj __consume (__obj s) {
  __LOCAL(blob, __RECORD_SELECT(s,___blob));
  __char* buf = blob->blob.blob;
  __word sz = blob->blob.sz;
  if (sz == 0)
    __fatal("<end-of-blob>");
  __char x = *buf;
  __LOCAL0(v);
    __BV_BEGIN(v,8);
    __BV_INIT(x);
    __BV_END(v,8);
  __LOCAL0(blobb);
    __BLOB_BEGIN(blobb);
    __BLOB_INIT(buf+1,sz-1);
    __BLOB_END(blobb);
  __LOCAL0(ss);
    __RECORD_BEGIN_UPDATE(ss,s);
    __RECORD_UPDATE(___blob,blobb);
    __RECORD_END_UPDATE(ss);
  __LOCAL0(a);
    __RECORD_BEGIN(a,2);
    __RECORD_ADD(___1,v);
    __RECORD_ADD(___2,ss);
    __RECORD_END(a,2);
  return (a);
}

__obj __slice (__obj tok_, __obj offs_, __obj sz_) {
  __word tok = tok_->bv.vec;
  __int offs = offs_->z.value;
  __int sz = sz_->z.value;
  __word x = ((tok >> offs) & ((1 << sz)-1));
  __LOCAL0(slice);
    __BV_BEGIN(slice,sz);
    __BV_INIT(x);
    __BV_END(slice,sz);
  return (slice);
}

__obj __halt (__obj env, __obj o) {
  return (o);
}

__obj __runWithState (__obj (*f)(__obj,__obj,__obj), __obj s) {
  __LOCAL0(k);
    __LABEL_BEGIN(k);
    __LABEL_INIT(__halt);
    __LABEL_END(k);
  __LOCAL0(envK);
    __CLOSURE_BEGIN(envK,1)
    __CLOSURE_ADD(k);
    __CLOSURE_END(envK,1);
  __LOCAL0(m);
    __LABEL_BEGIN(m);
    __LABEL_INIT(f);
    __LABEL_END(m);
  __LOCAL0(envM);
    __CLOSURE_BEGIN(envM,1)
    __CLOSURE_ADD(m);
    __CLOSURE_END(envM,1);
  return (__INVOKE3(m,envM,envK,s));
}

__obj eval (__obj (*f)(__obj,__obj,__obj), __char* blob, __word sz) {
  __LOCAL0(b);
    __BLOB_BEGIN(b);
    __BLOB_INIT(blob, sz);
    __BLOB_END(b);
  __LOCAL0(s);
    __RECORD_BEGIN(r,1);
    __RECORD_ADD(___blob,b);
    __RECORD_END(s,1);
  return (__runWithState(f,s));
}

const __char* __fieldName (__word i) {
  static __char* unknown = (__char*)"<unknown>";
  if (i < __NFIELDS)
     return ((const __char*)__fieldNames[i]);
  return (unknown);
}

const __char* __tagName (__word i) {
  static __char* unknown = (__char*)"<unknown>";
  if (i < __NTAGS)
     return ((const __char*)__tagNames[i]);
  return (unknown);
}

__obj __print (__obj o) {
  switch (__TAG(o)) {
    case __CLOSURE:
      printf("{tag=__CLOSURE,sz=%zu,env=..}",o->closure.sz);
      break;
    case __INT:
      printf("{tag=__INT,value=%ld}", o->z.value);
      break;
    case __TAGGED: {
      __word tag = o->tagged.tag;
      if (tag < __NTAGS)
        printf("{tag=%s,",__tagName(tag));
      else
        printf("{tag=<unknown:%lu>,",tag);
      printf("payload=");
      __print(o->tagged.payload);
      printf("}");
      break;
    }
    case __RECORD: {
      printf("{tag=__RECORD,sz=%lu,", o->record.sz);
      int i;
      for (i=0;i<o->record.sz;i++) {
        __objref tagged = &o->record.fields[i];
        __word tag = tagged->tagged.tag;
        __obj payload = tagged->tagged.payload;
        if (tag < __NFIELDS)
          printf("%s=",__fieldName(tag));
        else
          printf("<unknown:%lu>=",tag);
        __print(payload);
        if (i < o->record.sz-1)
          printf(",");
      }
      printf("}");
      break;
    }
    case __LABEL:
      printf("{tag=__LABEL,f=%p}",o->label.f);
      break;
    case __BLOB:
      printf("{tag=__BLOB,sz=%lu,blob=%p}",o->blob.sz, o->blob.blob);
      break;
    case __BV:
      printf("{tag=__BV,sz=%lu,vec=%zx}", o->bv.sz, o->bv.vec);
      break;
    case __NIL:
      printf("{tag=__NIL}");
      break;
    default:
      printf("{tag=<unknown>,..}");
   }
   return (__UNIT);
}

__obj __println (__obj o) {
  __print(o);
  printf("\n");
  return (__UNIT);
}

__obj __traceln (const char* s, __obj o) {
  printf("TRACE:%s:",s);
  return (__println(o));
}

__obj __isNil (__obj o) {
  switch (__TAG(o)) {
    case __NIL: return (__TRUE);
    default: return (__FALSE);
  }
}

int ___isNil (__obj o) {
  switch (__TAG(o)) {
    case __NIL: return (1);
    default: return (0);
  }
}

__obj prettyOpnds(__obj);

__obj prettyMem (__obj mem) {
  __int sz = __RECORD_SELECT(mem,___sz)->z.value;
  __obj segment = __RECORD_SELECT(mem,___segment);
  __obj opnd = __RECORD_SELECT(mem,___opnd);
  switch (sz) {
    case 8:
      printf("BYTE PTR ");
      break;
    case 16:
      printf("WORD PTR ");
      break;
    case 32:
      printf("DWORD PTR ");
      break;
    case 64:
      printf("QWORD PTR ");
      break;
    case 128:
      printf("DQWORD PTR ");
      break;
    default:
      printf("PTR(%ld) ", sz);
      break;
  }
  prettyOpnds(segment);
  printf(":[");
  prettyOpnds(opnd);
  printf("]");
  return (__UNIT);
}

__obj prettySum (__obj sum) {
  __obj a = __RECORD_SELECT(sum,___a);
  __obj b = __RECORD_SELECT(sum,___b);
  prettyOpnds(a);
  printf("+");
  return (prettyOpnds(b));
}

__obj prettyFac (__obj imm) {
  switch (__CASETAG(imm)) {
    case 0: break;
    case 1: printf("2*");break;
    case 2: printf("4*");break;
    case 3: printf("8*");break;
    default: __fatal("invalid scaling factor");
  }
  return (__UNIT);
}

__obj prettyScale (__obj scale) {
  __obj imm = __RECORD_SELECT(scale,___imm);
  __obj op = __RECORD_SELECT(scale,___opnd);
  prettyFac(imm);
  return (prettyOpnds(op));
}

__obj prettyOpnds (__obj opnds) {
  switch (__TAG(opnds)) {
    case __TAGGED: {
      __word tag = opnds->tagged.tag;
      __obj payload = opnds->tagged.payload;
      switch (tag) {
        case __MEM:
          return (prettyMem(payload));
        case __REG:
          return (prettyOpnds(payload));
        case __SUM:
          return (prettySum(payload));
        case __SCALE:
          return (prettyScale(payload));
        case __NEARABS:
          printf("NEAR ");
          return (prettyOpnds(payload));
        case __FARABS:
          printf("FAR ");
          return (prettyOpnds(payload));
        case __REL8:
        case __REL16:
        case __REL32:
        case __REL64:
          printf("RELATIVE ");
          return (prettyOpnds(payload));
        case __IMM8:
        case __IMM16:
        case __IMM32:
        case __IMM64:
          return (prettyOpnds(payload));
        default:
          printf("%s", __tagName(tag));
          if (!___isNil(payload)) {
            printf(",");
            return (prettyOpnds(payload));
          }
          return (__UNIT);
      }
    }
    case __RECORD: {
      switch (opnds->record.sz) {
        case 1: {
          __obj op1 = __RECORD_SELECT(opnds,___opnd1);
          return (prettyOpnds(op1));
        }
        case 2: {
          __obj op1 = __RECORD_SELECT(opnds,___opnd1);
          return (prettyOpnds(op1));
        }
        case 3: {
          __obj op1 = __RECORD_SELECT(opnds,___opnd1);
          __obj op2 = __RECORD_SELECT(opnds,___opnd2);
          prettyOpnds(op1);
          printf(",");
          return (prettyOpnds(op2));
        }
        case 4: {
          __obj op1 = __RECORD_SELECT(opnds,___opnd1);
          __obj op2 = __RECORD_SELECT(opnds,___opnd2);
          __obj op3 = __RECORD_SELECT(opnds,___opnd3);
          prettyOpnds(op1);
          printf(",");
          prettyOpnds(op2);
          printf(",");
          return (prettyOpnds(op3));
        }
        case 5: {
          __obj op1 = __RECORD_SELECT(opnds,___opnd1);
          __obj op2 = __RECORD_SELECT(opnds,___opnd2);
          __obj op3 = __RECORD_SELECT(opnds,___opnd3);
          __obj op4 = __RECORD_SELECT(opnds,___opnd4);
          prettyOpnds(op1);
          printf(",");
          prettyOpnds(op2);
          printf(",");
          prettyOpnds(op3);
          printf(",");
          return (prettyOpnds(op4));
        }
        default:
          __fatal("unsupported amount of operands");
      }
    }
    case __BV:
      printf("0x%zx",opnds->bv.vec);
      return (__UNIT);
    case __INT:
      printf("%ld",opnds->z.value);
      return (__UNIT);
    default:
       __fatal("invalid operand");
  }
}

__obj pretty (__obj insn) {
  switch (__TAG(insn)) {
    case __TAGGED: {
      __obj payload = insn->tagged.payload;
      __word tag = __CASETAG(__RECORD_SELECT(payload,___tag));
      switch (__CASETAG(insn)) {
         case __ARITY0:
            printf("%s",__tagName(tag));
            return (__UNIT);
         default:
            printf("%s ",__tagName(tag));
            return (prettyOpnds(payload));
      }
    }
    default:
      __fatal("invalid instruction object");
  }
}

__obj prettyln (__obj insn) {
  pretty(insn);
  printf("\n");
  return (__UNIT);
}

__obj __printState () {
  ptrdiff_t d = &heap[__RT_HEAP_SIZE] - hp;
  int n = d / sizeof(__unwrapped_obj);
  int used = n*100/__RT_HEAP_SIZE;
  printf("heap: %p, hp: %p, size: %u, used: %d (%d%%), obj-size: %zu\n",
    &heap[0], hp, __RT_HEAP_SIZE, n, used, sizeof(__unwrapped_obj));
  return (__UNIT);
}

__obj decode (__char* blob, __word sz) {
  __obj o = eval(__decode__,blob,sz);
  if (___isNil(o)) {printf("\n");return (__UNIT);}
  __obj insn = __RECORD_SELECT(o,___1);
  prettyln(insn);
  __resetHeap();
  return (__UNIT);
}

#ifdef WITHMAIN

int main (int argc, char** argv) {
  __char blob001[15] = {0x67,0xF3,0x45,0x0F,0x7E,0xD1};
  __char blob002[15] = {0xF3,0x67,0x45,0x0F,0x7E,0xD1};
  __char blob003[15] = {0x67,0x45,0xF3,0x0F,0x7E,0xD1};
  __char blob004[15] = {0xF3,0x45,0x67,0x0F,0x7E,0xD1};
  //__char blob005[15] = {67C4E1F97EC8};
  //__char blob006[15] = {C4E1F9677EC8};
  __char blob007[15] = {0x67,0x45,0xF3,0x0F,0x7E,0x11};
  //__char blob008[15] = {C4E1F97EC8};
  __word sz = 15;

  decode(blob001, sz);
  decode(blob002, sz);
  decode(blob003, sz);
  decode(blob004, sz);
  decode(blob007, sz);

  return (1); 
}

#endif

@functions@

/* vim:cindent
 * vim:ts=2
 * vim:sw=2
 * vim:expandtab */
