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

#define IF_DEBUG(e)

typedef struct _BUCKET
{
	SV** sv;
	int n;
} BUCKET;

typedef struct _ISET
{
	BUCKET* bucket;
	I32 buckets, elems;
} ISET;

#define ISET_HASH(el) ((I32) (el) >> 4)

int insert_in_bucket(BUCKET* pb, SV* sv)
{
	if (!pb->sv)
	{
		New(0, pb->sv, 1, SV*);
		pb->sv[0] = sv;
		pb->n = 1;
		IF_DEBUG(warn("inserting %p in bucket %p offset %d\n", sv, pb, 0));
	}
	else
	{
		SV **iter = pb->sv, **last = pb->sv + pb->n, **hole = 0;

		for (; iter != last; ++iter)
		{
			if (*iter)
			{
				if (*iter == sv)
					return 0;
			}
			else
				hole = iter;
		}

		if (!hole)
		{
			Renew(pb->sv, pb->n + 1, SV*);
			hole = pb->sv + pb->n;
			++pb->n;
		}

		*hole = sv;

		IF_DEBUG(warn("inserting %p in bucket %p offset %d\n", sv, pb, iter - pb->sv));
	}
	
	return 1;
}

void iset_insert_one(ISET* s, SV* rv)
{
	BUCKET** ppb;
	I32 hash, index;
	SV* el = SvRV(rv);

	SvROK(rv);

	if (!s->buckets)
	{
		Newz(0, s->bucket, 8, BUCKET);
		s->buckets = 8;
	}

	hash = ISET_HASH(el);
	index = hash & (s->buckets - 1);

	if (insert_in_bucket(s->bucket + index, el))
	{
		++s->elems;
		SvREFCNT_inc(el);
		IF_DEBUG(warn("rc of %p bumped to %d\n", el, SvREFCNT(el)));
	}

	if (s->elems > s->buckets)
	{
		int oldn = s->buckets;
		int newn = oldn << 1;

		BUCKET *bucket_first, *bucket_iter, *bucket_last, *new_bucket;
		int i;

		IF_DEBUG(warn("Reindexing, n = %d\n", s->elems));

		Renew(s->bucket, newn, BUCKET);
		Zero(s->bucket + oldn, oldn, BUCKET);
		s->buckets = newn;

		bucket_first = s->bucket;
		bucket_iter = bucket_first;
		bucket_last = bucket_iter + oldn;

		for (i = 0; bucket_iter != bucket_last; ++bucket_iter, ++i)
		{
			SV **el_iter, **el_last, **el_out_iter;
			I32 new_bucket_size;

			if (!bucket_iter->sv)
				continue;

			el_iter = bucket_iter->sv;
			el_last = el_iter + bucket_iter->n;
			el_out_iter = el_iter;

			for (; el_iter != el_last; ++el_iter)
			{
				SV* sv = *el_iter;
				I32 hash = ISET_HASH(sv);
				I32 index = hash & (newn - 1);

				if (index == i)
				{
					*el_out_iter++ = *el_iter;
					continue;
				}

				new_bucket = bucket_first + index;
				IF_DEBUG(warn("%p moved from bucket %d:%p to %d:%p",
					sv, i, bucket_iter, index, new_bucket));
				insert_in_bucket(new_bucket, sv);
			}
         
			new_bucket_size = el_out_iter - bucket_iter->sv;

			if (!new_bucket_size)
			{
				Safefree(bucket_iter->sv);
				bucket_iter->sv = 0;
				bucket_iter->n = 0;
			}

			else if (new_bucket_size < bucket_iter->n)
			{
				Renew(bucket_iter->sv, new_bucket_size, SV*);
				bucket_iter->n = new_bucket_size;
			}
		}
	}
}

void iset_clear(ISET* s)
{
	BUCKET* bucket_iter = s->bucket;
	BUCKET* bucket_last = bucket_iter + s->buckets;

	for (; bucket_iter != bucket_last; ++bucket_iter)
	{
		SV **el_iter, **el_last;

		if (!bucket_iter->sv)
            continue;

		el_iter = bucket_iter->sv;
		el_last = el_iter + bucket_iter->n;

		for (; el_iter != el_last; ++el_iter)
		{
			if (*el_iter)
			{
				IF_DEBUG(warn("freeing %p, rc = %d, bucket = %p(%d) pos = %d\n",
					 *el_iter, SvREFCNT(*el_iter),
					 bucket_iter, bucket_iter - s->bucket,
					 el_iter - bucket_iter->sv));

				SvREFCNT_dec(*el_iter);
				*el_iter = 0;
			}
		}

		Safefree(bucket_iter->sv);

		bucket_iter->sv = 0;
		bucket_iter->n = 0;
	}

	Safefree(s->bucket);
	s->bucket = 0;
	s->buckets = 0;
	s->elems = 0;
}


MODULE = Set::Object		PACKAGE = Set::Object		

PROTOTYPES: DISABLE

SV*
new(pkg, ...)
   SV* pkg;

   PPCODE:

   {
	   SV* self;
	   ISET* s;
	   I32 item;
	   SV* isv;
	
	   New(0, s, 1, ISET);
	   s->elems = 0;
	   s->bucket = 0;
	   s->buckets = 0;

	   isv = newSViv((IV) s);
	   sv_2mortal(isv);

	   self = newRV_inc(isv);
	   sv_2mortal(self);

	   sv_bless(self, gv_stashsv(pkg, FALSE));

	   for (item = 1; item < items; ++item)
	   {
		   iset_insert_one(s, ST(item));
	   }

      IF_DEBUG(warn("set!\n"));

      PUSHs(self);
      XSRETURN(1);
   }

void
insert(self, ...)
   SV* self;

   PPCODE:
	  ISET* s = (ISET*) SvIV(SvRV(self));
      I32 item;
      int init_elems = s->elems;

      for (item = 1; item < items; ++item)
      {
		  iset_insert_one(s, ST(item));
		  IF_DEBUG(warn("inserting %p %p size = %d\n", ST(item), SvRV(ST(item)), s->elems));
      }


      XSRETURN_IV(s->elems - init_elems);
  
void
remove(self, ...)
   SV* self;

   PPCODE:

      ISET* s = (ISET*) SvIV(SvRV(self));
      I32 hash, index, item;
      SV **el_iter, **el_last, **el_out_iter;
      BUCKET* bucket;
      int init_elems = s->elems;

      for (item = 1; item < items; ++item)
      {
         SV* el = ST(item);
         SV* rv = SvRV(el);
         hash = ISET_HASH(rv);
         index = hash & (s->buckets - 1);
         bucket = s->bucket + index;

         if (!bucket->sv)
            continue;

         el_iter = bucket->sv;
         el_out_iter = el_iter;
         el_last = el_iter + bucket->n;

         for (; el_iter != el_last; ++el_iter)
         {
            if (*el_iter == rv)
            {
               SvREFCNT_dec(rv);
			   *el_iter = 0;
               --s->elems;
			   break;
            }
         }
	  }

      XSRETURN_IV(init_elems - s->elems);

int
size(self)
   SV* self;

   CODE:

      RETVAL = ((ISET*) SvIV(SvRV(self)))->elems;

   OUTPUT: RETVAL

int
rc(self)
   SV* self;

   CODE:

      RETVAL = SvREFCNT(self);

   OUTPUT: RETVAL

int
rvrc(self)
   SV* self;

   CODE:

      RETVAL = SvREFCNT(SvRV(self));

   OUTPUT: RETVAL

void
includes(self, ...)
   SV* self;

   PPCODE:

      ISET* s = (ISET*) SvIV(SvRV(self));
      I32 hash, index, item;
      SV **el_iter, **el_last;
      BUCKET* bucket;

      for (item = 1; item < items; ++item)
      {
         SV* el = ST(item);
         SV* rv = SvRV(el);

         if (!s->buckets)
            XSRETURN_NO;

         hash = ISET_HASH(rv);
         index = hash & (s->buckets - 1);
         bucket = s->bucket + index;

		 IF_DEBUG(warn("includes: looking for %p in bucket %d:%p",
		      rv, index, bucket));

         if (!bucket->sv)
            XSRETURN_NO;

         el_iter = bucket->sv;
         el_last = el_iter + bucket->n;

         for (; el_iter != el_last; ++el_iter)
            if (*el_iter == rv)
               goto next;
            
         XSRETURN_NO;

         next: ;
      }

      XSRETURN_YES;


void
members(self)
   SV* self
   
   PPCODE:

      ISET* s = (ISET*) SvIV(SvRV(self));
      BUCKET* bucket_iter = s->bucket;
      BUCKET* bucket_last = bucket_iter + s->buckets;

      EXTEND(sp, s->elems - 1);

      for (; bucket_iter != bucket_last; ++bucket_iter)
      {
         SV **el_iter, **el_last;

         if (!bucket_iter->sv)
            continue;

         el_iter = bucket_iter->sv;
         el_last = el_iter + bucket_iter->n;

         for (; el_iter != el_last; ++el_iter)
            if (*el_iter)
			{
				SV* el = newRV(*el_iter);
				sv_bless(el, SvSTASH(*el_iter));
				sv_2mortal(el);
               	PUSHs(el);
			}
      }

void
clear(self)
   SV* self

   CODE:

      iset_clear((ISET*) SvIV(SvRV(self)));

void
DESTROY(self)
   SV* self

   CODE:

      ISET* s = (ISET*) SvIV(SvRV(self));
	  IF_DEBUG(warn("aargh!\n"));
      iset_clear(s);
      Safefree(s);
      


