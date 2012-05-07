
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
  return o;
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

__obj __slice (__obj tok_, __obj offs_, __obj sz_, __obj s) {
  __word tok = tok_->bv.vec;
  __int offs = offs_->z.value;
  __int sz = sz_->z.value;
  __word x = ((tok >> offs) & ((1 << sz)-1));
  __LOCAL0(slice);
    __BV_BEGIN(slice,sz);
    __BV_INIT(x);
    __BV_END(slice,sz);
  __LOCAL0(r);
    __RECORD_BEGIN(r,2);
    __RECORD_ADD(___1,slice);
    __RECORD_ADD(___2,s);
    __RECORD_END(r,2);
  return (r);
}

__obj __halt (__obj env, __obj o) {
   printf("halt\n");
   __println(o);
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

@functions@

static void __testConcat () {
  __obj x = __concat(__TRUE, __FALSE);
  __println(x);
}

static __obj __test000__ (__obj env, __obj k, __obj s) {
  __LOCAL(kk, __CLOSURE_REF(k,0));
  __println(s);
  return __INVOKE2(kk,k,s);
}

static __obj __test001__ (__obj env, __obj k, __obj s) {
  __LOCAL(kk, __CLOSURE_REF(k,0));
  printf("STATE0:");
  __println(s);
  s = __consume(s);
  printf("STATE1:");
  __println(s);
  return __INVOKE2(kk,k,s);
}

static void printState () {
  printf("heap: %p, hp: %p, size: %u, obj-size: %zu\n",
    &heap[0], hp, __RT_HEAP_SIZE, sizeof(__unwrapped_obj));
}

int main (int argc, char** argv) {
  printState();
  printf("argc: %d\n", argc);
  
  __char blob[15] = {0x48, 0x83, 0xc4, 0x08};
  __word sz = 15;

  __testConcat();

  __obj o;
  o = eval(__test000__,blob,sz);
  printState();
  o = eval(__test001__,blob,sz);

  printf("DECODE starting\n");
  printState();
  o = eval(__decode__,blob,sz);
  __println(o);
  printState();
  printf("DECODE finished\n");

  return (1); 
}
