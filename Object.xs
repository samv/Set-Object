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
	SV* el;

	if (!SvROK(rv))
	{
	  Perl_croak(aTHX_ "Tried to insert non-reference in a Set::Object");
	};

	el = SvRV(rv);

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

      if (s->buckets == 0)
	 goto remove_out;

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
remove_out:
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
   
   if (SvROK(self)) {
     RETVAL = SvREFCNT(SvRV(self));
   } else {
     XSRETURN_UNDEF;
   }

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
         SV* rv;

	 if (!SvROK(el))
	   XSRETURN_NO;

	 rv = SvRV(el);

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
				if (SvOBJECT(*el_iter)) {
				  sv_bless(el, SvSTASH(*el_iter));
				}
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
      
   /* Here are some functions from Scalar::Util; they are so simple,
      that it isn't worth making a dependancy on that module. */

int
is_int(sv)
	SV *sv
PROTOTYPE: $
CODE:
  SvGETMAGIC(sv);
  if ( !SvIOKp(sv) )
     XSRETURN_UNDEF;

  RETVAL = 1;
OUTPUT:
  RETVAL

int
is_string(sv)
	SV *sv
PROTOTYPE: $
CODE:
  SvGETMAGIC(sv);
  if ( !SvPOKp(sv) )
     XSRETURN_UNDEF;

  RETVAL = 1;
OUTPUT:
  RETVAL

int
is_double(sv)
	SV *sv
PROTOTYPE: $
CODE:
  SvGETMAGIC(sv);
  if ( !SvNOKp(sv) )
     XSRETURN_UNDEF;

  RETVAL = 1;
OUTPUT:
  RETVAL


char *
blessed(sv)
    SV * sv
PROTOTYPE: $
CODE:
{
    if (SvMAGICAL(sv))
	mg_get(sv);
    if(!sv_isobject(sv)) {
	XSRETURN_UNDEF;
    }
    RETVAL = sv_reftype(SvRV(sv),TRUE);
}
OUTPUT:
    RETVAL

char *
reftype(sv)
    SV * sv
PROTOTYPE: $
CODE:
{
    if (SvMAGICAL(sv))
	mg_get(sv);
    if(!SvROK(sv)) {
	XSRETURN_UNDEF;
    }
    RETVAL = sv_reftype(SvRV(sv),FALSE);
}
OUTPUT:
    RETVAL

UV
refaddr(sv)
    SV * sv
PROTOTYPE: $
CODE:
{
    if(SvROK(sv)) {
      // Don't return undef if not a valid ref - return 0 instead
      // (less "Use of uninitialised value..." messages)

      // XSRETURN_UNDEF;
	RETVAL = PTR2UV(SvRV(sv));
    }
}
OUTPUT:
    RETVAL


int
_ish_int(sv)
	SV *sv
PROTOTYPE: $
CODE:
  double dutch;
  int innit;
  STRLEN lp;  // world famous in NZ
  SV * MH;
  // This function returns the integer value of a passed scalar, as
  // long as the scalar can reasonably considered to already be a
  // representation of an integer.  This means if you want strings to
  // be interpreted as integers, you're going to have to add 0 to
  // them.

  if (SvMAGICAL(sv)) {
    // probably a tied scalar
    //mg_get(sv);
    Perl_croak(aTHX_ "Tied variables not supported");
  }

  if (SvAMAGIC(sv)) {
    // an overloaded variable.  need to actually call a function to
    // get its value.
    Perl_croak(aTHX_ "Overloaded variables not supported");
  }

  if (SvNIOKp(sv)) {
    // NOK - the scalar is a double

    if (SvPOKp(sv)) {
      // POK - the scalar is also a string.

      // we have to be careful; a scalar "2am" or, even worse, "2e6"
      // may satisfy this condition if it has been evaluated in
      // numeric context.  Remember, we are testing that the value
      // could already be considered an _integer_, and AFAIC 2e6 and
      // 2.0 are floats, end of story.

      // So, we stringify the numeric part of the passed SV, turn off
      // the NOK bit on the scalar, so as to perform a string
      // comparison against the passed in value.  If it is not the
      // same, then we almost certainly weren't given an integer.

      if (SvIOKp(sv)) {
	MH = newSViv(SvIV(sv));
      } else if (SvNOKp(sv)) {
	MH = newSVnv(SvNV(sv));
      }
      sv_2pv(MH, &lp);
      SvPOK_only(MH);

      if (sv_cmp(MH, sv) != 0) {
	XSRETURN_UNDEF;
      }
    }

    if (SvNOKp(sv)) {
      // How annoying - it's a double
      dutch = SvNV(sv);
      if (SvIOKp(sv)) {
	innit = SvIV(sv);
      } else {
	innit = (int)dutch;
      }
      if (dutch - innit < (0.000000001)) {
	RETVAL = innit;
      } else {
	XSRETURN_UNDEF;
      }
    } else if (SvIOKp(sv)) {
      RETVAL = SvIV(sv);
    }
  } else {
    XSRETURN_UNDEF;
  }
OUTPUT:
  RETVAL

int
is_overloaded(sv)
	SV *sv
PROTOTYPE: $
CODE:
  SvGETMAGIC(sv);
  if ( !SvAMAGIC(sv) )
     XSRETURN_UNDEF;
  RETVAL = 1;
OUTPUT:
  RETVAL

int
is_object(sv)
	SV *sv
PROTOTYPE: $
CODE:
  SvGETMAGIC(sv);
  if ( !SvOBJECT(sv) )
     XSRETURN_UNDEF;
  RETVAL = 1;
OUTPUT:
  RETVAL

void
_STORABLE_thaw(obj, cloning, serialized, ...)
   SV* obj;
   SV* cloning;
   SV* serialized;

   PPCODE:

   {
	   ISET* s;
	   I32 item;
	   SV* isv;
	
	   New(0, s, 1, ISET);
	   s->elems = 0;
	   s->bucket = 0;
	   s->buckets = 0;

	   if (!SvROK(obj)) {
	     Perl_croak(aTHX_ "Set::Object::STORABLE_thaw passed a non-reference");
	   }

	   /* FIXME - some random segfaults with 5.6.1, Storable 2.07,
		      freezing closures, and back-references to
		      overloaded objects.  One day I might even
		      understand why :-)
	    */
	   isv = SvRV(obj);
	   SvIV_set(isv, (IV) s);
	   SvIOK_on(isv);

	   for (item = 3; item < items; ++item)
	   {
		   iset_insert_one(s, ST(item));
	   }

      IF_DEBUG(warn("set!\n"));

      PUSHs(obj);
      XSRETURN(1);
   }
