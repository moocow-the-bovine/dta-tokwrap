#include "dtatwCommon.h"
#include "dtatwUtf8.h"
#include "dtatwExpat.h"

/*======================================================================
 * Globals
 */

#define CTBUFSIZE    256 //-- buffer size for character-local text data

typedef struct {
  XML_Parser xp;        //-- expat parser
  FILE *f_cx;           //-- output character-index file
  FILE *f_sx;           //-- output structure-index file
  FILE *f_tx;           //-- output text file
  int text_depth;       //-- number of open <text> elements
  int total_depth;      //-- total number of open elements (global depth)
  int c_depth;          //-- total number of open <c> elements (either 0 or 1: nested <c>s are not allowed)
  int is_chardata;      //-- true if current event is character data (used by cb_default)
  ByteOffset n_chrs;    //-- number of logical characters read
  ByteOffset loc_xoff;  //-- last xml-offset written to .sx as location-block (see LOC_FMT, cb_default())
  ByteOffset loc_toff;  //-- last text-offset written to .sx as location-block (see LOC_FMT, cb_default())
  XML_Char c_tbuf[CTBUFSIZE];	//-- text buffer for current character
  int c_tlen;			//-- byte length of text in character buffer c_tbuf[]
  ByteOffset c_xoffset;		//-- byte offset in XML stream at which current <c> started
  ByteOffset c_xlen;		//-- byte length in XML stream of current <c> (currently only used by flush_ws())
  ByteOffset c_toffset;		//-- byte offset in text stream at which current <c> started
  int ws_pending;		//-- have we seen some whitespace?
  uint32_t   cx_attrs[4];	//-- stores bbox for <c> records
} TokWrapData;

//-- want_profile: if true, some profiling information will be printed to stderr
//int want_profile = 1;
int want_profile = 0;

/*======================================================================
 * Debug
 */

/*======================================================================
 * Utils
 */

//--------------------------------------------------------------
void put_raw_text(TokWrapData *data, int tlen, const char *txt)
{
  if (data->f_tx) fwrite(txt, 1,tlen, data->f_tx);
  data->c_toffset += tlen;
}

//--------------------------------------------------------------
cxStoredRecord cxr;       //-- global temporary used by put_record_raw
void put_record_raw(TokWrapData *data, cxRecordType elt, ByteOffset xoffset, int xlen, int tlen, const uint32_t *attrs)
{
  if (!data->f_cx) return;

  cxr.flags = elt;
  if (xoffset != cxr.xoff + cxr.xlen) {
    cxr.flags |= cxfHasXmlOffset;
  }
  cxr.xoff = xoffset;  //-- always set cxr.xoff because we'll use it to check for the NEXT record's cxfHasXmlOffset flag
  cxr.xlen = xlen;
  if (tlen != xlen) {
    cxr.flags |= cxfHasTxtLength;
    cxr.tlen   = tlen;
  }
  if (attrs && attrs[0] != (uint32_t)-1) {
    cxr.flags |= cxfHasAttrs;
    memcpy(cxr.attrs, attrs, 16);
  }
  cx_put_record(data->f_cx, &cxr);
}

//--------------------------------------------------------------
void put_record_char(TokWrapData *data)
{
  ByteOffset c_xlen = XML_GetCurrentByteIndex(data->xp) + XML_GetCurrentByteCount(data->xp) - data->c_xoffset;
  put_record_raw(data,
		 cxrChar,
		 data->c_xoffset, c_xlen,
		 /*data->c_toffset,*/ data->c_tlen,
		 data->cx_attrs
		 );
  put_raw_text(data, data->c_tlen, data->c_tbuf);
  data->c_tlen = 0; //-- reset character-data buffer
}

//--------------------------------------------------------------
void put_record_textchar(TokWrapData *data, ByteOffset xoff, ByteOffset xlen)
{
  put_record_raw(data,
		 cxrChar,
		 xoff, xlen,
		 /*data->c_toffset,*/ data->c_tlen,
		 NULL
		 );
  put_raw_text(data, data->c_tlen, data->c_tbuf);
  data->c_tlen = 0; //-- reset character-data buffer
}

//--------------------------------------------------------------
int is_ws(const XML_Char *s, int len)
{
  int i;
  for (i=0; (len < 0 && *s) || i < len; ++i) {
    if (!isspace(s[i])) return 0;
  }
  return 1;
}

//--------------------------------------------------------------
inline void flush_ws(TokWrapData *data)
{
  if (data->ws_pending) {
    put_record_raw(data,
		   cxrChar,
		   data->c_xoffset, data->c_xlen,
		   /*data->c_toffset,*/ 1,
		   NULL
		   );
    put_raw_text(data, 1, " ");
    data->c_tlen = 0; //-- reset character-data buffer
    data->ws_pending = 0;
  }
}

//--------------------------------------------------------------
void put_record_lb(TokWrapData *data, const XML_Char **attrs)
{
  ByteOffset my_xoff = XML_GetCurrentByteIndex(data->xp);
  ByteOffset my_xlen = XML_GetCurrentByteCount(data->xp);
  put_record_raw(data,
		 cxrLb,
		 my_xoff, my_xlen,
		 /*data->c_toffset,*/ 1,
		 NULL
		 );
  put_raw_text(data, 1, "\n");
}

//--------------------------------------------------------------
void put_record_pb(TokWrapData *data, const XML_Char **attrs)
{
  ByteOffset my_xoff = XML_GetCurrentByteIndex(data->xp);
  ByteOffset my_xlen = XML_GetCurrentByteCount(data->xp);
  const uint32_t *cx_attrs = NULL;

  //-- parse attrs
  memset(data->cx_attrs,0,16);
  for ( ; *attrs; attrs += 2) {
    if (strcmp(attrs[0],"facs")==0) {
      const XML_Char *s = attrs[1];
      if (*s=='#') ++s; 
      if (*s=='f') ++s;
      data->cx_attrs[0] = strtoul(s,NULL,10);
      cx_attrs = data->cx_attrs;
      break;
    }
  }

  put_record_raw(data,
		 cxrPb,
		 my_xoff, my_xlen,
		 /*data->c_toffset,*/ 0,
		 cx_attrs
		 );
  //put_raw_text(data, 1, "\n");
}

//--------------------------------------------------------------
void put_record_formula(TokWrapData *data, const XML_Char **attrs)
{
  ByteOffset my_xoff = XML_GetCurrentByteIndex(data->xp);
  //ByteOffset my_xlen = XML_GetCurrentByteCount(data->xp);
  ByteOffset my_xlen = 0;
  int my_tlen = strlen(CX_FORMULA_TEXT);
  //char formula_id[CIDBUFSIZE];
  //snprintf(formula_id, CIDBUFSIZE, CX_FORMULA_ID, my_xoff);
  put_record_raw(data,
		 cxrFormula,
		 my_xoff, my_xlen,
		 /*data->c_toffset,*/ my_tlen,
		 NULL
		 );
  put_raw_text(data, my_tlen, CX_FORMULA_TEXT);
}


/*======================================================================
 * Handlers
 */

//--------------------------------------------------------------
void cb_start(TokWrapData *data, const XML_Char *name, const XML_Char **attrs)
{
  if (data->text_depth) {

    if (strcmp(name,"c")==0) { // || strcmp(name,"formula")==0
      if (data->c_depth) {
	fprintf(stderr, "%s: cannot handle nested <c> elements starting at bytes %lu, %lu\n",
		prog, data->c_xoffset, XML_GetCurrentByteIndex(data->xp));
	exit(3);
      }
      //-- parse attributes
      memset(data->cx_attrs,0xff,16);
      for ( ; *attrs; attrs += 2) {
	if (strlen(*attrs) != 3) continue;
	switch (attrs[0][0]) {
	case 'l':
	  switch (attrs[0][2]) {
	  case 'x': data->cx_attrs[0] = strtoul(attrs[1],NULL,10); break;
	  case 'y': data->cx_attrs[1] = strtoul(attrs[1],NULL,10); break;
	  default: break;
	  }
	case 'u':
	  switch (attrs[0][2]) {
	  case 'x': data->cx_attrs[2] = strtoul(attrs[1],NULL,10); break;
	  case 'y': data->cx_attrs[3] = strtoul(attrs[1],NULL,10); break;
	  default: break;
	  }
	default: break;
	}
      }
      data->c_xoffset = XML_GetCurrentByteIndex(data->xp);
      data->c_tlen    = 0;
      data->n_chrs++;
      data->total_depth++;
      data->c_depth = 1;
      data->ws_pending = 0;
      return;
    }
    else if (strcmp(name,"lb")==0) {
      put_record_lb(data,attrs);
      data->total_depth++;
      data->ws_pending = 0;
      return;
    }
    else if (strcmp(name,"pb")==0) {
      put_record_pb(data,attrs);
    }
    else if (strcmp(name,"formula")==0) {
      put_record_formula(data,attrs);
      data->ws_pending = 0;
    }
  }
  else if (strcmp(name,"text")==0) {
    data->text_depth++;
    data->ws_pending = 0;
  }
  data->is_chardata = 0;
  XML_DefaultCurrent(data->xp);
  data->total_depth++;
}

//--------------------------------------------------------------
void cb_end(TokWrapData *data, const XML_Char *name)
{
  if (strcmp(name,"c")==0) {
    put_record_char(data);  //-- output: index record + raw text
    data->total_depth--;
    data->c_depth = 0;      //-- ... and leave <c>-parsing mode
    data->ws_pending = 0;
    return;
  }
  else if (strcmp(name,"lb")==0) {
    data->total_depth--;
    data->ws_pending = 0;
    return;
  }
  else if (strcmp(name,"text")==0) {
    data->text_depth--;
    data->ws_pending = 0;
  }
  data->is_chardata = 0;
  XML_DefaultCurrent(data->xp);
  data->total_depth--;
}

//--------------------------------------------------------------
void cb_char(TokWrapData *data, const XML_Char *s, int len)
{
  if (data->c_depth) {
    assert2((data->c_tlen + len < CTBUFSIZE), "<c> text buffer overflow");
    memcpy(data->c_tbuf+data->c_tlen, s, len); //-- copy required, else clobbered by nested elts (e.g. <c><g>...</g></c>)
    data->c_tlen += len;
    data->ws_pending = 0;
    return;
  }
  else if (data->text_depth>0) {
    //-- character data: generate pseudo-elements
    if (is_ws(s,len)) {
      //-- whitespace-only: remember that we saw it
      data->c_xoffset = XML_GetCurrentByteIndex(data->xp);
      data->c_xlen    = XML_GetCurrentByteCount(data->xp);
      data->ws_pending = 1;
    }
    else {
      //-- non-whitespace: parse character data
      int i,j;
      int ctx_len;
      char *ctx = (char*)get_event_context(data->xp,&ctx_len), *tail;
      ByteOffset xoff = XML_GetCurrentByteIndex(data->xp), xlen;
      uint32_t u;
      for (i=0; i < ctx_len; i=j) {
	j=i;

	//-- text: character entity
	if (ctx[i] == '&') {
	  //-- text: character entity: numeric escape
	  if (ctx[i+1]=='#') {
	    if (ctx[i+2]=='x') {
	      u = strtoul((const char*)&ctx[i+3],&tail,16);
	    } else {
	      u = strtoul((const char*)&ctx[i+2],&tail,10);
	    }
	    j = 1+tail-ctx;
	  }
	  //-- text: character entity: built-in
	  else if (i+3 < ctx_len && strncmp(ctx+i+1,"lt;",3)==0) { u='<'; j=i+4; }
	  else if (i+3 < ctx_len && strncmp(ctx+i+1,"gt;",3)==0)  { u='>'; j=i+4; }
	  else if (i+4 < ctx_len && strncmp(ctx+i+1,"amp;",4)==0) { u='&'; j=i+5; }
	  else if (i+5 < ctx_len && strncmp(ctx+i+1,"quot;",5)==0) { u='"'; j=i+6; }
	  else if (i+5 < ctx_len && strncmp(ctx+i+1,"apos;",5)==0) { u='\''; j=i+5; }
	  else {
	    fprintf(stderr, "%s: WARNING: unparsed entity at XML byte %lu\n", prog, data->c_xoffset);
	  }
	}
	if (j==i) {
	  //-- normal text character or fallback
	  u = u8_nextcharn(ctx,len,&j);
	  if (j==i) { j=i+1; } //-- sanity check
	}

	//-- we've got a text character in $ctx[i:j] and its unicode codepoint in $u
	if (u<=0xff && isspace(u)) {
	  data->c_xoffset = xoff+i;
	  data->c_xlen = j-i;
	  data->ws_pending = 1;
	} else {
	  flush_ws(data);
	  u8_wc_toutf8(data->c_tbuf, u);
	  data->c_tlen = u8_wc_len(u);
	  data->c_tbuf[data->c_tlen] = '\0'; //-- nul-terminate
	  put_record_textchar(data, xoff+i, j-i);
	}
      }
      flush_ws(data);
    }
  }
  else {
    //-- character data outside of //text : shunt it to sx
    data->is_chardata = 1;
    XML_DefaultCurrent(data->xp);
  }
}

//--------------------------------------------------------------
//#define TW_DEBUG_LOC
#ifdef TW_DEBUG_LOC
static const char *LOC_FMT_PRE  = "<c type=\"pre\" n=\"%lu %lu %lu %lu\"/>";  //-- xoff xlen toff tlen
static const char *LOC_FMT_POST = "<c type=\"post\" n=\"%lu %lu %lu %lu\"/>"; //-- xoff xlen toff tlen
#else
static const char *LOC_FMT_PRE  = "<c n=\"%lu %lu %lu %lu\"/>"; //-- xoff xlen toff tlen
static const char *LOC_FMT_POST = "<c n=\"%lu %lu %lu %lu\"/>"; //-- xoff xlen toff tlen
#endif

void cb_default(TokWrapData *data, const XML_Char *s, int len)
{
  int ctx_len;
  const XML_Char *ctx = get_event_context(data->xp, &ctx_len);
  ByteOffset     xoff = XML_GetCurrentByteIndex(data->xp);
  if (data->total_depth > 0 && !data->is_chardata && xoff != data->loc_xoff) {
    //-- pre-copy location element (for close-tags)
    ByteOffset xlen = xoff - data->loc_xoff;
    ByteOffset tlen = data->c_toffset + data->c_tlen - data->loc_toff;
    if (data->f_sx) fprintf(data->f_sx, LOC_FMT_PRE, data->loc_xoff, xlen, data->loc_toff, tlen);
    data->loc_xoff = xoff;
    data->loc_toff = data->c_toffset + data->c_tlen;
  }
  if (data->f_sx) {
    //-- copy literal event to sx
    fwrite(ctx, 1,ctx_len, data->f_sx);
  }
  if (data->total_depth > 1 && !data->is_chardata && xoff+ctx_len != data->loc_xoff) {
    //-- post-copy location element (for open-tags)
    ByteOffset xlen = xoff + ctx_len - data->loc_xoff;
    ByteOffset tlen = data->c_toffset + data->c_tlen - data->loc_toff;
    if (data->f_sx) fprintf(data->f_sx, LOC_FMT_POST, data->loc_xoff, xlen, data->loc_toff, tlen);
    data->loc_xoff = xoff + ctx_len;
    data->loc_toff = data->c_toffset + data->c_tlen;
  }
}

/*======================================================================
 * MAIN
 */
int main(int argc, char **argv)
{
  TokWrapData data;
  XML_Parser xp;
  char *filename_in = "-";
  char *filename_cx = "-";
  char *filename_sx = NULL;
  char *filename_tx = NULL;
  FILE *f_in = stdin;   //-- input file
  FILE *f_cx = stdout;  //-- output character-index file (NULL for none)
  FILE *f_sx = NULL;    //-- output structure-index file (NULL for none)
  FILE *f_tx = NULL;    //-- output text file (NULL for none)
  //
  //-- profiling
  double elapsed = 0;
  ByteOffset n_xbytes = 0;

  //-- initialize: globals
  prog = file_basename(NULL,argv[0],"",-1,0);

  //-- sanity checks & defaults
  //assert(strlen(CX_NIL_ID) < CIDBUFSIZE);

  //-- command-line: usage
  if (argc <= 1) {
    fprintf(stderr, "(%s version %s / %s)\n", PACKAGE, PACKAGE_VERSION, PACKAGE_SVNID);
    fprintf(stderr, "Usage:\n");
    fprintf(stderr, " + %s INFILE [CXFILE [SXFILE [TXFILE]]]\n", prog);
    fprintf(stderr, " + INFILE : XML source file with <lb> elements and optional <c> elements\n");
    fprintf(stderr, " + CXFILE : output character-index CSV file; default=stdout\n");
    fprintf(stderr, " + SXFILE : output structure-index XML file; default=none\n");
    fprintf(stderr, " + TXFILE : output raw text-index file (unserialized); default=none\n");
    fprintf(stderr, " + \"-\" may be used in place of any filename to indicate standard (in|out)put\n");
    fprintf(stderr, " + \"\"  may be used in place of any output filename to discard output\n");
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
  //-- command-line: output character-index file
  if (argc > 2) {
    filename_cx = argv[2];
    if (strcmp(filename_cx,"")==0) {
      f_cx = NULL;
    }
    else if ( strcmp(filename_cx,"-")==0 ) {
      f_cx = stdout;
    }
    else if ( !(f_cx=fopen(filename_cx,"wb")) ) {
      fprintf(stderr, "%s: open failed for output character-index file `%s': %s\n", prog, filename_cx, strerror(errno));
      exit(1);
    }
  }
  //-- command-line: output structure-index file
  if (argc > 3) {
    filename_sx = argv[3];
    if (strcmp(filename_sx,"")==0) {
      f_sx = NULL;
    }
    else if ( strcmp(filename_sx,"-")==0 ) {
      f_sx = stdout;
    }
    else if ( strcmp(filename_sx,filename_cx)==0 ) {
      f_sx = f_cx;
    }
    else if ( !(f_sx=fopen(filename_sx,"wb")) ) {
      fprintf(stderr, "%s: open failed for output structure-index file `%s': %s\n", prog, filename_sx, strerror(errno));
      exit(1);
    }
  }
  //-- command-line: output text file
  if (argc > 4) {
    filename_tx = argv[4];
    if (strcmp(filename_tx,"")==0) {
      f_tx = NULL;
    }
    else if ( strcmp(filename_tx,"-")==0 ) {
      f_tx = stdout;
    }
    else if ( !(f_tx=fopen(filename_tx,"wb")) ) {
      fprintf(stderr, "%s: open failed for output text file `%s': %s\n", prog, filename_tx, strerror(errno));
      exit(1);
    }
  }

  //-- print output header(s)
  if (f_cx) cx_put_header(f_cx);

  //-- setup expat parser
  xp = XML_ParserCreate("UTF-8");
  if (!xp) {
    fprintf(stderr, "%s: XML_ParserCreate failed", prog);
    exit(1);
  }
  XML_SetUserData(xp, &data);
  XML_SetElementHandler(xp, (XML_StartElementHandler)cb_start, (XML_EndElementHandler)cb_end);
  XML_SetCharacterDataHandler(xp, (XML_CharacterDataHandler)cb_char);
  XML_SetDefaultHandler(xp, (XML_DefaultHandler)cb_default);

  //-- setup callback data
  memset(&data,0,sizeof(data));
  data.xp   = xp;
  data.f_cx = f_cx;
  data.f_sx = f_sx;
  data.f_tx = f_tx;

  //-- parse input file
  n_xbytes = expat_parse_file(xp,f_in,filename_in);

  //-- always terminate text file with a newline
  //if (f_tx) fputc('\n',f_tx);

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
  if (f_cx) fclose(f_cx);
  if (f_sx && f_sx != f_cx) fclose(f_sx);
  if (f_tx && f_tx != f_cx && f_tx != f_sx) fclose(f_tx);
  if (xp) XML_ParserFree(xp);

  return 0;
}
