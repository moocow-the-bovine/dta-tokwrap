/*-*- Mode: C -*- */
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
/*#include "ppport.h"*/

typedef unsigned int uint;
typedef unsigned char uchar;

/*==============================================================================
 * Utils
 */

//--------------------------------------------------------------
static inline int avbs_cmp(unsigned int a, unsigned int b)
{
  if      (a<b) return -1;
  else if (a>b) return  1;
  return 0;
}

//--------------------------------------------------------------
static inline uint avbs_index(const uchar *v, uint i, uint nbits)
{
  switch (nbits) {
  default:
  case 1:	return (v[i>>3] >>  (i%8))     & 0x1;
  case 2:	return (v[i>>2] >> ((i%4)<<1)) & 0x3;
  case 4:	return (v[i>>1] >> ((i%2)<<2)) & 0xf;
  case 8:	return (v[i]);
  case 16:	i <<= 1; return (v[i]<<8)  | (v[i+1]);
  case 32:	i <<= 2; return (v[i]<<24) | (v[i+1]<<16) | (v[i+2]<<8) | (v[i+3]);
  }
}

//--------------------------------------------------------------
static inline void avbs_vset(uchar *v, uint i, uint nbits, uint val)
{
  int b;
  fprintf(stderr, "vset(i=%u, nbits=%u, val=%u)\n", i,nbits,val);
  switch (nbits) {
  default:
  case 1:
    /*if (val&1)	v[i>>3] |=  (0x1<<(i%8));
      else	v[i>>3] &= ~(0x1<<(i%8));*/
    /*
    v[i>>3] &= ~(0x1<<(i%8));
    v[i>>3] |=  ((val&0x1)<<(i%8))
    */
    b=i&0x7; i>>=3; v[i] ^= ((val & ((~v[i])>>b)) & 0x1)<<b;
    break;
  case 2:	v[i>>2] &= ((val&0x3)<<((i%4)<<1)) | ~(0x3<<((i%4)<<1)); break;
  case 4:	v[i>>1] &= ((val&0xf)<<((i%2)<<2)) | ~(0xf<<((i%2)<<2)); break;
  case 8:	v[i] = val; break;
  case 16:	i <<= 1; v[i]=(val>> 8)&0xff; v[i+1]=(val&0xff); break;
  case 32:	i <<= 2; v[i]=(val>>24)&0xff; v[i+1]=(val>>16)&0xff; v[i+2]=(val>>8)&0xff; v[i+3]=val&0xff; break;
  }
}

//--------------------------------------------------------------
static uint avbs_lower_bound(const uchar *v, uint key, uint ilo, uint ihi, uint nbits)
{
 uint imid;
 while (ihi-ilo > 1) {
   imid = (ihi+ilo) >> 1;
   if (avbs_index(v, imid, nbits) < key) {
     ilo = imid;
   } else {
     ihi = imid;
   }
 }
 if (avbs_index(v,ilo,nbits)==key) return ilo;
 if (avbs_index(v,ihi,nbits)<=key) return ihi;
 return ilo;
}

//--------------------------------------------------------------
static uint avbs_upper_bound(const uchar *v, uint key, uint ilo, uint ihi, uint nbits)
{
 uint imid;
 while (ihi-ilo > 1) {
   imid = (ihi+ilo) >> 1;
   if (avbs_index(v, imid, nbits) > key) {
     ihi = imid;
   } else {
     ilo = imid;
   }
 }
 if (avbs_index(v,ihi,nbits)==key) return ihi;
 if (avbs_index(v,ilo,nbits)>=key) return ilo;
 return ihi;
}

//--------------------------------------------------------------
static uint avbs_bsearch(const uchar *v, uint key, uint ilo, uint ihi, uint nbits)
{
  while (ilo < ihi) {
    uint imid = (ilo+ihi) >> 1;
 
    // code must guarantee the interval is reduced at each iteration
    //assert(imid < imax);
    // note: 0 <= imin < imax implies imid will always be less than imax
 
    if (avbs_index(v, imid, nbits) < key)
      ilo = imid + 1;
    else
      ihi = imid;
  }
 
  // deferred test for equality
  if ((ilo == ihi) && (avbs_index(v,ilo,nbits) == key))
    return ilo;
  else
    return (uint)-1;
}

/*==============================================================================
 * XS Guts
 */

MODULE = Algorithm::BinarySearch::Vec    PACKAGE = Algorithm::BinarySearch::Vec

PROTOTYPES: ENABLE

##=====================================================================
## DEBUG
##=====================================================================

##--------------------------------------------------------------
uint
vget(SV *vec, uint i, uint nbits)
PREINIT:
  uchar *vp;
CODE:
 vp = (uchar *)SvPV_nolen(vec);
 RETVAL = avbs_index(vp, i, nbits);
OUTPUT:
  RETVAL

##--------------------------------------------------------------
void
vset(SV *vec, uint i, uint nbits, uint val)
PREINIT:
  uchar *vp;
CODE:
 vp = (uchar *)SvPV_nolen(vec);
 avbs_vset(vp, i, nbits, val);


##=====================================================================
## BINARY SEARCH, element-wise

##--------------------------------------------------------------
uint
vbsearch(SV *vec, uint key, uint nbits, ...)
PREINIT:
  const uchar *v;
  uint vlen, ilo, ihi;
CODE:
 v = SvPV(vec,vlen);
 if (items > 3) ilo = SvUV(ST(3));
 else ilo = 0;
 if (items > 4) ihi = SvUV(ST(4));
 else ihi = vlen * 8/nbits;
 RETVAL = avbs_bsearch(v,key,ilo,ihi,nbits);
 if (RETVAL == (uint)-1)
   XSRETURN_UNDEF;
OUTPUT:
 RETVAL

##--------------------------------------------------------------
uint
vbsearch_lb(SV *vec, uint key, uint nbits, ...)
PREINIT:
  const uchar *v;
  uint vlen, ilo, ihi;
CODE:
 v = SvPV(vec,vlen);
 if (items > 3) ilo = SvUV(ST(3));
 else ilo = 0;
 if (items > 4) ihi = SvUV(ST(4));
 else ihi = vlen * 8/nbits;
 RETVAL = avbs_lower_bound(v,key,ilo,ihi,nbits);
OUTPUT:
 RETVAL

##--------------------------------------------------------------
uint
vbsearch_ub(SV *vec, uint key, uint nbits, ...)
PREINIT:
  const uchar *v;
  uint vlen, ilo, ihi;
CODE:
 v = SvPV(vec,vlen);
 if (items > 3) ilo = SvUV(ST(3));
 else ilo = 0;
 if (items > 4) ihi = SvUV(ST(4));
 else ihi = vlen * 8/nbits;
 RETVAL = avbs_upper_bound(v,key,ilo,ihi,nbits);
OUTPUT:
 RETVAL


##=====================================================================
## BINARY SEARCH, array-wise

AV*
avbsearch(SV *haystack, AV *needle, uint nbits, ...)
PREINIT:
  const uchar *v;
  uint vlen, ilo, ihi;
  I32 i,n;
CODE:
 v = SvPV(haystack,vlen);
 if (items > 3) ilo = SvUV(ST(3));
 else ilo = 0;
 if (items > 4) ihi = SvUV(ST(4));
 else ihi = vlen * 8/nbits;
 n = av_len(needle);
 RETVAL = newAV();
 av_extend(RETVAL, n);
 for (i=0; i<=n; ++i) {
   SV   **key   = av_fetch(needle, i, 0);
   uint   found = avbs_bsearch(v,SvUV(*key),ilo,ihi,nbits);
   av_store(RETVAL, i, (found == (uint)-1 ? newSV(0) : newSVuv(found)));
 }
OUTPUT:
 RETVAL
