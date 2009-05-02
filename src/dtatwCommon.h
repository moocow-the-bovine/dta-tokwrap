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
 * Utils: attributes
 */

/*--------------------------------------------------------------
 * val = get_attr(name, attrs)
 */
static inline
const XML_Char *get_attr(const XML_Char *aname, const XML_Char **attrs)
{
  int i;
  for (i=0; attrs[i]; i += 2) {
    if (strcmp(aname,attrs[i])==0) return attrs[i+1];
  }
  return NULL;
}

/*======================================================================
 * Utils: context
 */

/*--------------------------------------------------------------
 * get_error_context()
 *  + gets expat error context, with a surrounding window of ctx_want bytes
 */
static inline
const char *get_error_context(XML_Parser xp, int ctx_want, int *offset, int *len)
{
  int ctx_offset, ctx_size;
  const char *ctx_buf = XML_GetInputContext(xp, &ctx_offset, &ctx_size);
  int ctx_mystart, ctx_myend;
  ctx_mystart = ((ctx_offset <= ctx_want)              ? 0        : (ctx_offset-ctx_want));
  ctx_myend   = ((ctx_size   <= (ctx_offset+ctx_want)) ? ctx_size : (ctx_offset+ctx_want));
  *offset = ctx_offset - ctx_mystart;
  *len    = ctx_myend - ctx_mystart;
  return ctx_buf + ctx_mystart;
}

/*--------------------------------------------------------------
 * get_event_context()
 *  + gets current event context (analagous to perl XML::Parser::original_string())
 */
static inline
const char *get_event_context(XML_Parser xp, int *len)
{
  int ctx_offset, ctx_size;
  const char *ctx_buf = XML_GetInputContext(xp, &ctx_offset, &ctx_size);
  int cur_size = XML_GetCurrentByteCount(xp);
  assert(ctx_offset >= 0);
  assert(ctx_offset+cur_size <= ctx_size);
  *len = cur_size;
  return ctx_buf + ctx_offset;
}

/*======================================================================
 * Utils: XML-escapes
 */

/*--------------------------------------------------------------
 * put_escaped_char(f,c)
 */
static inline
void put_escaped_char(FILE *f_out, XML_Char c)
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
void put_escaped_str(FILE *f, const XML_Char *str, int len)
{
  int i;
  for (i=0; str[i] && (len < 0 || i < len); i++) {
    put_escaped_char(f,str[i]);
  }
}



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

