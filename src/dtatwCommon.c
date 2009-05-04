#include "dtatwCommon.h"

/*======================================================================
 * Globals
 */
char *prog = "dtatwCommon"; //-- used for error reporting
char *CX_NIL_ID = "-";
char *CX_LB_ID  = "$LB$";

/*======================================================================
 * Utils: basename
 */
char *file_basename(char *dst, const char *src, const char *suff, int srclen, int dstlen)
{
  const char *base0, *base1;
  int suflen = strlen(suff);
  if (srclen < 0) srclen = strlen(src);

  base1 = src+srclen;
  if (srclen >= suflen && strcmp(suff,src+srclen-suflen)==0) base1 -= suflen;

  //-- scan backwards for first directory separator
  for (base0=base1; *base0 != '/' && *base0 != '\\'; base0--) {
    if (base0==src) break;
  }

  //-- maybe allocate dst
  if (dst==NULL) {
    if (dstlen <= 0) dstlen  = base1-base0+1;
    else             dstlen += base1-base0+1;
    dst = (char*)malloc(dstlen);
    assert(dst != NULL /* malloc error */);
  }

  //-- copy
  assert(dstlen > base1-base0 /* buffer overflow */);
  memcpy(dst, base0, base1-base0);
  dst[base1-base0] = '\0';

  return dst;
}
