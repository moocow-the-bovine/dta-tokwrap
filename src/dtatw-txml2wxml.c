#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <ctype.h>
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

#define BUFSIZE     8192 //-- file input buffer size

typedef struct {
  XML_Parser xp;        //-- expat parser
  FILE *f_out;          //-- output file
} ParseData;

//-- prog: default name of this program (used for error reporting, set from argv[0] later)
char *prog = "dtatw-txml2wxml";

//-- indentation/formatting
const char *indent_w = "\n  ";
const char *indent_c = "\n    ";
const char *indent_root = "\n";

#define WANT_T_ATTR 1

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

/*--------------------------------------------------------------
 * get_event_context()
 *  + gets current event context (analagous to perl XML::Parser::original_string())
 */
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


//--------------------------------------------------------------
void put_escaped_char(FILE *f, XML_Char c)
{
  switch (c) {
  case '&': fputs("&amp;", f); break;
  case '"': fputs("&quot;", f); break;
  case '\'': fputs("&apos;", f); break;
  case '>': fputs("&gt;", f); break;
  case '<': fputs("&lt;", f); break;
    //case '\t': fputs("&#9;", f); break;
  case '\n': fputs("&#10;", f); break;
  case '\r': fputs("&#13;", f); break;
  default: fputc(c, f); break;
  }
}

//--------------------------------------------------------------
void put_escaped_str(FILE *f, const XML_Char *str, int len)
{
  int i;
  for (i=0; str[i] && (len < 0 || i < len); i++) {
    put_escaped_char(f,str[i]);
  }
}

/*======================================================================
 * Handlers
 */

//--------------------------------------------------------------
void cb_start(ParseData *data, const XML_Char *name, const XML_Char **attrs)
{
  int i;
  const XML_Char *xml_id=NULL, *ca=NULL,*c_begin,*c_end, *ta=NULL;
  if (strcmp(name,"w")!=0) return;
  fprintf(data->f_out, "%s<w", indent_w);
  for (i=0; attrs[i] && (!xml_id || !ca || !ta); i += 2) {
    if      (strcmp(attrs[i],"xml:id")==0) xml_id=attrs[i+1];
    else if (strcmp(attrs[i],"c")==0)          ca=attrs[i+1];
#ifdef WANT_T_ATTR
    else if (strcmp(attrs[i],"t")==0)          ta=attrs[i+1];
#endif
  }
  if (xml_id) {
    fputs(" xml:id=\"", data->f_out);
    put_escaped_str(data->f_out, xml_id, -1);
    fputc('"', data->f_out);
  }
#ifdef WANT_T_ATTR
  if (ta) {
    fputs(" t=\"", data->f_out);
    put_escaped_str(data->f_out, ta, -1);
    fputc('"', data->f_out);
  }
#endif
  fputc('>', data->f_out);
  if (ca) {
    for (c_begin=ca; *c_begin; c_begin=c_end) {
      for ( ; *c_begin && isspace(*c_begin); c_begin++) {
	;
      }
      for (c_end=c_begin; *c_end && !isspace(*c_end); c_end++) {
	;
      }
      if (*c_begin && c_end > c_begin) {
	fputs(indent_c,data->f_out);
	fputs("<c ref=\"#", data->f_out);
	put_escaped_str(data->f_out, c_begin, c_end-c_begin);
	fputs("\"/>", data->f_out);
      }
    }
  }
  fputs(indent_w, data->f_out);
  fputs("</w>", data->f_out);
}

//--------------------------------------------------------------
void cb_end(ParseData *data, const XML_Char *name)
{
  return;
}

/*======================================================================
 * MAIN
 */
int main(int argc, char **argv)
{
  ParseData data;
  XML_Parser xp;
  void *buf;
  int  isFinal = 0;
  char *filename_in  = "-";
  char *filename_out = "-";
  char *xmlbase = NULL;
  FILE *f_in  = stdin;   //-- input file
  FILE *f_out = stdout;  //-- output file

  //-- initialize: globals
  prog = argv[0];

  //-- command-line: usage
  if (argc <= 1) {
    fprintf(stderr, "Usage: %s INFILE [OUTFILE [XMLBASE]]\n", prog);
    fprintf(stderr, " + INFILE  : XML-ified tokenizer output file\n");
    fprintf(stderr, " + OUTFILE : standoff token file\n");
    exit(1);
  }
  //-- command-line: input file
  if (argc > 1) {
    filename_in = argv[1];
    if ( strcmp(filename_in,"-")!=0 && !(f_in=fopen(filename_in,"rb")) ) {
      fprintf(stderr, "%s: open failed for input file `%s': %s\n", prog, filename_in, strerror(errno));
      exit(1);
    }
  }
  //-- command-line: output file
  if (argc > 2) {
    filename_out = argv[2];
    if (strcmp(filename_out,"")==0) {
      f_out = NULL;
    }
    else if ( strcmp(filename_out,"-")==0 ) {
      f_out = stdout;
    }
    else if ( !(f_out=fopen(filename_out,"wb")) ) {
      fprintf(stderr, "%s: open failed for output file `%s': %s\n", prog, filename_out, strerror(errno));
      exit(1);
    }
  }
  if (argc > 3) {
    xmlbase = argv[3];
  } else {
    xmlbase = filename_in;
  }

  //-- setup expat parser
  xp = XML_ParserCreate("UTF-8");
  if (!xp) {
    fprintf(stderr, "%s: XML_ParserCreate failed", prog);
    exit(1);
  }
  XML_SetUserData(xp, &data);
  XML_SetElementHandler(xp, (XML_StartElementHandler)cb_start, (XML_EndElementHandler)cb_end);

  //-- setup callback data
  memset(&data,0,sizeof(data));
  data.xp    = xp;
  data.f_out = f_out;

  //-- print header
  fprintf(f_out,
	  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
	  "<tokens xml:base=\"%s\">",
	  (xmlbase ? xmlbase : "")
	  );

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

    //-- check for file errors
    isFinal = feof(f_in);
    if (ferror(f_in) && !isFinal) {
      fprintf(stderr, "%s: `%s' (line %d, col %d, byte %ld): I/O error: %s\n",
	      prog, filename_in,
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
	      prog, filename_in,
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

  //-- print footer
  fprintf(f_out, "%s</tokens>\n", indent_root);

  //-- cleanup
  if (f_in)  fclose(f_in);
  if (f_out) fclose(f_out);
  if (xp) XML_ParserFree(xp);

  return 0;
}
