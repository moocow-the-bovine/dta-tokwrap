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

//-- ENABLE_ASSERT : if defined, debugging assertions will be enabled
#define ENABLE_ASSERT 1
//#undef ENABLE_ASSERT

//-- NIL_ID: string used for missing xml:id attributes on <c> elements
const char *NIL_ID = "-";

//-- START_ID : pseudo-ID for START records
const char *START_ID = "$START$";

//-- ATTR_ID : pseudo-ID for ATTR records
const char *ATTR_ID = "$ATTR$";

//-- END_ID : pseudo-ID for END records
const char *END_ID = "$END$";

#define BUFSIZE     8192 //-- file input buffer size
#define CTBUFSIZE    256 //-- <c>-local text buffer size
#define CIDBUFSIZE   256 //-- <c>-local xml:id buffer size

typedef long unsigned int ByteOffset;
typedef int ByteLen;

typedef struct {
  XML_Parser xp;        //-- expat parser
  FILE *f_ix;          //-- output index file
  FILE *f_tx;          //-- output text file
  int text_depth;       //-- boolean: number of open 'text' elements
  ByteOffset n_chrs;    //-- number of <c> elements read
  int is_c;             //-- boolean: true if currently parsing a 'c' elt
  XML_Char c_tbuf[CTBUFSIZE]; //-- text buffer for current <c>
  int c_tlen;                 //-- byte length of text in character buffer c_tbuf[]
  XML_Char c_id[CIDBUFSIZE];  //-- xml:id of current <c>
  ByteOffset c_xoffset; //-- byte offset in XML stream at which current <c> started
  ByteOffset c_toffset; //-- byte offset in text stream at which current <c> started
} TokWrapData;

//-- prog: default name of this program (used for error reporting, set from argv[0] later)
char *prog = "dta-tokwrap-textindex";

//-- want_profile: if true, some profiling information will be printed to stderr
int want_profile = 1;

//-- want_outfile_comments: if true, some explanatory comments will be printed to the output file
int want_outfile_comments = 1;

//-- want_outfile_format_colnames: if true, column names will be printed as the first record
// + column names will be commented if want_outfile_comments is true as well
int want_outfile_colnames = 1;

/*======================================================================
 * Debug
 */

#if !defined(assert)
# if defined(ENABLE_ASSERT)
#  define assert(test) if (!(test)) { fprintf(stderr, "%s: %s:%d: assertion failed: (%s)\n", prog, __FILE__, __LINE__, #test); exit(255); }
# else  /* defined(ENABLE_ASSERT) -> false */
#  define assert(test) 
# endif /* defined(ENABLE_ASSERT) */
#endif /* !defined(assert) */

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
void put_raw_text(TokWrapData *data, int tlen, const char *txt)
{
  if (data->f_tx) fwrite(txt, 1,tlen, data->f_tx);
  data->c_toffset += tlen;
}

//--------------------------------------------------------------
void put_record_raw(FILE *f, const char *id, ByteOffset xoffset, int xlen, ByteOffset toffset, int tlen, const char *txt)
{
  if (!f) return;
  fprintf(f, "%s\t%lu\t%d\t%lu\t%d\t%s\n", id, xoffset, xlen, toffset, (tlen < 0 ? 0 : tlen), index_text(txt,tlen));
}

//--------------------------------------------------------------
void put_record_start(TokWrapData *data, const XML_Char *name, const XML_Char **attrs)
{
  int ai;
  long xoffset = XML_GetCurrentByteIndex(data->xp);
  int  xlen    = XML_GetCurrentByteCount(data->xp);
  put_record_raw(data->f_ix, START_ID, xoffset,xlen, data->c_toffset,-1, name);
  for (ai=0; attrs[ai]; ai++) {
    put_record_raw(data->f_ix, ATTR_ID, xoffset,xlen, data->c_toffset,-1, attrs[ai]);
  }
}

//--------------------------------------------------------------
void put_record_end(TokWrapData *data, const XML_Char *name)
{
  put_record_raw(data->f_ix, END_ID, XML_GetCurrentByteIndex(data->xp),XML_GetCurrentByteCount(data->xp), data->c_toffset,-1, name);
  if (strcmp(name,"lb")==0) put_raw_text(data, 1, "\n");
}

//--------------------------------------------------------------
void put_record_char(TokWrapData *data)
{
  ByteOffset c_xlen = XML_GetCurrentByteIndex(data->xp) + XML_GetCurrentByteCount(data->xp) - data->c_xoffset;
  put_record_raw(data->f_ix,
		 data->c_id,
		 data->c_xoffset, c_xlen,
		 data->c_toffset, data->c_tlen,
		 data->c_tbuf
		 );
  put_raw_text(data, data->c_tlen, data->c_tbuf);
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
      assert(strlen(id) < CIDBUFSIZE);
      strcpy(data->c_id,id);
    } else {
      assert(strlen(NIL_ID) < CIDBUFSIZE);
      strcpy(data->c_id,NIL_ID);
    }
    data->c_xoffset = XML_GetCurrentByteIndex(data->xp);
    data->c_tlen    = 0;
    data->is_c      = 1;
    data->n_chrs++;
    return;
  }
  if (strcmp(name,"text")==0) {
    data->text_depth++;
  }
  put_record_start(data,name,attrs);
}

//--------------------------------------------------------------
void cb_end(TokWrapData *data, const XML_Char *name)
{
  if (strcmp(name,"c")==0) {
    put_record_char(data);  //-- output: index record + raw text
    data->is_c = 0;         //-- ... and leave <c>-parsing mode
    return;
  }
  if (strcmp(name,"text")==0) {
    data->text_depth--;
  }
  put_record_end(data,name);
}

//--------------------------------------------------------------
void cb_char(TokWrapData *data, const XML_Char *s, int len)
{
  if (data->is_c) {
    assert(data->c_tlen + len < CTBUFSIZE);
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
  char *infilename = "-";
  char *ixfilename = "-";
  char *txfilename = NULL;
  FILE *f_in = stdin;   //-- input file
  FILE *f_ix = NULL;    //-- output index file (NULL for none)
  FILE *f_tx = NULL;    //-- output text file (NULL for none)
  //
  //-- profiling
  double elapsed = 0;
  ByteOffset n_xbytes = 0;

  //-- initialize: globals
  prog = argv[0];

  //-- command-line: usage
  if (argc <= 1) {
    fprintf(stderr, "Usage: %s INFILE [IXFILE [TXFILE]]\n", prog);
    fprintf(stderr, " + INFILE : XML source file with <c> elements\n");
    fprintf(stderr, " + IXFILE : output index file, TAB-separated; default=stdout\n");
    fprintf(stderr, " + TXFILE : output raw text file; default=none\n");
    exit(1);
  }
  //-- command-line: input file
  if (argc > 1) {
    infilename = argv[1];
    if ( strcmp(infilename,"-")!=0 && !(f_in=fopen(infilename,"rb")) ) {
      fprintf(stderr, "%s: open failed for input file `%s': %s\n", prog, infilename, strerror(errno));
      exit(1);
    }
  }
  //-- command-line: output index file
  if (argc > 2) {
    ixfilename = argv[2];
    if (strcmp(ixfilename,"")==0) {
      f_ix = NULL;
    }
    else if ( strcmp(ixfilename,"-")==0 ) {
      f_ix = stdout;
    }
    else if ( !(f_ix=fopen(ixfilename,"wb")) ) {
      fprintf(stderr, "%s: open failed for output index file `%s': %s\n", prog, ixfilename, strerror(errno));
      exit(1);
    }
  }
  //-- command-line: output text file
  if (argc > 3) {
    txfilename = argv[3];
    if (strcmp(txfilename,"")==0) {
      f_tx = NULL;
    }
    else if ( strcmp(txfilename,"-")==0 ) {
      f_tx = stdout;
    }
    else if ( !(f_tx=fopen(txfilename,"wb")) ) {
      fprintf(stderr, "%s: open failed for output text file `%s': %s\n", prog, txfilename, strerror(errno));
      exit(1);
    }
  }

  //-- print output header
  if (f_ix && want_outfile_comments) {
    int i;
    fprintf(f_ix, "%%%% XML event list file generated by %s\n", prog);
    fprintf(f_ix, "%%%% Command-line: %s", argv[0]);
    for (i=1; i < argc; i++) { fprintf(f_ix," '%s'", argv[i]); }
    fputc('\n', f_ix);
    fprintf(f_ix, "%%%%======================================================================\n");
  }
  if (f_ix && want_outfile_colnames) {
    fprintf(f_ix, "%s$ID$\t$XML_OFFSET$\t$XML_LENGTH$\t$TXT_OFFSET$\t$TXT_LEN$\t$TEXT$\n", (want_outfile_comments ? "%% " : ""));
  }

  //-- setup expat parser
  xp = XML_ParserCreate("UTF-8");
  if (!xp) {
    fprintf(stderr, "%s: XML_ParserCreate failed", prog);
    exit(1);
  }
  XML_SetUserData(xp, &data);
  XML_SetElementHandler(xp, (XML_StartElementHandler)cb_start, (XML_EndElementHandler)cb_end);
  XML_SetCharacterDataHandler(xp, (XML_CharacterDataHandler)cb_char);

  //-- setup callback data
  memset(&data,0,sizeof(data));
  data.xp   = xp;
  data.f_ix = f_ix;
  data.f_tx = f_tx;

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
    nread = fread(buf, 1,BUFSIZE, f_in);
    n_xbytes += nread;

    //-- check for file errors
    isFinal = feof(f_in);
    if (ferror(f_in) && !isFinal) {
      fprintf(stderr, "%s: `%s' (line %d, col %d, byte %ld): I/O error: %s\n",
	      prog, infilename,
	      XML_GetCurrentLineNumber(xp), XML_GetCurrentColumnNumber(xp), XML_GetCurrentByteIndex(xp),
	      strerror(errno));
      exit(1);
    }

    status = XML_ParseBuffer(xp, (int)nread, isFinal);

    //-- check for expat errors
    if (status != XML_STATUS_OK) {
      int ctx_offset = 0, ctx_len = 0;
      const char *ctx_buf;
      fprintf(stderr, "%s: `%s' (line %d, col %d, byte %ld): XML error: %s\n",
	      prog, infilename,
	      XML_GetCurrentLineNumber(xp), XML_GetCurrentColumnNumber(xp), XML_GetCurrentByteIndex(xp),
	      XML_ErrorString(XML_GetErrorCode(xp)));

      ctx_buf = get_error_context(xp, 64, &ctx_offset, &ctx_len);
      fprintf(stderr, "%s: Error Context:\n%.*s%s%.*s\n",
	      prog,
	      ctx_offset, ctx_buf,
	      "\n---HERE---\n",
	      (ctx_len-ctx_offset), ctx_buf+ctx_offset);
      exit(2);
    }
  } while (!isFinal);

  //-- always terminate text file with a newline
  if (f_tx) fputc('\n',f_tx);

  //-- profiling
  if (want_profile) {
    elapsed = ((double)clock()) / ((double)CLOCKS_PER_SEC);
    if (elapsed <= 0) elapsed = 1e-5;
    fprintf(stderr, "%s: %.2f%s XML chars ~ %.2f%s XML bytes in %.2f sec: %.2f %schar/sec ~ %.2f %sbyte/sec\n",
	    prog,
	    si_val(data.n_chrs),si_suffix(data.n_chrs),
	    si_val(n_xbytes),si_suffix(n_xbytes),
	    elapsed, 
	    si_val(data.n_chrs/elapsed),si_suffix(data.n_chrs/elapsed),
	    si_val(n_xbytes/elapsed),si_suffix(n_xbytes/elapsed));
  }

  //-- cleanup
  if (f_in) fclose(f_in);
  if (f_ix) fclose(f_ix);
  if (f_tx) fclose(f_tx);
  if (xp) XML_ParserFree(xp);

  return 0;
}
