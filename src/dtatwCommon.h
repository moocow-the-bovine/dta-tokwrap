/*
 * File: dtatwCommon.h
 * Author: Bryan Jurish <jurish@bbaw.de>
 * Description: DTA tokenizer wrappers: C utilities: common definitions: headers
 */

#ifndef DTATW_COMMON_H
#define DTATW_COMMON_H

#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <ctype.h>
#include <time.h>

#undef XML_DTD
#undef XML_NS
#undef XML_UNICODE
#undef XML_UNICODE_WHAT_T
#define XML_CONTEXT_BYTES 1024
#include <expat.h>

/*======================================================================
 * Globals
 */

#define FILE_BUFSIZE 8192 //-- file input buffer size
typedef long unsigned int ByteOffset;
typedef int ByteLen;

extern char *prog;

//-- CX_NIL_ID: pseudo-id used for missing xml:id attributes on <c> elements
extern char *CX_NIL_ID; //-- default: "-"

//-- CX_LB_ID : pseudo-ID for <lb/> records
extern char *CX_LB_ID; //-- default: "$LB$"

/*======================================================================
 * Debug
 */

//-- ENABLE_ASSERT : if defined, debugging assertions will be enabled
#define ENABLE_ASSERT 1
//#undef ENABLE_ASSERT

#if !defined(assert)
# if defined(ENABLE_ASSERT)
#  define assert(test) if (!(test)) { fprintf(stderr, "%s: %s:%d: assertion failed: (%s)\n", prog, __FILE__, __LINE__, #test); exit(255); }
# else  /* defined(ENABLE_ASSERT) -> false */
#  define assert(test) 
# endif /* defined(ENABLE_ASSERT) */
#endif /* !defined(assert) */

/*======================================================================
 * Utils: XML-escapes
 */

/*--------------------------------------------------------------
 * put_escaped_char(f,c)
 */
static inline
//void put_escaped_char(FILE *f_out, XML_Char c)
void put_escaped_char(FILE *f_out, char c)
{
  switch (c) {
  case '&': fputs("&amp;", f_out); break;
  case '"': fputs("&quot;", f_out); break;
  case '\'': fputs("&apos;", f_out); break;
  case '>': fputs("&gt;", f_out); break;
  case '<': fputs("&lt;", f_out); break;
    //case '\t': fputs("&#9;", f_out); break;
  case '\n': fputs("&#10;", f_out); break;
  case '\r': fputs("&#13;", f_out); break;
  default: fputc(c, f_out); break;
  }
}

/*--------------------------------------------------------------
 * put_escaped_str(f,str,len)
 */
static inline
//void put_escaped_str(FILE *f, const XML_Char *str, int len)
void put_escaped_str(FILE *f, const char *str, int len)
{
  int i;
  for (i=0; str[i] && (len < 0 || i < len); i++) {
    put_escaped_char(f,str[i]);
  }
}

/*======================================================================
 * Utils: basename
 */

/*--------------------------------------------------------------
 * file_basename(dst, src, suff, srclen, dstlen)
 *  + removes leading directories (if any) and suffix 'suff' from 'src', writing result to 'dst'
 *  + returns 'dst', allocating if it is passed as a NULL pointer
 *    - if 'dst' is non-NULL, 'dstlen' should contain the allocated length of 'dst'
 *    - otherwise, if 'dst' is NULL, 'dstlen' should be <=0 (basename only) or number of additional bytes to allocate
 */
extern char *file_basename(char *dst, const char *src, const char *suff, int srclen, int dstlen);

/*======================================================================
 * Utils: si
 */

/*--------------------------------------------------------------
 * g = si_g(f)
 */
static inline
double si_val(double g)
{
  if (g >= 1e12) return g / 1e12;
  if (g >= 1e9) return g / 1e9;
  if (g >= 1e6) return g / 1e6;
  if (g >= 1e3) return g / 1e3;
  return g;
}

static inline
const char *si_suffix(double g)
{
  if (g >= 1e12) return "T";
  if (g >= 1e9) return "G";
  if (g >= 1e6) return "M";
  if (g >= 1e3) return "K";
  return "";
}

/*======================================================================
 * Utils: File Parsing
 */
//-- n_xmlbytes_read = expat_parse_file(xp,f)
//   + exit()s on error
ByteOffset expat_parse_file(XML_Parser xp, FILE *f_in, const char *filename_in);


#endif /* DTATW_COMMON_H */

