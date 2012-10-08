/*
 * File: dtatwCommon.h
 * Author: Bryan Jurish <configure.ac>
 * Description: DTA tokenizer wrappers: C utilities: common definitions: headers
 */

#ifndef DTATW_COMMON_H
#define DTATW_COMMON_H

#include "dtatwConfig.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <errno.h>
#include <time.h>

/*======================================================================
 * Globals
 */

#define FILE_BUFSIZE 8192 //-- file input buffer size
typedef long unsigned int ByteOffset;
typedef int ByteLen;

extern char *prog;

//-- CX_NIL_ID: pseudo-id used for missing (xml:)?id attributes on <c> elements
extern char *CX_NIL_ID; //-- default: "-"

//-- CX_LB_ID : pseudo-ID for <lb/> records
extern char *CX_LB_ID; //-- default: "$LB$"

//-- CX_PB_ID : pseudo-ID for <pb/> records
extern char *CX_PB_ID; //-- default: "$PB$"

//-- CX_FORMULA_ID : pseudo-ID format for <formula/> records (given original byte offset)
#define CX_FORMULA_PREFIX "$FORMULA:"
extern char *CX_FORMULA_ID; //-- default: CX_FORMULA_PREFIX ":%lu$"

//-- CX_FORMULA_TEXT : text inserted for <formula/> records
extern char *CX_FORMULA_TEXT; //-- default: " FORMULA "

//-- xmlid_attr : output attribute for (xml:)?id attributes (default="id")
extern char *xmlid_name; 

/*======================================================================
 * utf8 stuff
 */

/** \brief typedef for unicode codepoints */
typedef unsigned int ucs4;

/** \brief useful alias */
#ifndef uint
#define uint unsigned int
#endif

/** \brief useful alias */
#ifndef uchar
# define uchar unsigned char
#endif

/** \brief utf8.h wants this */
#ifndef u_int32_t
# define u_int32_t ucs4
#endif


/*======================================================================
 * Debug
 */

//-- ENABLE_ASSERT : if defined, debugging assertions will be enabled
#define ENABLE_ASSERT 1
//#undef ENABLE_ASSERT

#if !defined(assert)
# if defined(ENABLE_ASSERT)
#  define assert2(test,label) \
     if (!(test)) { \
       fprintf(stderr, "%s: %s:%d: assertion failed: (%s): %s\n", prog, __FILE__, __LINE__, #test, (label)); \
       exit(255); \
     }
#  define assert(test) \
     if (!(test)) { \
       fprintf(stderr, "%s: %s:%d: assertion failed: (%s)\n", prog, __FILE__, __LINE__, #test); \
       exit(255); \
     }
# else  /* defined(ENABLE_ASSERT) -> false */
#  define assert(test)
#  define assert2(test,label)
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
 * Utils: TAB-separated string parsing
 */

//--------------------------------------------------------------
// next_tab()
//  + returns char* to next '\t', '\n', or '\0' in s
inline static char *next_tab(char *s)
{
  for (; *s && *s!='\t' && *s!='\n'; s++) ;
  return s;
}

//--------------------------------------------------------------
// next_tab_z()
//  + returns char* to position of next '\t', '\n', or '\0' in s
//  + sets the character to '\0', so returned string always looks like ""
inline static char *next_tab_z(char *s)
{
  for (; *s && *s!='\t' && *s!='\n'; s++) ;
  *s = '\0';
  return s;
}

//--------------------------------------------------------------
// next_char_z()
//  + returns char* to position of next character c or '\0' in s
//  + sets the matching character to '\0', so returned string always looks like ""
inline static char *next_char_z(char *s, char c)
{
  for (; *s && *s != c; s++) ;
  *s = '\0';
  return s;
}

/*======================================================================
 * Utils: slurp
 */

// size = file_size(f)
//  + get file size; uses fstat()
off_t file_size(FILE *f);

// slurp_file()
//  + slurp file contents into buf
//  + if buflen is zero, *bufp will be a newly allocated buffer
//    which on return contains all the (remaining) bytes of the file
//  + if buflen is nonzero, *bufp should have that many bytes allocated,
//    and only that many bytes will be slurped
//  + return value is number of bytes actually slurped
size_t file_slurp(FILE *f, char **bufp, size_t buflen);

/*======================================================================
 * Utils: .cx file(s)
 */

// CX_HAVE_PB : whether to parse 'pb' field in cxRecord
//#define CX_HAVE_PB 1

// CX_WANT_TEXT : whether to include (and parse) 'text' field in cxRecord
#define CX_WANT_TEXT 1

// cxRecord : struct for character-index records as loaded from .cx file
typedef struct {
  char        *id;      //-- (xml:)?id of source <c>
  ByteOffset xoff;      //-- original xml byte offset
  ByteLen    xlen;      //-- original xml byte length
  ByteOffset toff;      //-- .tx byte offset
  ByteLen    tlen;      //-- .tx byte length
#ifdef CX_HAVE_PB
  int          pb;      //-- preceding::pb[1]/@facs (trimmed)
#endif
#ifdef CX_WANT_TEXT
  char      *text;      //-- output text (un-escaped)
#endif
  struct bxRecord_t *bxp; //-- pointer to .bx-record (block) containing this <c>, if available
  unsigned char claimed;	//-- claimed (0:unclaimed, 1: claimed by current word, >1: claimed by other word)
} cxRecord;

// cxData : array of .cx records
typedef struct {
  cxRecord   *data;              //-- vector of cx records
  ByteOffset  len;               //-- number of used cx records (index of 1st unused record)
  ByteOffset  alloc;             //-- number of allocated cx records
} cxData;

// CXDATA_DEFAULT_ALLOC : default original buffer size for cxData.data, in number of records
#ifndef CXDATA_DEFAULT_ALLOC
# define CXDATA_DEFAULT_ALLOC 8192
#endif

cxData   *cxDataInit(cxData *cxd, size_t size); //-- initializes/allocates *cxd
cxRecord *cxDataPush(cxData *cxd, cxRecord *cx);    //-- append *cx to *cxd->data, re-allocating if required
cxData   *cxDataLoad(cxData *cx, FILE *f);          //-- loads *cxd from file f
char *cx_text_string(char *src, int src_len);       //-- un-escapes cx-file "text" string to a new string (returned)

/*======================================================================
 * Utils: .bx file(s)
 */

// bxRecord : struct for block-index records as loaded from .bx file
typedef struct bxRecord_t {
  char *key;        //-- sort key
  char *elt;        //-- element name
  ByteOffset xoff;  //-- xml byte offset
  ByteOffset xlen;  //-- xml byte length
  ByteOffset toff;  //-- tx byte offset
  ByteOffset tlen;  //-- tx byte length
  ByteOffset otoff; //-- txt byte offset
  ByteOffset otlen; //-- txt byte length
} bxRecord;

// bxData : array of .bx records
typedef struct {
  bxRecord   *data;              //-- vector of bx records
  ByteOffset  alloc;             //-- number of allocated bx records
  ByteOffset  len;               //-- number of used bx records (index of 1st unused record)
} bxData;

// BXDATA_DEFAULT_ALLOC : default buffer size for bxdata[], in number of records
#ifndef BXDATA_DEFAULT_ALLOC
# define BXDATA_DEFAULT_ALLOC 1024
#endif

bxData   *bxDataInit(bxData *bxd, size_t size);   //-- initialize/allocate bxdata
bxRecord *bxDataPush(bxData *bxd, bxRecord *bx);      //-- append *bx to *bxd, re-allocating if required
bxData   *bxDataLoad(bxData *bxd, FILE *f);           //-- loads *bxd from file f


/*======================================================================
 * Utils: .cx + .bx indexing
 */

typedef struct {
  cxRecord **data;     //-- cxRecord_ptr = data[byte_index]
  ByteOffset  len;     //-- number of allocated&used positions in data
} Offset2CxIndex;

// tx2cxIndex(): init/alloc: cxRecord *cx =  txo2cx->data[ tx_byte_index]
Offset2CxIndex  *tx2cxIndex(Offset2CxIndex *txo2cx,  cxData *cxd);

// txt2cxIndex(): init/alloc: cxRecord *cx = txto2cx->data[txt_byte_index]
Offset2CxIndex *txt2cxIndex(Offset2CxIndex *txto2cx, bxData *bxd, Offset2CxIndex *txb2cx);

// cx2bxIndex(): init/alloc: bxRecord *bx = cx2bx[cx_index]  :: UNUSED (?!)
bxRecord **cx2bxIndex(cxData *cxd, bxData *bxd, Offset2CxIndex *tx2cx);

// cx_is_adjacent(): check whether cx1 immediately follows cx2
int cx_is_adjacent(const cxRecord *cx1, const cxRecord *cx2);

#endif /* DTATW_COMMON_H */
