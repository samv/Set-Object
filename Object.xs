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
        HV* outer;
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
  SV** oldsvref;

  if (!s->flat) {
    IF_INSERT_DEBUG(warn("iset_insert_scalar(%x): creating hashes", s));
    s->flat = newHV();
    s->outer = newHV();
  }

  //SvGETMAGIC(sv);
  key = SvPV(sv, len);
  IF_INSERT_DEBUG(warn("iset_insert_scalar(%x): sv (%x, rc = %d, str= '%s')!", s, sv, SvREFCNT(sv), SvPV_nolen(sv)));

  if (oldsvref = hv_fetch(s->outer, key, len, 0)) {
    SV* oldsv = *oldsvref;

    IF_INSERT_DEBUG(warn("iset_insert_scalar(%x): got old sv (%x, rc = %d, str= '%s')!", s, oldsv, SvREFCNT(oldsv), SvPV_nolen(oldsv)));

    SvREFCNT_inc(oldsv);
    if (!hv_store(s->flat, key, len, oldsv, 0)) {
      warn("hv store failed[?] set=%x, sv=%x(str='%s')",
	   s, oldsv, SvPV_nolen(oldsv));
    }

    IF_INSERT_DEBUG(warn("iset_insert_scalar(%x): remembering old sv (%x, rc = %d)!", s, oldsv, SvREFCNT(oldsv)));

    //warn("remove: rc++ (%x, rc = %d)!", oldsv, SvREFCNT(oldsv));
    //IF_INSERT_DEBUG(warn("iset_insert_scalar(%x): rc++ (%x, rc = %d)!", s, oldsv, SvREFCNT(oldsv)));

    hv_delete(s->outer, key, len, G_DISCARD);

    //SvREFCNT_dec(oldsv);

    IF_INSERT_DEBUG(warn("iset_insert_scalar(%x): deleted old sv (%x, rc = %d)!", s, oldsv, SvREFCNT(oldsv)));

    // convert to a string...
    //warn("Found, removing via delete");
    return 1;
  }
  else if (!hv_exists(s->flat, key, len)) {

    SV* newsv;

    IF_INSERT_DEBUG(warn("iset_insert_scalar(%x): sv (%x, rc = %d)!", s, sv, SvREFCNT(sv)));

    newsv = newSVsv(sv);

    SvREFCNT_inc(sv);

    if (hv_store(s->flat, key, len, newsv, 0)) {
      IF_INSERT_DEBUG(warn("iset_insert_scalar(%x): newsv (%x, rc = %d) stored", s, newsv, SvREFCNT(newsv)));
    } else {
      SvREFCNT_dec(newsv);
      warn("set insert of scalar '%s' failed!", SvPV_nolen(newsv));
    }

    return 1;
  }

  return 0;
}

int iset_remove_scalar(ISET* s, SV* sv)
{
  STRLEN len;
  char* key = 0;
  SV** oldsvref;

  if (!s->flat) {
    IF_REMOVE_DEBUG(warn("iset_remove_scalar(%x): shortcut for %x(str = '%s') (no hash)", s, sv, SvPV_nolen(sv)));
    return 0;
  }

  //IF_DEBUG(warn("Checking for existance of %s", SvPV_nolen(sv)));
  //SvGETMAGIC(sv);
  IF_REMOVE_DEBUG(warn("iset_remove_scalar(%x): sv (%x, rc = %d, str= '%s')!", s, sv, SvREFCNT(sv), SvPV_nolen(sv)));

  key = SvPV(sv, len);

  if (oldsvref = hv_fetch(s->flat, key, len, 0)) {
    SV* oldsv = *oldsvref;

    IF_REMOVE_DEBUG(warn("iset_remove_scalar(%x): got old sv (%x, rc = %d, str= '%s')!", s, oldsv, SvREFCNT(oldsv), SvPV_nolen(oldsv)));

    SvREFCNT_inc(oldsv);

    hv_store(s->outer, key, len, oldsv, 0);

    IF_REMOVE_DEBUG(warn("iset_remove_scalar(%x): remembered old sv (%x, rc = %d)!", s, oldsv, SvREFCNT(oldsv)));

    //warn("remove: rc++ (%x, rc = %d)!", oldsv, SvREFCNT(oldsv));
    IF_REMOVE_DEBUG(warn("iset_remove_scalar(%x): removed old sv (%x, rc = %d)!", s, oldsv, SvREFCNT(oldsv)));

    hv_delete(s->flat, key, len, G_DISCARD);

    IF_REMOVE_DEBUG(warn("iset_remove_scalar(%x): deleted old sv (%x, rc = %d)!", s, oldsv, SvREFCNT(oldsv)));

    // convert to a string...
    //warn("Found, removing via delete");
    return 1;
  }
  return 0;
  
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
	BUCKET** ppb;
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
	   //warn("created set id = %x", s);
	   s->elems = 0;
	   s->bucket = 0;
	   s->buckets = 0;
	   s->flat = 0;

	   // warning: cast from pointer to integer of different size
	   isv = newSViv((IV) s);
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
	  ISET* s = (ISET*) SvIV(SvRV(self));
      I32 item;
int inserted = 0;

      for (item = 1; item < items; ++item)
      {
	if (s == ST(item)) {
	  warn("INSERTING SET UP OWN ARSE");
	}
	if ISET_INSERT(s, ST(item))
			inserted++;
		  IF_DEBUG(warn("inserting %p %p size = %d\n", ST(item), SvRV(ST(item)), s->elems));
      }


      XSRETURN_IV(inserted);
  
void
is_universal(self, ...)
     SV* self;

     PPCODE:
      ISET* s = (ISET*) SvIV(SvRV(self));

      if (s->flat) {
	if (HvUSEDKEYS(s->outer))
	  XSRETURN_UNDEF;
      }

      XSRETURN_IV(1);

void
_complement(self, ...)
     SV* self;

     PPCODE:
      ISET* s = (ISET*) SvIV(SvRV(self));

      if (s->flat) {
	HV* slurp = s->outer;
	s->outer = s->flat;
	s->flat = slurp;
      }

      XSRETURN_IV(1);

void
_(self, ...)
     SV* self;

     CODE:
      ISET* s = (ISET*) SvIV(SvRV(self));
      SV* flat, *outer;

      POPs;

      if (!s->flat) {
	IF_INSERT_DEBUG(warn("iset_internal(%x): creating hashes", s));
	s->flat = newHV();
	s->outer = newHV();
      }

      flat = newRV_inc(s->flat);
      outer = newRV_inc(s->outer);
	
      SvREFCNT_inc(flat);
      SvREFCNT_inc(outer);
      PUSHs(sv_2mortal(flat));
      PUSHs(sv_2mortal(outer));
      XSRETURN(2);


     
void
remove(self, ...)
   SV* self;

   PPCODE:

      ISET* s = (ISET*) SvIV(SvRV(self));
      I32 hash, index, item;
      SV **el_iter, **el_last, **el_out_iter;
      BUCKET* bucket;
      int removed = 0;

      for (item = 1; item < items; ++item)
      {
         SV* el = ST(item);

	 if (!SvROK(el)) {
	   if (s->flat) {
	     IF_REMOVE_DEBUG(warn("Calling remove_scalar for ST(%d)", item));
	     if (iset_remove_scalar(s, el))
	       removed++;
	   }
	   continue;
	 }
	 IF_REMOVE_DEBUG(warn("using object remove for ST(%d)", item));
	 
         SV* rv = SvRV(el);
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
   ISET* s = (ISET*) SvIV(SvRV(self));

   if (s->elems)
     XSRETURN_UNDEF;

   if (s->flat) {
     if (HvUSEDKEYS(s->flat)) {
       //warn("got some keys: %d\n", HvUSEDKEYS(s->flat));
       XSRETURN_UNDEF;
     }
   }

   RETVAL = 1;

   OUTPUT: RETVAL

int
size(self)
   SV* self;

   CODE:
   ISET* s = (ISET*) SvIV(SvRV(self));

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

      ISET* s = (ISET*) SvIV(SvRV(self));
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

      ISET* s = (ISET*) SvIV(SvRV(self));
      BUCKET* bucket_iter = s->bucket;
      BUCKET* bucket_last = bucket_iter + s->buckets;

      EXTEND(sp, s->elems + (s->flat ? HvUSEDKEYS(s->flat) : 0) );

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
	  //warn("i=%d, num=%d", i, num);
	  HE* he = hv_iternext(s->flat);

	  //warn("Got here");
	  SV* topic = hv_iterval(s->flat, he);
	  //warn("Got here 2");
	  //warn("copying item - %x (rc = %d)", (int)topic, SvREFCNT(topic));
	  SV* el = newSVsv(topic);
	  PUSHs(sv_2mortal(el));
	  //warn("returning mortal - %x (rc = %d)", (int)el, SvREFCNT(el));
        }
      }
//warn("that's all, folks");

void
check(self)
   SV* self

   CODE:
      ISET* s = (ISET*) SvIV(SvRV(self));
      if (s->flat) {
	  HE* he; // he
	  hv_iterinit(s->flat);
	  while (he = hv_iternext(s->flat)) {
	    SV* el = hv_iterval(s->flat, he);

	    if (SvREFCNT(el) != 1) {
	      warn("iset_check: el = %x (rc = %d, str = '%s')", el, SvREFCNT(el), SvPV_nolen(el));
	    }
	  }
	  while (he = hv_iternext(s->outer)) {
	    SV* el = hv_iterval(s->flat, he);

	    if (SvREFCNT(el) != 1) {
	      warn("iset_check: outer el = %x (rc = %d, str = '%s')", el, SvREFCNT(el), SvPV_nolen(el));
	    }
	  }
      }

void
clear(self)
   SV* self

   CODE:
      ISET* s = (ISET*) SvIV(SvRV(self));

      iset_clear(s);
      if (s->flat) {
	  HE* he; // he
	  hv_iterinit(s->flat);
	  while (he = hv_iternext(s->flat)) {
	    int len;
	    char* key = HePV(he, len);
	    SV* el = hv_iterval(s->flat, he);

	    IF_REMOVE_DEBUG(warn("iset_clear: el = %x (rc = %d, str = '%s')", el, SvREFCNT(el), SvPV_nolen(el)));
	    hv_delete(s->flat, key, len, G_DISCARD);
	    IF_REMOVE_DEBUG(warn("iset_clear: DELETED: el = %x (rc = %d)", el, SvREFCNT(el)));
	    SvREFCNT_inc(el);
	    if (!hv_store(s->outer, key, len, el, 0)) {
	      warn("set internal error (hv_store) with '%s'", SvPV_nolen(el));
	    }
	    IF_REMOVE_DEBUG(warn("iset_clear: STORED in outer: el = %x (rc = %d)", el, SvREFCNT(el)));
	  }
      }
      
void
fill(self)
   SV* self

   CODE:
      ISET* s = (ISET*) SvIV(SvRV(self));

      iset_clear(s);
      if (s->flat) {
	  HE* he; // he
	  hv_iterinit(s->outer);
	  while (he = hv_iternext(s->outer)) {
	    int len;
	    char* key = HePV(he, len);
	    SV* el = hv_iterval(s->outer, he);

	    IF_REMOVE_DEBUG(warn("iset_fill: el = %x (rc = %d, str = '%s')", el, SvREFCNT(el), SvPV_nolen(el)));
	    hv_delete(s->outer, key, len, G_DISCARD);
	    IF_REMOVE_DEBUG(warn("iset_fill: DELETED: el = %x (rc = %d)", el, SvREFCNT(el)));
	    SvREFCNT_inc(el);
	    if (!hv_store(s->flat, key, len, el, 0)) {
	      warn("set internal error (hv_store) with '%s'", SvPV_nolen(el));
	    }
	    IF_REMOVE_DEBUG(warn("iset_fill: STORED in outer: el = %x (rc = %d)", el, SvREFCNT(el)));
	  }
      }
 
void
DESTROY(self)
   SV* self

   CODE:

      ISET* s = (ISET*) SvIV(SvRV(self));
      IF_DEBUG(warn("aargh!\n"));
//warn("destroying set id = %x", s);
      iset_clear(s);
      if (s->flat) {
	//warn("about to dec self(%x/%x)->flat(%x) from %d",
	     //self, s, s->flat, SvREFCNT(s->flat));
	//SvREFCNT_dec(s->flat);
	//warn("ok");
	//warn("about to dec outer(%x/%x)->flat(%x) from %d",
	     //self, s, s->outer, SvREFCNT(s->outer));
	//SvREFCNT_dec(s->outer);
	//warn("ok");
	//warn("that took them to (rc(flat) == %d, rc(outer) == %d)",
	     //SvREFCNT(s->flat), SvREFCNT(s->outer) );
	  //hv_undef(s->flat);
	  //s->flat = 0;
	  //hv_undef(s->outer);
	  //s->outer = 0;
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
	   SvIV_set(isv, (IV) s);
	   SvIOK_on(isv);

	   for (item = 3; item < items; ++item)
	   {
		  ISET_INSERT(s, ST(item));
	   }

      IF_DEBUG(warn("set!\n"));

      PUSHs(obj);
      XSRETURN(1);
   }
