#include "dtatwCommon.h"

/*======================================================================
 * Globals
 */

// VERBOSE_IO : whether to print progress messages for load/save
//#define VERBOSE_IO 1
#undef VERBOSE_IO

// WARN_ON_OVERLAP : whether to output warnings when token overlap is detected
//  + whether or not this is defined, an "overlap" attribute will be written
//    for overlapping tokens if 'olAttr' is non-NULL (see xml structure constants, below)
#define WARN_ON_OVERLAP 1
//#undef WARN_ON_OVERLAP

// COMPRESS_CIDS
//  + if defined, c id lists will be compressed into '${CID_FIRST}+${LEN}' lists
#define COMPRESS_CIDS 1

//-- want_profile: if true, some profiling information will be printed to stderr
//int want_profile = 1;
int want_profile = 0;
//
ByteOffset nxbytes = 0; //-- for profiling: approximate number of xml bytes in original input (from .cx file)
ByteOffset ntoks   = 0; //-- for profiling: number of tokens (from .t file)

//-- indentation constants (set these to empty strings to output size-optimized XML)
const char *indent_root = "\n";
const char *indent_s    = "\n  ";
const char *indent_w    = "\n    ";
const char *indent_al   = "\n      ";
const char *indent_a    = "\n        ";

//-- xml structure constants (should jive with 'mkbx0', 'mkbx')
const char *docElt = "sentences";  //-- output document element
const char *sElt   = "s";          //-- output sentence element
const char *wElt   = "w";          //-- output token element
const char *alElt  = "toka";	   //-- output token-analyses element
const char *aElt   = "a";          //-- output token-analysis element
const char *txtPosAttr = "b";      //-- output .txt byte-position attribute (b="OFFSET LEN")
const char *xmlPosAttr = "xb";     //-- output .xml byte-position attribute (xb="OFFSET_0+LEN_0... OFFSET_N+LEN_N")
const char *olAttr  = "overlap";   //-- output overlap-properties attribute
const char *textAttr = "t";        //-- output token-text attribute
const char *cAttr    = "c";        //-- output token-chars attribute (space-separated (xml:)?ids from .cx file)


/*======================================================================
 * Utils: .cx, .bx file, indexing
 *  + now in dtatwCommon.[ch]
 */
cxData cxdata = {NULL,0,0};       //-- cxRecord *cx = &cxdata->data[c_index]
bxData bxdata = {NULL,0,0};       //-- bxRecord *bx = &bxdata->data[block_index]

Offset2CxIndex txb2cx  = {NULL,0};  //-- cxRecord *cx =  txb2cx->data[ tx_byte_index]
Offset2CxIndex txtb2cx = {NULL,0};  //-- cxRecord *cx = txtb2cx->data[txt_byte_index]

/*======================================================================
 * Utils: .tt
 */

//--------------------------------------------------------------
/* bool = cx_id_ok(cx)
 *  + returns true iff cx is a "real" character record with a valid id, etc.
 *  + ignores ids: NULL, "", CX_NIL_ID
 *  + does NOT ignore: CX_LB_ID, CX_PB_ID, CX_FORMULA_ID
 *  + see dtatwCommon.h for id constants
 */
static inline int cx_id_ok(const cxRecord *cx)
{
  return (cx
	  && cx->id
	  && cx->id[0]
	  && strcmp(cx->id,CX_NIL_ID) !=0
	  //&& strncmp(cx->id,CX_FORMULA_PREFIX,strlen(CX_FORMULA_PREFIX)) !=0
	  //&& strcmp(cx->id,CX_LB_ID) !=0
	  //&& strcmp(cx->id,CX_PB_ID) !=0
	  );
}

//--------------------------------------------------------------
/* Typedef(s) for .tt "word buffer"
 */
#define WORDBUF_TEXT_LEN 8192
#define WORDBUF_CX_LEN   8192
#define WORDBUF_REST_LEN 8192

//-- flags for ttWordBuffer
typedef enum {
  ttwNone  = 0x0000,    //-- no special flags
  ttwSB    = 0x0001,    //-- whether we saw a sentence boundary before this word
  ttwOverL = 0x0004,    //-- did this word overlap to its left?
  ttwOverR = 0x0008,    //-- did this word overlap to its right?
  ttwAll   = 0x000f,    //-- all flags
} ttWordFlags;

const unsigned int ttwOver = (ttwOverL|ttwOverR); //-- flag-mask: all overlap flags

typedef struct {
  unsigned int w_flags;                //-- mask of ttWordFlags flags
  ByteOffset w_off;                    //-- .txt byte offset, as reported by tokenizer
  ByteOffset w_len;                    //-- .txt byte length, as reported by tokenizer
  char       w_text[WORDBUF_TEXT_LEN]; //-- word text buffer
  char       w_rest[WORDBUF_REST_LEN]; //-- word analyses buffer (TAB-separated)
  cxRecord  *w_cx  [WORDBUF_CX_LEN];   //-- word .cx buffer
} ttWordBuffer;

unsigned int s_id_ctr = 0;  //-- counter for generated //s/@(xml:)?id
unsigned int w_id_ctr = 0;  //-- counter for generated //w/@(xml:)?id

//--------------------------------------------------------------
// global temps for output construction
#define WORD_XMLPOS_LEN 8192
char w_xmlpos[WORD_XMLPOS_LEN];

//--------------------------------------------------------------
/* tt_next_word(f_out, w0, w1, &s_open)
 *  + checks for pathological conditions on word boundaries
 *  + w0 is the previous word read
 *  + w1 is the current word
 *  + s_open is a flag indicating whether a sentence-element is currently open
 *  + may output a record for w0 (if remainder of w1 is non-empty)
 *  + assigns w0 contents to (the unused portions of) w1
 */
unsigned int tt_linenum = 1;
const char *tt_filename = "(?)";
static void tt_next_word(FILE *f_out, ttWordBuffer *w0, ttWordBuffer *w1, int *s_open)
{
  //-- boundary checks: token-overlap
  if (w1->w_cx[0] && w1->w_cx[0] == w0->w_cx[w0->w_len-1]) {
    cxRecord *cx = w1->w_cx[0];
    int w1i;

#if WARN_ON_OVERLAP
    fprintf(stderr, "%s: WARNING: file `%s' line %u: token-overlap between \"%s\" and \"%s\" detected, c-id=\"%s\"\n",
	    prog, tt_filename, tt_linenum, w0->w_text, w1->w_text, cx->id);
#endif

    //-- append to w0: w1.(cx,text)
    for (w1i=0; w1->w_cx[w1i]==cx; w1i++) {
      w0->w_text[w0->w_len+w1i] = w1->w_text[w1i];
      w0->w_cx  [w0->w_len+w1i] = cx;
    }
    //-- update w0: (cx,text) terminators, length
    w0->w_text[w0->w_len+w1i] = '\0';
    w0->w_cx  [w0->w_len+w1i] = NULL;
    w0->w_len += w1i;

    //-- update w1.(cx,text,len)
    w1->w_off += w1i;
    w1->w_len -= w1i;
    memmove(&w1->w_text[0], &w1->w_text[w1i], (w1->w_len+1)*sizeof(char));
    memmove(&w1->w_cx  [0], &w1->w_cx  [w1i], (w1->w_len+1)*sizeof(cxRecord*));

    //-- update: overlap flags
    w0->w_flags |= ttwOverR;
    w1->w_flags |= ttwOverL;

    //-- check for empty w1
    if (w1->w_len == 0) {
      //-- empty w1: maybe adopt analyses
      if (w1->w_rest[0]) {
	char *w0rest_end = &w0->w_rest[strlen(w0->w_rest)];
	*w0rest_end = '\t';
	w0rest_end++;
	assert(w0rest_end-&w0->w_rest[0]+strlen(w1->w_rest) < WORDBUF_REST_LEN /* buffer overflow */);
	strcpy(w0rest_end, w1->w_rest);
	w1->w_rest[0] = '\0';
      }
      //-- empty w1: adopt sentence-boundary flags (no!)
      //w0->w_flags |= (w1->w_flags & ttwSB);
    }
  }

  //-- output: w0 (only for non-empty w0 AND w1)
  if (w0->w_len && w1->w_len) {

    //-- output: check for EOS
    if (w0->w_flags & ttwSB) {
      if (*s_open) fprintf(f_out, "%s</%s>", indent_s, sElt);
      *s_open = 0;
    }
    //-- output: check for BOS (depending only on *s_open; regardless of ttwSB flag)
    if (!*s_open) {
      fprintf(f_out, "%s<%s %s=\"s%lu\">", indent_s, sElt, xmlid_name, ++s_id_ctr);
      *s_open = 1;
    }

    //-- output: w0: begin: open <w ...>
    fprintf(f_out, "%s<%s %s=\"w%lu\"", indent_w, wElt, xmlid_name, ++w_id_ctr);

    //-- output: w0: text
    if (textAttr) {
      fprintf(f_out, " %s=\"", textAttr);
      put_escaped_str(f_out, w0->w_text, -1);
      fputc('"', f_out);
    }

    //-- output: w0: location: .txt
    if (txtPosAttr)
      fprintf(f_out, " %s=\"%lu %lu\"", txtPosAttr, w0->w_off, w0->w_len);

    //-- output: w0: c-ids
    if (cAttr) {
      int i,j,len;
      cxRecord *icx_prev = NULL; //-- previous cx record whose ID we've output, or NULL on first <c>
      cxRecord *jcx_prev = NULL; //-- ... for compressed c id lists
      char     *xmlpos   = w_xmlpos;
      ByteOffset xmloff  = (ByteOffset)-1;
      ByteOffset xmlend  = (ByteOffset)-1;
      fprintf(f_out, " %s=\"", cAttr);
      *xmlpos = '\0';
      for (i=0; i < w0->w_len; i++) {
	cxRecord *icx = txtb2cx.data[w0->w_off+i];
	if (!cx_id_ok(icx) || icx==icx_prev) continue;  //-- ignore pseudo-ids and duplicates
	if (icx_prev) { fputc(' ',f_out); *xmlpos++=' '; *xmlpos='\0'; }
	if (icx->id)  put_escaped_str(f_out, icx->id, -1);
	xmloff = icx->xoff;
	xmlend = xmloff + icx->xlen;
#ifdef COMPRESS_CIDS
	//-- compressed //c id-list output: get adjacent run length
	jcx_prev = icx;
	for (len=1, j=(i+1); j < w0->w_len; j++) {
	  cxRecord *jcx = txtb2cx.data[w0->w_off+j];
	  if (jcx==jcx_prev) continue;  //-- ignore duplicates
	  if (!cx_id_ok(jcx) || !cx_is_adjacent(jcx_prev,jcx)) break;
	  jcx_prev = jcx;
	  len++;
	  xmlend = jcx->xoff+jcx->xlen;
	}
	if (len > 1) fprintf(f_out, "+%d", len);
	i=j-1;
	icx = jcx_prev;
#endif /* COMPRESS_CIDS */
	icx_prev = icx;
	xmlpos += sprintf(xmlpos, "%lu+%lu", xmloff, (xmlend-xmloff));
      }
      fputc('"', f_out);
      if (xmlPosAttr) fprintf(f_out, " %s=\"%s\"", xmlPosAttr, w_xmlpos);
    }

    //-- output: w0: flags: overlap
    if (olAttr && (w0->w_flags & ttwOver)) {
      fprintf(f_out, " %s=\"%s%s\"",
	      olAttr,
	      ((w0->w_flags & ttwOverL) ? "L" : ""),
	      ((w0->w_flags & ttwOverR) ? "R" : ""));
    }

    //-- output: w0: analyses (finishing <w ...>, also writing </w> if required)
    if (w0->w_rest[0]) {
      char *w_rest = &w0->w_rest[0], *tail;
      fprintf(f_out, ">%s<%s>", indent_al, alElt);
      do {
	tail = next_tab(w_rest);
	fprintf(f_out, "%s<%s>", indent_a, aElt);
	put_escaped_str(f_out, w_rest, tail-w_rest);
	fprintf(f_out, "</%s>", aElt);
	if (tail && *tail) tail++;
	w_rest = tail;
      } while (*w_rest);
      fprintf(f_out, "%s</%s>%s</w>", indent_al, alElt, indent_w);
    }
    else {
      fputs("/>", f_out);
    }

    //-- update: profiling information
    ++ntoks;
  }

  //-- update: w0 <- w1 (only for non-empty w1)
  if (w1->w_len) {
    w0->w_flags = w1->w_flags;
    w0->w_off   = w1->w_off;
    w0->w_len   = w1->w_len;
    strcpy(w0->w_text, w1->w_text);
    strcpy(w0->w_rest, w1->w_rest);
    memcpy(w0->w_cx, w1->w_cx, w1->w_len*sizeof(cxRecord*));
  }

  //-- update: clear w1 (always)
  memset(w1, 0, sizeof(ttWordBuffer));
  w1->w_flags = ttwNone;
  w1->w_off   = 0;
  w1->w_len   = 0;
  w1->w_text[0] = '\0';
  w1->w_rest[0] = '\0';
  w1->w_cx[0]   = NULL;
}

//--------------------------------------------------------------
/* process_tt_file()
 *  + requires:
 *    - populated cxdata struct (see cxDataLoad() in dtatwCommon.c)
 *    - populated txtb2cx struct (see txt2cxIndex() in dtatwCommon.c)
 */
#define INITIAL_TT_LINEBUF_SIZE 8192
static void process_tt_file(FILE *f_in, FILE *f_out, char *filename_in, char *filename_out)
{
  char *linebuf=NULL; //, *s0, *s1;
  size_t linebuf_alloc=0;
  ssize_t linelen;
  int s_open = 0;          //-- bool: is an <s> element currently open?
  char *w_text, *w_loc, *w_loc_tail, *w_rest;  //-- temps for input parsing
  ttWordBuffer w0, w1;     //-- word buffers;

  //-- sanity checks
  assert(f_in != NULL /* no .tt input file? */);
  assert(f_out != NULL /* no .xml output file? */);
  assert(cxdata.data != NULL /* require .cx data */);
  assert(txtb2cx.data != NULL /* require txt-byte -> cx-pointer lookup vector */);

  //-- init line buffer
  linebuf = (char*)malloc(INITIAL_TT_LINEBUF_SIZE);
  assert(linebuf != NULL /* malloc failed */);
  linebuf_alloc = INITIAL_TT_LINEBUF_SIZE;

  //-- init error reporting globals
  tt_linenum = 0;
  tt_filename = filename_in;

  //-- init word buffer(s)
  memset(&w0, 0, sizeof(ttWordBuffer));
  memset(&w1, 0, sizeof(ttWordBuffer));

  //-- ye olde loope
  while ( (linelen=getline(&linebuf,&linebuf_alloc,f_in)) >= 0 ) {
    ++tt_linenum;
    if (linebuf[0]=='%' && linebuf[1]=='%') continue;  //-- skip comments

    //-- chomp newline (and maybe carriage return)
    if (linelen>0 && linebuf[linelen-1]=='\n') linebuf[--linelen] = '\0';
    if (linelen>0 && linebuf[linelen-1]=='\r') linebuf[--linelen] = '\0';

    //-- check for EOS (blank line)
    if (linebuf[0]=='\0') {
      w1.w_flags |= ttwSB;
      continue;
    }

    //-- word: inital parse into strings (w_text, w_loc, w_rest)
    w_text = linebuf;
    w_loc  = next_tab_z(w_text)+1;
    w_rest = next_tab_z(w_loc)+1;
    assert(w_loc-w_text < WORDBUF_TEXT_LEN /* buffer overflow */);
    assert(linelen-(w_rest-w_text) < WORDBUF_REST_LEN /* buffer overflow */);

    //-- word: parse to buffer 'w1'
    w1.w_off = strtoul(w_loc,      &w_loc_tail, 0);
    w1.w_len = strtoul(w_loc_tail, NULL,        0);
    strcpy(w1.w_text, w_text);
    strcpy(w1.w_rest, w_rest);

    //-- word: populate w1.w_cx[] buffer
    assert(w1.w_len < WORDBUF_CX_LEN /* buffer overflow */);
    assert(w1.w_off+w1.w_len <= txtb2cx.len /* positioning error would cause segfault */);
    memcpy(w1.w_cx, txtb2cx.data+w1.w_off, w1.w_len*sizeof(cxRecord*));
    w1.w_cx[w1.w_len] = NULL;

    //-- word: dump output
    tt_next_word(f_out, &w0, &w1, &s_open);
  }
  //-- output final word (in 'w0' buffer)
  memset(&w1, 0, sizeof(ttWordBuffer));
  w1.w_len = 1; //-- hack
  tt_next_word(f_out, &w0, &w1, &s_open);

  //-- close open sentence if any
  if (s_open) fprintf(f_out, "%s</%s>", indent_s, sElt);

  //-- cleanup
  if (linebuf) free(linebuf);
}

/*======================================================================
 * MAIN
 */
int main(int argc, char **argv)
{
  char *filename_in  = "-";
  char *filename_cx  = NULL;
  char *filename_bx  = NULL;
  char *filename_out = "-";
  char *xmlbase = NULL;  //-- root @xml:base attribute (or basename)
  char *xmlsuff = "";    //-- additional suffix for root @xml:base
  FILE *f_in  = stdin;   //-- input .t file
  FILE *f_cx  = NULL;    //-- input .cx file
  FILE *f_bx  = NULL;    //-- input .tx file
  FILE *f_out = stdout;  //-- output .xml file
  int i;

  //-- initialize: globals
  prog = file_basename(NULL,argv[0],"",-1,0);

  //-- command-line: usage
  if (argc <= 3) {
    fprintf(stderr, "(%s version %s / %s)\n", PACKAGE, PACKAGE_VERSION, PACKAGE_SVNID);
    fprintf(stderr, "Usage:\n");
    fprintf(stderr, " %s TFILE CXFILE BXFILE [OUTFILE [XMLBASE]]\n", prog);
    fprintf(stderr, " + TFILE   : raw tokenizer output file\n");
    fprintf(stderr, " + CXFILE  : character index file as created by dtatw-mkindex\n");
    fprintf(stderr, " + BXFILE  : block index file as created by dta-tokwrap.perl\n");
    fprintf(stderr, " + OUTFILE : output XML file (default=stdout)\n");
    fprintf(stderr, " + XMLBASE : root xml:base attribute value for output file\n");
    fprintf(stderr, " + \"-\" may be used in place of any filename to indicate standard (in|out)put\n");
    exit(1);
  }
  //-- command-line: input file
  if (argc > 1) {
    filename_in = argv[1];
    if (strcmp(filename_in,"-")==0) f_in = stdin;
    else if ( !(f_in=fopen(filename_in,"rb")) ) {
      fprintf(stderr, "%s: open failed for input .t file `%s': %s\n", prog, filename_in, strerror(errno));
      exit(1);
    }
  }
  //-- command-line: .cx file
  if (argc > 2) {
    filename_cx = argv[2];
    if (strcmp(filename_cx,"-")==0) f_cx = stdin;
    else if ( !(f_cx=fopen(filename_cx,"rb")) ) {
      fprintf(stderr, "%s: open failed for input .cx file `%s': %s\n", prog, filename_cx, strerror(errno));
      exit(1);
    }
  }
  //-- command-line: .bx file
  if (argc > 3) {
    filename_bx = argv[3];
    if (strcmp(filename_bx,"-")==0) f_bx = stdin;
    else if ( !(f_bx=fopen(filename_bx,"rb")) ) {
      fprintf(stderr, "%s: open failed for input .bx file `%s': %s\n", prog, filename_bx, strerror(errno));
      exit(1);
    }
  }
  //-- command-line: output file
  if (argc > 4) {
    filename_out = argv[4];
    if (strcmp(filename_out,"")==0) {
      f_out = NULL;
    }
    else if ( strcmp(filename_out,"-")==0 ) {
      f_out = stdout;
    }
    else if ( !(f_out=fopen(filename_out,"wb")) ) {
      fprintf(stderr, "%s: open failed for output XML file `%s': %s\n", prog, filename_out, strerror(errno));
      exit(1);
    }
  }
  //-- command-line: xmlbase
  if (argc > 5) {
    xmlbase = argv[5];
    xmlsuff = "";
  } else if (filename_cx && filename_cx[0] && strcmp(filename_cx,"-") != 0) {
    xmlbase = file_basename(NULL, filename_cx, ".cx", -1,0);
    xmlsuff = ".xml";
  } else if (filename_bx && filename_bx[0] && strcmp(filename_bx,"-") != 0) {
    xmlbase = file_basename(NULL, filename_bx, ".bx", -1,0);
    xmlsuff = ".xml";
  } else if (filename_in && filename_in[0] && strcmp(filename_in,"-") != 0) {
    xmlbase = file_basename(NULL, filename_in, ".t", -1,0);
    xmlsuff = ".xml";
  } else if (filename_out && filename_out[0] && strcmp(filename_out,"-") != 0) {
    xmlbase = file_basename(NULL, filename_out, ".t.xml", -1,0);
    xmlsuff = ".xml";
  } else {
    xmlbase = NULL; //-- couldn't guess xml:base
  }

  //-- print basic XML header
  fprintf(f_out, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
  fprintf(f_out, "<!--\n");
  fprintf(f_out, " ! File created by %s (%s version %s)\n", prog, PACKAGE, PACKAGE_VERSION);
  fprintf(f_out, " ! Command-line: %s", argv[0]);
  for (i=1; i < argc; i++) {
    fprintf(f_out, " '%s'", (argv[i][0] ? argv[i] : ""));
  }
  fprintf(f_out, "\n !-->\n");

  //-- load .cx data
  cxDataLoad(&cxdata, f_cx);
  if (f_cx != stdin) fclose(f_cx);
  f_cx = NULL;
#ifdef VERBOSE_IO
  fprintf(stderr, "%s: parsed %lu records from .cx file '%s'\n", prog, cxdata.len, filename_cx);
#endif
  

  //-- load .bx data
  bxDataLoad(&bxdata, f_bx);
  if (f_bx != stdin) fclose(f_bx);
  f_bx = NULL;
#ifdef VERBOSE_IO
  fprintf(stderr, "%s: parsed %lu records from .bx file '%s'\n", prog, bxdata.len, filename_bx);
  assert(cxdata != NULL && cxdata->data != NULL /* require cxdata */);
  assert(cxdata.len > 0 /* require non-empty cxdata */);
  fprintf(stderr, "%s: number of source XML-bytes ~= %lu\n", prog, cxdata->data[cxdata.len-1].xoff);
#endif

  //-- create (tx_byte_index => cx_record) lookup vector
  tx2cxIndex(&txb2cx, &cxdata);
#ifdef VERBOSE_IO
  fprintf(stderr, "%s: initialized %lu-element .tx-byte => .cx-record index\n", prog, txb2cx.len);
#endif

  //-- create (txt_byte_index => cx_record_or_NULL) lookup vector
 txt2cxIndex(&txtb2cx, &bxdata, &txb2cx);
#ifdef VERBOSE_IO
  fprintf(stderr, "%s: initialized %lu-element .txt-byte => .cx-record index\n", prog, txtb2cx.len);
#endif

  //-- print XML root element
  fprintf(f_out,"<%s",docElt);
  if (xmlbase && *xmlbase) {
    fprintf(f_out, " xml:base=\"%s%s\"", xmlbase, xmlsuff);
  }
  fputc('>',f_out);

  //-- process .tt-format input data
  process_tt_file(f_in,f_out, filename_in,filename_out);

  //-- print XML footer
  fprintf(f_out, "%s</%s>\n", indent_root, docElt);

  //-- show profile?
  if (want_profile) {
    double elapsed = ((double)clock()) / ((double)CLOCKS_PER_SEC);
    if (elapsed <= 0) elapsed = 1e-5;

    assert(cxdata.data != NULL/* profile: require cxdata */);
    assert(cxdata.len > 0 /* profile: require non-empty cxdata */);
    
    //-- approximate number of original source XML bytes
    nxbytes = cxdata.data[cxdata.len-1].xoff + cxdata.data[cxdata.len-1].xlen;

    fprintf(stderr, "%s: processed %.1f%s tok ~ %.1f%s XML bytes in %.3f sec: %.1f %stok/sec ~ %.1f %sbyte/sec\n",
	    prog,
	    si_val(ntoks), si_suffix(ntoks),
	    si_val(nxbytes), si_suffix(nxbytes),
	    elapsed,
	    si_val(ntoks/elapsed), si_suffix(ntoks/elapsed),
	    si_val(nxbytes/elapsed), si_suffix(nxbytes/elapsed)
	    );
  }

  //-- cleanup
  if (f_in)  fclose(f_in);
  if (f_cx)  fclose(f_cx);
  if (f_bx)  fclose(f_bx);
  if (f_out) fclose(f_out);

  return 0;
}
