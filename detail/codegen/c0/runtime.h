/* vim:cindent:ts=2:sw=2:expandtab */

#ifndef __RUNTIME_H
#define __RUNTIME_H

#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <stdarg.h>
#include <stddef.h>
#include <string.h>

#define __RT_HEAP_SIZE (4*1024)

#define __CHECK_HEAP(n) /* TODO: check for heap-overflow */
#define __ALLOC1() --hp /* TODO: check for heap-overflow */
#define __ALLOC0() hp /* TODO: check for heap-overfl(4*1024) */
#define __ALLOCN(n) hp-=n /* TODO: check for heap-overflow */

#define __INVOKE1(o, closure)\
  ((__obj(*)(__obj))((o)->label.f))(closure)

#define __INVOKE2(o, closure, x)\
  ((__obj(*)(__obj,__obj))((o)->label.f))(closure, x)

#define __INVOKE3(o, closure, x, y)\
  ((__obj(*)(__obj,__obj,__obj))((o)->label.f))(closure, x, y)

#define __INVOKE4(o, closure, x, y, z)\
  ((__obj(*)(__obj,__obj,__obj,__obj))((o)->label.f))(closure, x, y, z)

#define __INVOKE5(o, closure, w, x, y, z)\
  ((__obj(*)(__obj,__obj,__obj,__obj,__obj))((o)->label.f))(closure, w, x, y, z)

#define __INVOKE6(o, closure, v, w, x, y, z)\
  ((__obj(*)(__obj,__obj,__obj,__obj,__obj,__obj))((o)->label.f))(closure, v, w, x, y, z)

#define __INVOKE7(o, closure, u, v, w, x, y, z)\
  ((__obj(*)(__obj,__obj,__obj,__obj,__obj,__obj,__obj))((o)->label.f))(closure, u, v, w, x, y, z)

#define __FCALL(f,...) f(__VA_ARGS__)

/** ## Integers */

#define __INT_BEGIN(Cname)\
  __CHECK_HEAP(1)

#define __INT_INIT(val)\
  {__objref o = __ALLOC1();\
   o->z.header.tag = __INT;\
   o->z.value = val
   
#define __INT_END(Cname)\
   Cname = __WRAP(o);}

/** ## Labels */

#define __LABEL_BEGIN(Cname)\
  __CHECK_HEAP(1)

#define __LABEL_INIT(val)\
  {__objref o = __ALLOC1();\
   o->label.header.tag = __LABEL;\
   o->label.f = (__obj (*)(void)) val
   
#define __LABEL_END(Cname)\
   Cname = __WRAP(o);}

/** ## Closures */

#define __CLOSURE_BEGIN(Cname, n)\
   __CHECK_HEAP(n+1)

#define __CLOSURE_ADD(value)\
   {__objref o = __ALLOC1();\
    *o = *(__UNWRAP(value));}

#define __CLOSURE_END(Cname, n)\
   {__objref o = __ALLOC1();\
    o->closure.header.tag = __CLOSURE;\
    o->closure.sz = n;\
    o->closure.env = o+1;\
    Cname = __WRAP(o);}

#define __CLOSURE_REF(Cname, n) (__WRAP(&(Cname->closure.env[n])))

/** ## Records */

/* PERF: A more efficient data-structure for records is needed.
 * maybe versioned arrays or some kind of list/stack with the
 * most recently added fields on-top. */
#define __RECORD_BEGIN(Cname, n)\
  __CHECK_HEAP(n+1)

#define __RECORD_ADD(field, value)\
  {__objref o = __ALLOC1();\
   o->tagged.header.tag = __TAGGED;\
   o->tagged.tag = field;\
   o->tagged.payload = value;}

#define __RECORD_END(Cname, n)\
  {__objref o = __ALLOC1();\
   o->record.header.tag = __RECORD;\
   o->record.sz = n;\
   o->record.fields = o+1;\
   Cname = __WRAP(o);}

#define __RECORD_BEGIN_UPDATE(Cdst, Csrc)\
  {__recordCloneFields((struct __record*)Csrc);\
   __word n = Csrc->record.sz

#define __RECORD_UPDATE(tag, value)\
   n += __recordUpdate(__ALLOC0(),n,tag,value)

#define __RECORD_END_UPDATE(Cdst)\
  {__objref o = __ALLOC1();\
   o->record.header.tag = __RECORD;\
   o->record.sz = n;\
   o->record.fields = o+1;\
   Cdst = __WRAP(o);}}

#define __RECORD_SELECT(Cname, field)\
  __recordLookup(((struct __record*)Cname), field)->tagged.payload

/** ## Ropes/Strings */

#define __ROPE_BEGIN(Cname) /* TODO: CHECK HEAP */

#define __ROPE_CONCAT(a,b)\
  {__objref o = __ALLOC1();\
   o->ropebranch.header.tag = __ROPEBRANCH;\
   o->ropebranch.left = a;\
   o->ropebranch.right = b;

#define __ROPE_FROMCSTRING(s)\
  {__objref o = __ALLOC1();\
   __int len = strlen(s);\
   __int n = len/sizeof(__unwrapped_obj);\
   n = ((len % sizeof(__unwrapped_obj)) == 0) ? n : n + 1;\
   o->ropeleaf.header.tag = __ROPELEAF;\
   o->ropeleaf.sz = len;\
   __objref p = __ALLOCN(n);\
   memcpy(p,s,len);\
   o->ropeleaf.blob = (__char*)p;

#define __ROPE_END(Cname)\
   Cname = __WRAP(o);}

/** ## Bitvectors */

#define __BV_BEGIN(Cname, n)\
  __CHECK_HEAP(1)

#define __BV_INIT(value)\
  {__objref o = __ALLOC1();\
   o->bv.header.tag = __BV;\
   o->bv.vec = value;\

#define __BV_END(Cname, n)\
   o->bv.sz = n;\
   Cname = __WRAP(o);}

/** ## Tagged values (datatypes) */

#define __TAGGED_BEGIN(Cname)\
  __CHECK_HEAP(1)

#define __TAGGED_INIT(con, value)\
  {__objref o = __ALLOC1();\
   o->tagged.header.tag = __TAGGED;\
   o->tagged.tag = con;\
   o->tagged.payload = value;

#define __TAGGED_END(Cname)\
   Cname = __WRAP(o);}

#define __TAGGED_BEGIN(Cname)\
  __CHECK_HEAP(1)

/** ## Blobs */

#define __BLOB_BEGIN(Cname)\
  __CHECK_HEAP(1)

#define __BLOB_INIT(buf, size)\
  {__objref o = __ALLOC1();\
   o->blob.header.tag = __BLOB;\
   o->blob.blob = buf;\
   o->blob.sz = size;

#define __BLOB_END(Cname)\
   Cname = __WRAP(o);}

#define __LOCAL0(Cname) __obj Cname
#define __LOCAL(Cname, body) __obj Cname = body

typedef union __header __header;
typedef union __unwrapped_obj __unwrapped_obj;
typedef union __wrapped_obj __wrapped_obj;
typedef __unwrapped_obj* __objref;
typedef __wrapped_obj* __obj;
typedef uint64_t __word;
typedef int64_t __int;
typedef uint8_t __char;

enum __tag {
  __CLOSURE,
  __BV,
  __INT,
  __TAGGED,
  __RECORD,
  __NIL,
  __BLOB,
  __ROPELEAF,
  __ROPEBRANCH,
  __LABEL
};

union __header {
  enum __tag tag;
  __obj ignored;
} __attribute__((aligned(8)));

union __unwrapped_obj {
  struct __unwrapped_immediate {
    __header header;
  } object;
  struct __unwrapped_tagged {
    __header header;
    __word tag;
    __obj payload;
  } tagged;
  struct __unwrapped_closure {
    __header header;
    __word sz;
    __objref env;
  } closure;
  struct __unwrapped_record {
    __header header;
    __word sz;
    __objref fields;
  } record;
  struct __unwrapped_bv {
    __header header;
    __word sz;
    __word vec;
  } bv;
  struct __unwrapped_label {
    __header header;
    __obj (*f)(void);
  } label;
  struct __unwrapped_blob {
    __header header;
    __char* blob;
    __word sz;
  } blob;
  struct __unwrapped_ropeleaf {
    __header header;
    __char* blob;
    __word sz;
  } ropeleaf;
  struct __unwrapped_ropebranch {
    __header header;
    __obj left;
    __obj right;
  } ropebranch;
  struct __unwrapped_int {
    __header header;
    __int value;
  } z;
} __attribute__((aligned(8)));

union __wrapped_obj {
  struct __tagged {
    __word tag;
    __obj payload;
  } tagged;
  struct __closure {
    __word sz;
    __objref env;
  } closure;
  struct __record {
    __word sz;
    __objref fields;
  } record;
  struct __bv {
    __word sz;
    __word vec;
  } bv;
  struct __label {
    __obj (*f)(void);
  } label;
  struct __blob {
    __char* blob;
    __word sz;
  } blob;
  struct __ropeleaf {
    __char* blob;
    __word sz;
  } ropeleaf;
  struct __ropebranch {
    __obj left;
    __obj right;
  } ropebranch;
  struct __int {
    __int value;
  } z;
} __attribute__((aligned(8)));

#define __WRAP(x) ((__obj)(((__header*)x)+1))
#define __UNWRAP(x) ((__objref)(((__header*)x)-1))
#define __TAG(x) ((__UNWRAP((__obj)x))->object.header.tag)

#ifndef RELAXEDFATAL
#define __FATAL(type) __fatal("%s:%d:%s",__FILE__,__LINE__,#type)
#else
#define __FATAL(type)\
  {printf("%s:%d:%s\n",__FILE__,__LINE__,#type);\
   return (__UNIT);}
#endif

void __fatal(char*,...) __attribute__((noreturn));
__unwrapped_obj heap[__RT_HEAP_SIZE] __attribute__((aligned(8)));
__objref hp;
__obj __UNIT;
__obj __TRUE;
__obj __FALSE;

/* ## Constructor tags */

#define __RESERVED 0
@constructors@

/* ## Record field selectors */

#define ___blob 0
@fields@

/* ## Exported functions */

@exports@

/* ## Primitive runtime functions */

const __char* __tagName (__word i);
const __char* __fieldName (__word i);

__obj __halt (__obj,__obj);
__obj __print (__obj);
__obj __println (__obj);
__obj __traceln (const char*,__obj);

static inline __objref __recordLookup (struct __record* record, __word field) {
  __word i, sz = record->sz;
  __objref fields = record->fields;
  for (i = 0; i < sz; i++) {
    __objref o = &fields[i];
    if (o->tagged.tag == field)
       return (o);
  }
  if (field < __NFIELDS)
    __fatal("record-field '%s' not found",__fieldName(field));
  else
    __fatal("record-field '%zu' not found",field);
}

static inline __word __recordUpdate (__objref fields, __word n, __word field, __obj value) {
  __word i;
  for (i = 0; i < n; i++) {
    __objref o = &fields[i];
    if (o->tagged.tag == field) {
       /* Overwriting already exisiting field */
       o->tagged.payload = value;
       return (0);
    }
  }
  /* Allocating new record field */
  __objref o = __ALLOC1();
  o->tagged.header.tag = __TAGGED;
  o->tagged.tag = field;
  o->tagged.payload = value;
  return (1);
}

static inline void __recordCloneFields (struct __record* record) {
  __word sz = record->sz;
  __objref fields = __ALLOCN(sz);
  memcpy(fields, record->fields, sz*sizeof(__unwrapped_obj));
}

/* #define __DECON(o) (o)->tagged.payload */
/* PERF */
static inline __obj __DECON (__obj o) {
  switch (__TAG(o)) {
    case __TAGGED: return (o->tagged.payload);
    default: return o;
  }
}

static inline __word __CASETAG (__obj o) {
  switch (__TAG(o)) {
    case __INT:
      return ((__word)o->z.value);
    case __TAGGED:
      return (o->tagged.tag);
    case __BV:
      return (o->bv.vec);
    default:
      __fatal("__CASETAG() applied to non-tagged object");
  }
}

static inline __word __CASETAGCON (__obj o) { return o->tagged.tag; }

static inline __word __CASETAGVEC (__obj o) { return o->bv.vec; }

static inline __word __CASETAGINT (__obj o) { return o->z.value; }

static inline int __isTrue (__obj o) {
   return (o == __TRUE); /* TODO: or isBitVec(o)&&value='1' */
}

static inline int __isFalse (__obj o) {
   return (o == __FALSE); /* TODO: or isBitVec(o)&&value='0' */
}

static inline void __resetHeap() {
  hp = &heap[__RT_HEAP_SIZE];
}

__obj __consume8(__obj);
__obj __unconsume8(__obj);
__obj __consume16(__obj);
__obj __unconsume16(__obj);
__obj __consume32(__obj);
__obj __unconsume32(__obj);
__obj __slice(__obj,__obj,__obj);
__obj __concat(__obj,__obj);
__obj __equal(__obj,__obj);
__obj __and(__obj,__obj);
__obj __sx(__obj);
__obj __zx(__obj);
__obj __raise(__obj);
__obj __not(__obj);
__obj __isNil(__obj);
__obj __printState();
__obj __concatstring(__obj,__obj);
__obj __showbitvec(__obj);
__obj __showint(__obj);
__obj __flattenstring(__obj,char*,__word);

/** ## Operations on integers */

__obj __eqi(__obj,__obj);
__obj __lti(__obj,__obj);
__obj __lei(__obj,__obj);
__obj __addi(__obj,__obj);
__obj __subi(__obj,__obj);
__obj __muli(__obj,__obj);

/* ## API helpers */

int ___isNil(__obj);
__obj __runWithState(__obj(*)(__obj,__obj),__obj);
__obj __evalPure(__obj(*)(__obj,__obj),__obj);
__obj __eval(__obj(*)(__obj,__obj),__char*,__word);
__word __decode(__obj(*)(__obj,__obj),__char*,__word,__obj*);
__obj __pretty(__obj(*)(__obj,__obj),__obj,char*,__word);
__obj __translate(__obj(*)(__obj,__obj),__obj);

#endif /* __RUNTIME_H */

