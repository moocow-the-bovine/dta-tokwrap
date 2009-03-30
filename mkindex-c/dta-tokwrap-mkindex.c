#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <time.h>

#undef XML_DTD
#undef XML_NS
#undef XML_UNICODE
#undef XML_UNICODE_WHAT_T
#include <expat.h>

/*======================================================================
 * Globals
 */

//-- NIL_ID: string used for missing xml:id attributes on <c> elements
const char *NIL_ID = "-";

//-- START_ID : pseudo-ID for START records (see WATCH_ELTS[])
const char *START_ID = "$START$";

//-- ATTR_ID : pseudo-ID for ATTR records (see WATCH_ELTS[])
const char *ATTR_ID = "$ATTR$";

//-- END_ID : pseudo-ID for END records (see WATCH_ELTS[])
const char *END_ID = "$END$";

//-- WATCH_ELTS : START, ATTR and END records will be written for these
const char *WATCH_ELTS[] =
  {
    "lb",
    "hi",
    "p",
    "pb",
    "table",
    "row",
    "cell",
    "item",
    "note",
    "list",
    "div",
    "head",
    "ref",
    "fw",
    "g",
    "figure",
    "front",
    "body",
    "back",
    /*... more here ...*/
    NULL //-- EOL sentinel
  };

#define BUFSIZE     8192 //-- file input buffer size
#define CTBUFSIZE    256 //-- <c>-local text buffer size
#define CIDBUFSIZE   256 //-- <c>-local xml:id buffer size

typedef long unsigned int ByteOffset;
typedef int ByteLen;

typedef struct {
  XML_Parser xp;        //-- expat parser
  FILE *fidx;           //-- output index file
  int text_depth;       //-- boolean: number of open 'text' elements
  ByteOffset n_chrs;    //-- number of <c> elements read
  int is_c;             //-- boolean: true if currently parsing a 'c' elt
  XML_Char c_tbuf[CTBUFSIZE]; //-- text buffer for current <c>
  int c_tlen;                 //-- byte length of text in character buffer c_tbuf[]
  XML_Char c_id[CIDBUFSIZE];  //-- xml:id of current <c>
  ByteOffset c_xoffset; //-- byte offset in XML stream at which current <c> started
} TokWrapData;

char *prog = "dta-tokwrap-mkindex";

/*======================================================================
 * Utils
 */

//--------------------------------------------------------------
const XML_Char *get_attr(const XML_Char *aname, const XML_Char **attrs)
{
  int i;
  for (i=0; attrs[i]; i += 2) {
    if (strcmp(aname,attrs[i])==0) return attrs[i+1];
  }
  return NULL;
}

/*--------------------------------------------------------------
 * index_text()
 *  + escape text for printing in index
 */
char index_txtbuf[CTBUFSIZE];
char *index_text(const char *buf, int len)
{
  int i,j;
  char *out = index_txtbuf;
  for (i=0,j=0; (len < 0 || i < len) && buf[i]; i++) {
    switch (buf[i]) {
    case '\\':
      out[j++] = '\\';
      out[j++] = '\\';
      break;
    case '\t':
      out[j++] = '\\';
      out[j++] = 't';
      break;
    case '\n':
      out[j++] = '\\';
      out[j++] = 'n';
      break;
    default:
      out[j++] = buf[i];
      break;
    }
  }
  out[j++] = '\0';
  return out;
}

//--------------------------------------------------------------
void put_record_raw(FILE *f, const char *id, ByteOffset xoffset, int xlen, int tlen, const char *txt)
{
  fprintf(f, "%s\t%lu\t%d\t%s\n", id, xoffset, xlen, index_text(txt,tlen));
}

//--------------------------------------------------------------
#define STARTBUF_LEN 1024
char startbuf[STARTBUF_LEN];
void put_record_watch(TokWrapData *data, const XML_Char *name, const XML_Char **attrs)
{
  if (attrs) {
    int ai;
    long xoffset = XML_GetCurrentByteIndex(data->xp);
    int  xlen    = XML_GetCurrentByteCount(data->xp);
    put_record_raw(data->fidx, START_ID, xoffset,xlen, -1,name);
    for (ai=0; attrs[ai]; ai++) {
      put_record_raw(data->fidx, ATTR_ID, xoffset,xlen, -1,attrs[ai]);
    }
  }
  else {
    //-- END
    put_record_raw(data->fidx, END_ID, XML_GetCurrentByteIndex(data->xp),XML_GetCurrentByteCount(data->xp), -1,name);
  }
}

//--------------------------------------------------------------
void put_record_char(TokWrapData *data)
{
  ByteOffset c_xlen = XML_GetCurrentByteIndex(data->xp) + XML_GetCurrentByteCount(data->xp) - data->c_xoffset;
  put_record_raw(data->fidx,
		 data->c_id,
		 data->c_xoffset, c_xlen,
		 data->c_tlen, data->c_tbuf
		 );
}

/*--------------------------------------------------------------
 * check_watch(data,name,attrs)
 *  + check whether 'name' is being watch; if so, write a pseudo-record
 *  + if *attrs is NULL, a pseudo-END record will be written
 *  + otherwise, a pseudo-START record and pseudo-ATTR records will be written
 */
int check_watch(TokWrapData *data, const XML_Char *name, const XML_Char **attrs)
{
  int i;
  for (i=0; WATCH_ELTS[i]; i++) {
    if (strcmp(name,WATCH_ELTS[i])==0) {
      put_record_watch(data,name,attrs);
      return 1;
    }
  }
  return 0;
}

/*--------------------------------------------------------------
 * get_error_context()
 *  + gets error context
 */
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
 * g = si_g(f)
 */

double si_val(double g)
{
  if (g >= 1e12) return g / 1e12;
  if (g >= 1e9) return g / 1e9;
  if (g >= 1e6) return g / 1e6;
  if (g >= 1e3) return g / 1e3;
  return g;
}

const char *si_suffix(double g)
{
  if (g >= 1e12) return "T";
  if (g >= 1e9) return "G";
  if (g >= 1e6) return "M";
  if (g >= 1e3) return "K";
  return "";
}



/*======================================================================
 * Handlers
 */

//--------------------------------------------------------------
void cb_start(TokWrapData *data, const XML_Char *name, const XML_Char **attrs)
{
  if (data->text_depth && strcmp(name,"c")==0) {
    const char *id;
    if (data->is_c) {
      fprintf(stderr, "%s: cannot handle nested <c> elements starting at bytes %lu, %lu\n",
	      prog, data->c_xoffset, XML_GetCurrentByteIndex(data->xp));
      exit(3);
    }
    if ( (id=get_attr("xml:id", attrs)) ) {
      strcpy(data->c_id,id);
    } else {
      strcpy(data->c_id,NIL_ID);
    }
    data->c_xoffset = XML_GetCurrentByteIndex(data->xp);
    data->c_tlen    = 0;
    data->is_c      = 1;
    data->n_chrs++;
    return;
  }
  else if (strcmp(name,"text")==0) {
    data->text_depth++;
  }
  //-- check: token-break on element START
  check_watch(data,name,attrs);
}

//--------------------------------------------------------------
void cb_end(TokWrapData *data, const XML_Char *name)
{
  //fprintf(data->fidx, "END %s\n", name);
  if (strcmp(name,"c")==0) {
    put_record_char(data);  //-- output: index record
    data->is_c = 0;         //-- ... and leave <c>-parsing mode
    return;
  }
  if (strcmp(name,"text")==0) {
    data->text_depth--;
  }
  check_watch(data,name,NULL);
}

//--------------------------------------------------------------
void cb_char(TokWrapData *data, const XML_Char *s, int len)
{
  if (data->is_c) {
    //assert(data->c_tlen + len < CTBUFSIZE);
    memcpy(data->c_tbuf+data->c_tlen, s, len); //-- copy required, else clobbered by nested elts (e.g. <c><g>...</g></c>)
    data->c_tlen += len;
  }
}

/*======================================================================
 * MAIN
 */
int main(int argc, char **argv)
{
  TokWrapData data;
  XML_Parser xp;
  void *buf;
  int  isFinal = 0;
  const char *infilename = "-";
  FILE *in = stdin;
  FILE *fidx = stdout;
  //FILE *ftxt = fopen("out.txt","wb");
  //
  //-- profiling
  double elapsed = 0;
  ByteOffset n_xbytes = 0;

  //-- initialize globals
  prog = argv[0];

  //-- setup expat parser
  xp = XML_ParserCreate("UTF-8");
  XML_SetUserData(xp, &data);
  XML_SetElementHandler(xp, (XML_StartElementHandler)cb_start, (XML_EndElementHandler)cb_end);
  XML_SetCharacterDataHandler(xp, (XML_CharacterDataHandler)cb_char);

  //-- setup callback data
  memset(&data,0,sizeof(data));
  data.xp   = xp;
  data.fidx = fidx;
  //data.ftxt = ftxt;

  //-- parse input file
  do {
    size_t nread;
    int status;

    //-- setup & read into buffer (uses expat functions to avoid double-copy)
    buf = XML_GetBuffer(xp, BUFSIZE);
    if (!buf) {
      fprintf(stderr, "%s: XML_GetBuffer() failed!\n", prog);
      exit(1);
    }
    nread = fread(buf, 1,BUFSIZE, in);
    n_xbytes += nread;

    //-- check for file errors
    isFinal = feof(in);
    if (ferror(in) && !isFinal) {
      fprintf(stderr, "%s: '%s' (line %d, col %d): I/O error: %s\n",
	      prog, infilename,
	      XML_GetCurrentLineNumber(xp), XML_GetCurrentColumnNumber(xp),
	      strerror(errno));
      exit(1);
    }

    status = XML_ParseBuffer(xp, (int)nread, isFinal);

    //-- check for expat errors
    if (status != XML_STATUS_OK) {
      int ctx_offset = 0, ctx_len = 0;
      const char *ctx_buf;
      fprintf(stderr, "%s: '%s' (line %d, col %d, byte %ld): XML error: %s\n",
	      prog, infilename,
	      XML_GetCurrentLineNumber(xp), XML_GetCurrentColumnNumber(xp), XML_GetCurrentByteIndex(xp),
	      XML_ErrorString(XML_GetErrorCode(xp)));

      ctx_buf = get_error_context(xp, 64, &ctx_offset, &ctx_len);
      fprintf(stderr, "%s: Error Context:\n%.*s\n--HERE--\n%.*s\n", prog, ctx_offset, ctx_buf, (ctx_len-ctx_offset), ctx_buf+ctx_offset);
      exit(2);
    }
  } while (!isFinal);

  //-- always terminate text file with a newline
  //fputc('\n', data.ftxt);
  //data.c_toffset++;

  //-- profiling
  elapsed = ((double)clock()) / ((double)CLOCKS_PER_SEC);
  if (elapsed <= 0) elapsed = 1e-5;
  fprintf(stderr, "%s: %.2f%s XML chars ~ %.2f%s XML bytes in %.2f sec: %.2f %schar/sec ~ %.2f %sbyte/sec\n",
	  prog,
	  si_val(data.n_chrs),si_suffix(data.n_chrs),
	  si_val(n_xbytes),si_suffix(n_xbytes),
	  elapsed, 
	  si_val(data.n_chrs/elapsed),si_suffix(data.n_chrs/elapsed),
	  si_val(n_xbytes/elapsed),si_suffix(n_xbytes/elapsed));

  //-- cleanup
  if (in) fclose(in);
  if (fidx) fclose(fidx);
  //if (ftxt) fclose(ftxt);
  if (xp) XML_ParserFree(xp);

  return 0;
}
