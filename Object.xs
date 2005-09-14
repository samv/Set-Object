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

#include "ppport.h"

// for debugging object-related functions
#define IF_DEBUG(e)

// for debugging scalar-related functions
#define IF_REMOVE_DEBUG(e)
#define IF_INSERT_DEBUG(e)

typedef struct _BUCKET
{
	SV** sv;
	int n;
} BUCKET;

typedef struct _ISET
{
	BUCKET* bucket;
	I32 buckets, elems;
        HV* flat;
} ISET;

#define ISET_HASH(el) ((I32) (el) >> 4)

#define ISET_INSERT(s, item) \
	     ( SvROK(item) \
	       ? iset_insert_one(s, item) \
               : iset_insert_scalar(s, item) )

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

int iset_insert_scalar(ISET* s, SV* sv)
{
  STRLEN len;
  char* key = 0;

  if (!s->flat) {
    IF_INSERT_DEBUG(warn("iset_insert_scalar(%x): creating scalar hash", s));
    s->flat = newHV();
  }

  //SvGETMAGIC(sv);
  key = SvPV(sv, len);

  IF_INSERT_DEBUG(warn("iset_insert_scalar(%x): sv (%x, rc = %d, str= '%s')!", s, sv, SvREFCNT(sv), SvPV_nolen(sv)));

  if (!hv_exists(s->flat, key, len)) {

    if (!hv_store(s->flat, key, len, &PL_sv_undef, 0)) {
      warn("hv store failed[?] set=%x", s);
    }

    IF_INSERT_DEBUG(warn("iset_insert_scalar(%x): inserted OK!", s));

    return 1;
  }
  else {
    
    IF_INSERT_DEBUG(warn("iset_insert_scalar(%x): already there!", s));
    return 0;
  }

}

int iset_remove_scalar(ISET* s, SV* sv)
{
  STRLEN len;
  char* key = 0;

  if (!s->flat) {
    IF_REMOVE_DEBUG(warn("iset_remove_scalar(%x): shortcut for %x(str = '%s') (no hash)", s, sv, SvPV_nolen(sv)));
    return 0;
  }

  //IF_DEBUG(warn("Checking for existance of %s", SvPV_nolen(sv)));
  //SvGETMAGIC(sv);
  IF_REMOVE_DEBUG(warn("iset_remove_scalar(%x): sv (%x, rc = %d, str= '%s')!", s, sv, SvREFCNT(sv), SvPV_nolen(sv)));

  key = SvPV(sv, len);

  if ( hv_delete(s->flat, key, len, 0) ) {

    IF_REMOVE_DEBUG(warn("iset_remove_scalar(%x): deleted key", s));
    return 1;

  } else {

    IF_REMOVE_DEBUG(warn("iset_remove_scalar(%x): key not absent", s));
    return 0;
  }
  
}

bool iset_includes_scalar(ISET* s, SV* sv)
{
  if (s->flat) {
    STRLEN len;
    char* key = SvPV(sv, len);
    return hv_exists(s->flat, key, len);
  }
  else {
    return 0;
  }
}


int iset_insert_one(ISET* s, SV* rv)
{
	I32 hash, index;
	SV* el;
	int ins = 0;

	if (!SvROK(rv))
	{
	    Perl_croak(aTHX_ "Tried to insert a non-reference into a Set::Object");
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
		++ins;
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

	return ins;
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

void
new(pkg, ...)
   SV* pkg;

   PPCODE:

   {
	   SV* self;
	   ISET* s;
	   I32 item;
	   SV* isv;
	
	   New(0, s, 1, ISET);
	   //warn("created set id = %x", s);
	   s->elems = 0;
	   s->bucket = 0;
	   s->buckets = 0;
	   s->flat = 0;

	   // warning: cast from pointer to integer of different size
	   isv = newSViv( PTR2IV(s) );
	   sv_2mortal(isv);

	   self = newRV_inc(isv);
	   sv_2mortal(self);

	   sv_bless(self, gv_stashsv(pkg, FALSE));

	   for (item = 1; item < items; ++item)
	   {
		   ISET_INSERT(s, ST(item));
	   }

      IF_DEBUG(warn("set!\n"));

      PUSHs(self);
      XSRETURN(1);
   }

void
insert(self, ...)
   SV* self;

   PPCODE:
      ISET* s = INT2PTR(ISET*, SvIV(SvRV(self)));
      I32 item;
      int inserted = 0;

      for (item = 1; item < items; ++item)
      {
	if ((SV*)s == ST(item)) {
	  warn("INSERTING SET UP OWN ARSE");
	}
	if ISET_INSERT(s, ST(item))
			inserted++;
		  IF_DEBUG(warn("inserting %p %p size = %d\n", ST(item), SvRV(ST(item)), s->elems));
      }


      XSRETURN_IV(inserted);
  
void
remove(self, ...)
   SV* self;

   PPCODE:

      ISET* s = INT2PTR(ISET*, SvIV(SvRV(self)));
      I32 hash, index, item;
      SV **el_iter, **el_last, **el_out_iter;
      BUCKET* bucket;
      int removed = 0;

      for (item = 1; item < items; ++item)
      {
         SV* el = ST(item);
         SV *rv;

	 if (!SvROK(el)) {
	   if (s->flat) {
	     IF_REMOVE_DEBUG(warn("Calling remove_scalar for ST(%d)", item));
	     if (iset_remove_scalar(s, el))
	       removed++;
	   }
	   continue;
	 }
	 IF_REMOVE_DEBUG(warn("using object remove for ST(%d)", item));
	 
         rv = SvRV(el);
         hash = ISET_HASH(rv);
         index = hash & (s->buckets - 1);
         bucket = s->bucket + index;


	 if (s->buckets == 0)
	   goto remove_out;

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
	       removed++;
			   break;
            }
         }
      }
remove_out:
      XSRETURN_IV(removed);

int
is_null(self)
   SV* self;

   CODE:
   ISET* s = INT2PTR(ISET*, SvIV(SvRV(self)));

   if (s->elems)
     XSRETURN_UNDEF;

   if (s->flat) {
     if (HvKEYS(s->flat)) {
       //warn("got some keys: %d\n", HvKEYS(s->flat));
       XSRETURN_UNDEF;
     }
   }

   RETVAL = 1;

   OUTPUT: RETVAL

int
size(self)
   SV* self;

   CODE:
   ISET* s = INT2PTR(ISET*, SvIV(SvRV(self)));

   RETVAL = s->elems + (s->flat ? HvKEYS(s->flat) : 0);
               

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

      ISET* s = INT2PTR(ISET*, SvIV(SvRV(self)));
      I32 hash, index, item;
      SV **el_iter, **el_last;
      BUCKET* bucket;

      for (item = 1; item < items; ++item)
      {
         SV* el = ST(item);
         SV* rv;

	 if (!SvROK(el)) {
	   IF_DEBUG(warn("includes! el = %s\n", SvPV_nolen(el)));
	   if (!iset_includes_scalar(s, el))
	     XSRETURN_NO;
	   goto next;
	 }

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

      ISET* s = INT2PTR(ISET*, SvIV(SvRV(self)));
      BUCKET* bucket_iter = s->bucket;
      BUCKET* bucket_last = bucket_iter + s->buckets;

      EXTEND(sp, s->elems + (s->flat ? HvKEYS(s->flat) : 0) );

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
				PUSHs(sv_2mortal(el));
				//XPUSHs(el);
				//PUSHs(el);
			}
      }

      if (s->flat) {
        int i = 0, num = hv_iterinit(s->flat);

        while (i++ < num) {
	  HE* he = hv_iternext(s->flat);

	  PUSHs(HeSVKEY_force(he));
        }
      }
//warn("that's all, folks");

void
clear(self)
   SV* self

   CODE:
      ISET* s = INT2PTR(ISET*, SvIV(SvRV(self)));

      iset_clear(s);
      if (s->flat) {
	hv_clear(s->flat);
	IF_REMOVE_DEBUG(warn("iset_clear(%x): cleared", s));
      }
      
void
DESTROY(self)
   SV* self

   CODE:
      ISET* s = INT2PTR(ISET*, SvIV(SvRV(self)));
      IF_DEBUG(warn("aargh!\n"));
      iset_clear(s);
      if (s->flat) {
	hv_undef(s->flat);
      }
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
    } else {
      RETVAL = 0;
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

   PPCODE:

   {
	   ISET* s;
	   I32 item;
	   SV* isv;
	
	   New(0, s, 1, ISET);
	   s->elems = 0;
	   s->bucket = 0;
	   s->buckets = 0;
	   s->flat = 0;

	   if (!SvROK(obj)) {
	     Perl_croak(aTHX_ "Set::Object::STORABLE_thaw passed a non-reference");
	   }

	   /* FIXME - some random segfaults with 5.6.1, Storable 2.07,
		      freezing closures, and back-references to
		      overloaded objects.  One day I might even
		      understand why :-)

		      Bug in Storable... that's why.  old news.
	    */
	   isv = SvRV(obj);
	   SvIV_set(isv, PTR2IV(s) );
	   SvIOK_on(isv);

	   for (item = 3; item < items; ++item)
	   {
		  ISET_INSERT(s, ST(item));
	   }

      IF_DEBUG(warn("set!\n"));

      PUSHs(obj);
      XSRETURN(1);
   }
