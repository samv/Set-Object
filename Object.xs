#ifdef __cplusplus
extern "C" {
#endif
#define PERL_POLLUTE
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#ifdef __cplusplus
}
#endif

typedef struct _ISET
{
   struct xpvav iset_xpvav;
   I32 iset_fill, iset_max, iset_elems;
} ISET;

#define ISET_HASH(el) ((I32) (el) >> 4)

void iset_insert_one(AV* array, SV* el)
{
   ISET* s;
   SV *rv, **ppb;
   I32 hash, index;

   if (!SvROK(el))
      croak("element must be a reference");

   s = (ISET*) array->sv_any;
   rv = SvRV(el);

   if (s->iset_max == -1)
   {
      av_extend(array, 8);
      s->iset_max = 7;
   }

   hash = ISET_HASH(rv);
   index = hash & s->iset_max;
   ppb = av_fetch(array, index, 0);

   if (!ppb)
   {
      AV* pb = newAV();
      av_push(pb, newRV_inc(rv));
      av_store(array, index, newRV_noinc((SV*) pb));
      ++s->iset_fill;
      ++s->iset_elems;
   }
   else
   {
      AV* pb = (AV*) SvRV(*ppb);
      int nj = av_len(pb);
      int j;

      for (j = 0; j <= nj; ++j)
      {
         SV** pel = av_fetch(pb, j, 0);

         if (pel && SvRV(*pel) == rv)
            return;
      }

      av_push(pb, newRV_inc(rv));
      ++s->iset_elems;
   }

   if (s->iset_elems == s->iset_max)
   {
      int newmax = 2 * (s->iset_max + 1) - 1;
      SV** bucket_first;
      SV** bucket_iter;
      SV** bucket_last;
      SV** new_bucket;
      int i;

      av_extend(array, newmax + 1);

      bucket_first = AvARRAY(array);
      bucket_iter = bucket_first;
      bucket_last = bucket_iter + av_len(array) + 1;

      for (i = 0; bucket_iter != bucket_last; ++bucket_iter, ++i)
      {
         AV* bucket;
         SV **el_iter, **el_last, **el_out_iter;
         I32 newfill;

         if (*bucket_iter == &sv_undef)
            continue;

         bucket = (AV*) SvRV(*bucket_iter);

         el_iter = AvARRAY(bucket);
         el_last = el_iter + av_len(bucket) + 1;
         el_out_iter = el_iter;

         for (; el_iter != el_last; ++el_iter)
         {
            SV* sv = *el_iter;
            SV* rv = SvRV(sv);
            I32 hash = ISET_HASH(rv);
            I32 index = hash & newmax;

            if (index == i)
            {
               *el_out_iter++ = *el_iter;
               continue;
            }

            new_bucket = bucket_first + index;

            if (*new_bucket == &sv_undef)
            {
               AV* pb = newAV();
               av_push(pb, sv);
               av_store(array, new_bucket - bucket_first, newRV_noinc((SV*) pb));
            }
            else
            {
               av_push((AV*) SvRV(*new_bucket), sv);
            }
         
         }
         
         newfill = el_out_iter - AvARRAY(bucket) - 1;

         for (; el_out_iter != el_last; ++el_out_iter)
         {
            *el_out_iter = &sv_undef;
         }

         av_fill(bucket, newfill);
      }

      s->iset_max = newmax;
   }
}

MODULE = Set::Object		PACKAGE = Set::Object		

PROTOTYPES: DISABLE
      

SV*
new(pkg, ...)
   SV* pkg;

   PPCODE:

      SV* self;
      AV* array = newAV();
      ISET* s;
      I32 item;
      
      array->sv_any = (struct xpvav*) saferealloc(array->sv_any, sizeof(ISET));

      s = (ISET*) array->sv_any;
      s->iset_fill = 0;
      s->iset_elems = 0;
      s->iset_max = -1;

      self = newRV_noinc((SV*) array);
      sv_bless(self, gv_stashsv(pkg, FALSE));
      sv_2mortal(self);

      for (item = 1; item < items; ++item)
      {
         iset_insert_one(array, ST(item));
      }

      PUSHs(self);
      XSRETURN(1);

void
insert(self, ...)
   SV* self;

   PPCODE:

      AV* array = (AV*) SvRV(self);
      ISET* s = (ISET*) array->sv_any;
      I32 item;
      int init_elems = s->iset_elems;

      for (item = 1; item < items; ++item)
      {
         iset_insert_one(array, ST(item));
      }

      XSRETURN_IV(s->iset_elems - init_elems);

void
remove(self, ...)
   SV* self;

   PPCODE:

      AV* array = (AV*) SvRV(self);
      ISET* s = (ISET*) array->sv_any;
      I32 hash, index, item;
      SV **ppb, **el_iter, **el_last, **el_out_iter;
      AV* bucket;
      int init_elems = s->iset_elems;

      for (item = 1; item < items; ++item)
      {
         SV* el = ST(item);
         SV* rv = SvRV(el);
         I32 newfill;
         hash = ISET_HASH(rv);
         index = hash & s->iset_max;
         ppb = av_fetch(array, index, 0);

         if (!ppb)
            continue;

         bucket = (AV*) SvRV(*ppb);

         el_iter = AvARRAY(bucket);
         el_out_iter = el_iter;
         el_last = el_iter + av_len(bucket) + 1;

         for (; el_iter != el_last; ++el_iter)
         {
            if (SvRV(*el_iter) == rv)
            {
               SvREFCNT_dec(*el_iter);
               --s->iset_elems;
            }
            else
            {
               *el_out_iter++ = *el_iter;
            }
         }
         
         newfill = el_out_iter - AvARRAY(bucket) - 1;

         for (; el_out_iter != el_last; ++el_out_iter)
         {
            *el_out_iter = &sv_undef;
         }

         av_fill(bucket, newfill);
      }

      XSRETURN_IV(init_elems - s->iset_elems);

int
size(self)
   SV* self;

   CODE:

      ISET* s = (ISET*) ((AV*) SvRV(self))->sv_any;
      RETVAL = s->iset_elems;

   OUTPUT: RETVAL

void
includes(self, ...)
   SV* self;

   PPCODE:

      AV* array = (AV*) SvRV(self);
      ISET* s = (ISET*) array->sv_any;
      I32 hash, index, item;
      SV **ppb, **el_iter, **el_last;
      AV* bucket;

      for (item = 1; item < items; ++item)
      {
         SV* el = ST(item);
         SV* rv = SvRV(el);
         hash = ISET_HASH(rv);
         index = hash & s->iset_max;
         ppb = av_fetch(array, index, 0);

         if (!ppb)
            XSRETURN_NO;

         bucket = (AV*) SvRV(*ppb);

         el_iter = AvARRAY(bucket);
         el_last = el_iter + av_len(bucket) + 1;

         for (; el_iter != el_last; ++el_iter)
            if (SvRV(*el_iter) == rv)
               goto next;
            
         XSRETURN_NO;

         next: ;
      }

      XSRETURN_YES;


void
members(self)
   SV* self
   
   PPCODE:

      AV* array = (AV*) SvRV(self);
      SV** bucket_iter = AvARRAY(array);
      SV** bucket_last = bucket_iter + av_len(array) + 1;
      ISET* s = (ISET*) array->sv_any;

      EXTEND(sp, s->iset_elems - 1);

      for (; bucket_iter != bucket_last; ++bucket_iter)
      {
         AV* bucket;
         SV **el_iter, **el_last;

         if (*bucket_iter == &sv_undef)
            continue;

         bucket = (AV*) SvRV(*bucket_iter);

         el_iter = AvARRAY(bucket);
         el_last = el_iter + av_len(bucket) + 1;

         for (; el_iter != el_last; ++el_iter)
            if (*el_iter != &sv_undef)
               PUSHs(*el_iter);
      }

      XSRETURN(s->iset_elems);

void
clear(self)
   SV* self

   CODE:

      AV* array = (AV*) SvRV(self);
      SV** bucket_iter = AvARRAY(array);
      SV** bucket_last = bucket_iter + av_len(array) + 1;
      ISET* s = (ISET*) array->sv_any;

      for (; bucket_iter != bucket_last; ++bucket_iter)
      {
         if (*bucket_iter == &sv_undef)
            continue;

         SvREFCNT_dec(*bucket_iter);
         *bucket_iter = &sv_undef;
      }

      s->iset_elems = 0;