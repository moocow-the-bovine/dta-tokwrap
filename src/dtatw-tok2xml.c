#include "dtatwCommon.h"

/*======================================================================
 * Globals
 */

// VERBOSE_IO : whether to print progress messages for load/save
//#define VERBOSE_IO 1
#undef VERBOSE_IO

// CX_WANT_TEXT : whether to parse & store text data from .cx file
//#define CX_WANT_TEXT 1
#undef CX_WANT_TEXT

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
const char *indent_a    = "\n      ";

//-- xml structure constants (should jive with 'mkbx0', 'mkbx')
const char *docElt = "sentences";  //-- output document element
const char *sElt   = "s";          //-- output sentence element
const char *wElt   = "w";          //-- output token element
const char *aElt   = "a";          //-- output token-analysis element
const char *posAttr = "b";         //-- output byte-position attribute
const char *textAttr = "t";        //-- output token-text attribute
const char *cAttr    = "c";        //-- output token-chars attribute (space-separated xml:ids from .cx file)


/*======================================================================
 * Utils: .cx file
 */

// cxRecord : struct for character-index records as loaded from .cx file
typedef struct {
  char        *id;      //-- xml:id of source <c>
  ByteOffset xoff;      //-- original xml byte offset
  ByteLen    xlen;      //-- original xml byte length
  ByteOffset toff;      //-- .tx byte offset
  ByteLen    tlen;      //-- .tx byte length
#ifdef CX_WANT_TEXT
  char      *text;      //-- output text
#endif
} cxRecord;

// CXDATA_INITIAL_ALLOC : original buffer size for cxdata[], in number of records
#define CXDATA_INITIAL_ALLOC 8192

// cxdata : cxRecord[ncxdata_alloc]
cxRecord *cxdata = NULL;
ByteOffset ncxdata_alloc = 0;  //-- number of records allocated in cxdata
ByteOffset ncxdata = 0;        //-- number of records used in cxdata (index of 1st unused record)

//--------------------------------------------------------------
static void initCxData(void)
{
  cxdata = (cxRecord*)malloc(CXDATA_INITIAL_ALLOC*sizeof(cxRecord));
  assert(cxdata != NULL /* memory full on malloc */);
  ncxdata_alloc = CXDATA_INITIAL_ALLOC;
  ncxdata = 0;
}

//--------------------------------------------------------------
static void pushCxRecord(cxRecord *cx)
{
  if (ncxdata+1 >= ncxdata_alloc) {
    //-- whoops: must reallocate
    cxdata = (cxRecord*)realloc(cxdata, ncxdata_alloc*2*sizeof(cxRecord));
    assert(cxdata != NULL /* memory full on realloc */);
    ncxdata_alloc *= 2;
  }
  //-- just push copy raw data, pointers & all
  memcpy(&cxdata[ncxdata], cx, sizeof(cxRecord));
  ncxdata++;
}

//--------------------------------------------------------------
// un-escapes cx file text string to a new string; returns newly allocated string
static char *cx_text_string(char *src, int src_len)
{
  int i,j;
  char *dst = (char*)malloc(src_len);
  for (i=0,j=0; src[i] && i < src_len; i++,j++) {
    switch (src[i]) {
    case '\\':
      i++;
      switch (src[i]) {
      case '0': dst[j] = '\0'; break;
      case 'n': dst[j] = '\n'; break;
      case 't': dst[j] = '\t'; break;
      case '\\': dst[j] = '\\'; break;
      default: dst[j] = src[i]; break;
      }
    default:
      dst[j] = src[i];
      break;
    }
  }
  dst[j] = '\0';
}

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
#define INITIAL_LINEBUF_SIZE 1024
static void loadCxFile(FILE *f)
{
  cxRecord cx;
  char *linebuf=NULL;
  size_t linebuf_alloc=0;
  ssize_t linelen;
  char *s0, *s1;

  if (cxdata==NULL) initCxData();
  assert(f!=NULL /* require .cx file */);

  //-- init line buffer
  linebuf = (char*)malloc(INITIAL_LINEBUF_SIZE);
  assert(linebuf != NULL /* malloc failed */);
  linebuf_alloc = INITIAL_LINEBUF_SIZE;

  while ( (linelen=getline(&linebuf,&linebuf_alloc,f)) >= 0 ) {
    char *tail;
    if (linebuf[0]=='%' && linebuf[1]=='%') continue;  //-- skip comments

    //-- ID
    s0  = linebuf;
    s1  = next_tab_z(s0);
    cx.id = strdup(s0);

    //-- xoff
    s0 = s1+1;
    s1 = next_tab(s0);
    cx.xoff = strtoul(s0,&tail,0);

    //-- xlen
    s0 = s1+1;
    s1 = next_tab(s0);
    cx.xlen = strtol(s0,&tail,0);

    //-- toff
    s0 = s1+1;
    s1 = next_tab(s0);
    cx.toff = strtoul(s0,&tail,0);

    //-- tlen
    s0 = s1+1;
    s1 = next_tab(s0);
    cx.tlen = strtol(s0,&tail,0);

#ifdef CX_WANT_TEXT
    //-- text
    s0 = s1+1;
    s1 = next_tab_z(s0);
    cx.text = cx_text_string(text_s, s1-s0);
#endif

    pushCxRecord(&cx);
  }

  //-- cleanup
  if (linebuf) free(linebuf);
}

/*======================================================================
 * Utils: .bx file
 */

// bxRecord : struct for block-index records as loaded from .bx file
typedef struct {
  char *key;        //-- sort key
  char *elt;        //-- element name
  ByteOffset xoff;  //-- xml byte offset
  ByteOffset xlen;  //-- xml byte length
  ByteOffset toff;  //-- tx byte offset
  ByteOffset tlen;  //-- tx byte length
  ByteOffset otoff; //-- txt byte offset
  ByteOffset otlen; //-- txt byte length
} bxRecord;

// BXDATA_INITIAL_ALLOC : original buffer size for cxdata[], in number of records
#define BXDATA_INITIAL_ALLOC 1024

// bxdata : bxRecord[nbxdata_alloc]
bxRecord *bxdata = NULL;
ByteOffset nbxdata_alloc = 0;  //-- number of records allocated in bxdata
ByteOffset nbxdata = 0;        //-- number of records used in bxdata (index of 1st unused record)

//--------------------------------------------------------------
static void initBxData(void)
{
  bxdata = (bxRecord*)malloc(BXDATA_INITIAL_ALLOC*sizeof(bxRecord));
  assert(bxdata != NULL /* malloc failed */);
  nbxdata_alloc = BXDATA_INITIAL_ALLOC;
  nbxdata = 0;
}

//--------------------------------------------------------------
static void pushBxRecord(bxRecord *bx)
{
  if (nbxdata+1 >= nbxdata_alloc) {
    //-- whoops: must reallocate
    bxdata = (bxRecord*)realloc(bxdata, nbxdata_alloc*2*sizeof(bxRecord));
    assert(bxdata != NULL /* memory full on realloc */);
    nbxdata_alloc *= 2;
  }
  //-- just push copy raw data, pointers & all
  memcpy(&bxdata[nbxdata], bx, sizeof(bxRecord));
  nbxdata++;
}

//--------------------------------------------------------------
static void loadBxFile(FILE *f)
{
  bxRecord bx;
  char *linebuf=NULL, *s0, *s1;
  size_t linebuf_alloc=0;
  ssize_t linelen;

  if (bxdata==NULL) initBxData();
  assert(f!=NULL /* require .bx file */);

  //-- init line buffer
  linebuf = (char*)malloc(INITIAL_LINEBUF_SIZE);
  assert(linebuf != NULL /* malloc failed */);
  linebuf_alloc = INITIAL_LINEBUF_SIZE;

  while ( (linelen=getline(&linebuf,&linebuf_alloc,f)) >= 0 ) {
    char *tail;
    if (linebuf[0]=='%' && linebuf[1]=='%') continue;  //-- skip comments

    //-- key
    s0  = linebuf;
    s1  = next_tab_z(s0);
    bx.key = strdup(s0);

    //-- elt
    s0 = s1+1;
    s1 = next_tab_z(s0);
    bx.elt = strdup(s0);

    //-- xoff
    s0 = s1+1;
    s1 = next_tab(s0);
    bx.xoff = strtoul(s0,&tail,0);

    //-- xlen
    s0 = s1+1;
    s1 = next_tab(s0);
    bx.xlen = strtoul(s0,&tail,0);

    //-- toff
    s0 = s1+1;
    s1 = next_tab(s0);
    bx.toff = strtoul(s0,&tail,0);

    //-- tlen
    s0 = s1+1;
    s1 = next_tab(s0);
    bx.tlen = strtol(s0,&tail,0);

    //-- otoff
    s0 = s1+1;
    s1 = next_tab(s0);
    bx.otoff = strtoul(s0,&tail,0);

    //-- otlen
    s0 = s1+1;
    s1 = next_tab(s0);
    bx.otlen = strtol(s0,&tail,0);

    pushBxRecord(&bx);
  }

  //-- cleanup
  if (linebuf) free(linebuf);
}

/*======================================================================
 * Utils: indexing
 */

//--------------------------------------------------------------
//-- txb2cx[ntxb] tx byte-index to cx record lookup vector
cxRecord   **txb2cx = NULL; //-- cxRecord = txb2cx[tx_byte_index]
ByteOffset   ntxb   = 0;    //-- number of raw tx bytes

//--------------------------------------------------------------
/* init_txb2ci()
 *  + allocates & populates tb2ci lookup vector:
 *  + requires loaded, non-empty cxdata
 */
void init_txb2ci(void)
{
  cxRecord *cx;
  ByteOffset cxi, txi, t_end;
  assert(cxdata != NULL /* require loaded cx data */);
  assert(ncxdata > 0    /* require non-empty cx index */);

  cx     = &cxdata[ncxdata-1];
  ntxb   = cx->toff + cx->tlen;
  txb2cx = (cxRecord**)malloc(ntxb*sizeof(cxRecord*));
  assert(txb2cx != NULL /* malloc failed for tx-byte to cx-record lookup vector */);
  memset(txb2cx,0,ntxb*sizeof(cxRecord*)); //-- zero the block

  for (cxi=0; cxi < ncxdata; cxi++) {
    cx    = &cxdata[cxi];
#if 0
    //-- map ALL tx-bytes generated by this 'c' to a pointer (may cause token overlap!)
    t_end = cx->toff+cx->tlen;
    for (txi=cx->toff; txi < t_end; txi++) {
      txb2cx[txi] = cx;
    }
#else
    //-- map only the FIRST tx-byte generated by this 'c' to a pointer
    txb2cx[cx->toff] = cx;
#endif
  }

  return;
}

//--------------------------------------------------------------
/* init_txtb2ci()
 *  + allocates & populates txtb2ci lookup vector
 *  + requires:
 *    - populated bxdata[] vector (see loadBxFile())
 *    - populated txb2ci[] vector (see init_txb2ci())
 */
cxRecord   **txtb2cx = NULL; //-- cxRecord_or_NULL = txtb2cx[txt_byte_index]
ByteOffset   ntxtb   = 0;    //-- number of .txt bytes

void init_txtb2ci(void)
{
  bxRecord *bx;
  ByteOffset bxi, txti, ot_end;
  assert(bxdata != NULL /* require loaded bx data */);
  assert(nbxdata > 0    /* require non-empty bx index */);

  bx      = &bxdata[nbxdata-1];
  ntxtb   = bx->otoff + bx->otlen;
  txtb2cx = (cxRecord**)malloc(ntxtb*sizeof(cxRecord*));
  assert(txtb2cx != NULL /* malloc failed for txt-byte to cx-record lookup vector */);
  memset(txtb2cx,0,ntxtb*sizeof(cxRecord*)); //-- zero the block

  for (bxi=0; bxi < nbxdata; bxi++) {
    bx = &bxdata[bxi];
    if (bx->tlen > 0) {
      //-- "normal" text which SHOULD have corresponding cx records
      for (txti=0; txti < bx->otlen; txti++) {
	cxRecord *cx = txb2cx[bx->toff+txti];
	txtb2cx[bx->otoff+txti] = cx;
	//-- (?) map special characters (e.g. <lb/>) to NULL here?
	//if (cx->id[0]=='$') { ... }
      }
    }
    //-- hints and other pseudo-text with NO cx records are mapped to NULL (via memset(), above)
  }

  return;
}

/*======================================================================
 * Utils: .tt
 */

//--------------------------------------------------------------
/* bool = cx_id_ok(cx)
 *  + returns true iff cx is a "real" character record with
 *    a valid id, etc.
 *  + ignores ids: NULL, "", CX_NIL_ID, CX_LB_ID (see dtatwCommon.h for the latter)
 */
static inline int cx_id_ok(const cxRecord *cx)
{
  return (cx
	  && cx->id
	  && cx->id[0]
	  && strcmp(cx->id,CX_NIL_ID)!=0
	  && strcmp(cx->id,CX_LB_ID) !=0
	  );
}

//--------------------------------------------------------------
/* process_tt_file()
 *  + requires:
 *    - populated cxdata[] vector (see loadCxFile())
 *    - populated txtb2ci[] vector (see init_txtb2ci())
 */
static void process_tt_file(FILE *f_in, FILE *f_out, char *filename_in, char *filename_out)
{
  char *linebuf=NULL, *s0, *s1;
  size_t linebuf_alloc=0;
  ssize_t linelen;
  unsigned int wi=0, si=0; //-- id-generation trackers
  int s_open = 0;          //-- bool: is an <s> element currently open?
  char *w_text, *w_loc, *w_loc_tail, *w_rest;
  ByteOffset w_loc_off, w_loc_len;


  //-- sanity checks
  assert(f_in != NULL /* no .tt input file? */);
  assert(f_out != NULL /* no .xml output file? */);
  assert(cxdata != NULL /* require .cx data */);
  assert(txtb2cx != NULL /* require txt-byte -> cx-pointer lookup vector */);

  //-- init line buffer
  linebuf = (char*)malloc(INITIAL_LINEBUF_SIZE);
  assert(linebuf != NULL /* malloc failed */);
  linebuf_alloc = INITIAL_LINEBUF_SIZE;

  while ( (linelen=getline(&linebuf,&linebuf_alloc,f_in)) >= 0 ) {
    if (linebuf[0]=='%' && linebuf[1]=='%') continue;  //-- skip comments

    //-- chomp newline (and maybe carriage return)
    if (linelen>0 && linebuf[linelen-1]=='\n') linebuf[--linelen] = '\0';
    if (linelen>0 && linebuf[linelen-1]=='\r') linebuf[--linelen] = '\0';

    //-- check for EOS (blank line)
    if (linebuf[0]=='\0') {
      if (s_open) fprintf(f_out, "%s</%s>", indent_s, sElt);
      s_open = 0;
      continue;
    }

    //-- word: maybe open new <s>
    if (!s_open) {
      fprintf(f_out, "%s<%s xml:id=\"s%lu\">", indent_s, sElt, ++si);
      s_open = 1;
    }

    //-- word: begin open <w>
    fprintf(f_out, "%s<%s xml:id=\"w%lu\"", indent_w, wElt, ++wi);

    //-- word: inital parse into (text,loc,rest)
    w_text = linebuf;
    w_loc  = next_tab_z(w_text)+1;
    w_rest = next_tab_z(w_loc)+1;

    //-- word: parse & output loc
    w_loc_off = strtoul(w_loc,      &w_loc_tail, 0);
    w_loc_len = strtoul(w_loc_tail, NULL,        0);
    if (posAttr)
      fprintf(f_out, " %s=\"%lu %lu\"", posAttr, w_loc_off, w_loc_len);

    //-- word: output text
    if (textAttr) {
      fprintf(f_out, " %s=\"", textAttr);
      put_escaped_str(f_out, w_text, -1);
      fputc('"', f_out);
    }

    //-- word: output c-ids
    if (cAttr) {
      int i;
      cxRecord *cx_prev = NULL; //-- previous cx record whose ID we've output, or NULL on first <c>
      fprintf(f_out, " %s=\"", cAttr);
      for (i=0; i < w_loc_len; i++) {
	cxRecord *cx = txtb2cx[w_loc_off+i];
	if (!cx_id_ok(cx)) continue;  //-- ignore pseudo-ids
	if (cx != cx_prev) {
	  if (cx_prev) fputc(' ',f_out);
	  if (cx->id)  put_escaped_str(f_out, cx->id, -1);
	  cx_prev = cx;
	}
      }
      fputc('"', f_out);
    }

    //-- word: output analyses (finishing <w ...>, also writing </w> if required)
    if (w_rest && *w_rest) {
      fputc('>',f_out);
      do {
	char *tail = next_tab(w_rest);
	fprintf(f_out, "%s<%s>", indent_a, aElt);
	put_escaped_str(f_out, w_rest, tail-w_rest);
	fprintf(f_out, "</%s>", aElt);
	if (tail && *tail) tail++;
	w_rest = tail;
      } while (w_rest && *w_rest);
      fprintf(f_out, "%s</w>", indent_w);
    }
    else {
      fputs("/>", f_out);
    }

    //-- word: update profiling information
    ++ntoks;
  }

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
  prog = argv[0];

  //-- command-line: usage
  if (argc <= 2) {
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
    if ( strcmp(filename_in,"-")!=0 && !(f_in=fopen(filename_in,"rb")) ) {
      fprintf(stderr, "%s: open failed for input .t file `%s': %s\n", prog, filename_in, strerror(errno));
      exit(1);
    }
  }
  //-- command-line: .cx file
  if (argc > 2) {
    filename_cx = argv[2];
    if ( !(f_cx=fopen(filename_cx,"rb")) ) {
      fprintf(stderr, "%s: open failed for input .cx file `%s': %s\n", prog, filename_cx, strerror(errno));
      exit(1);
    }
  }
  //-- command-line: .tx file
  if (argc > 3) {
    filename_bx = argv[3];
    if ( !(f_bx=fopen(filename_bx,"rb")) ) {
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

  //-- load cx file
  loadCxFile(f_cx);
  fclose(f_cx);
  f_cx = NULL;
#ifdef VERBOSE_IO
  fprintf(stderr, "%s: parsed %lu records from .cx file '%s'\n", prog, ncxdata, filename_cx);
#endif
  

  //-- load bx file
  loadBxFile(f_bx);
  fclose(f_bx);
  f_bx = NULL;
#ifdef VERBOSE_IO
  fprintf(stderr, "%s: parsed %lu records from .bx file '%s'\n", prog, nbxdata, filename_bx);
  assert(cxdata != NULL /* require cxdata */);
  assert(ncxdata > 0 /* require non-empty cxdata */);
  fprintf(stderr, "%s: number of source XML-bytes ~= %lu\n", prog, cxdata[ncxdata-1].xoff);
#endif

  //-- create (tx_byte_index => cx_record) lookup vector
  init_txb2ci();
#ifdef VERBOSE_IO
  fprintf(stderr, "%s: initialized %lu-element .tx-byte => .cx-record index\n", prog, ntxb);
#endif

  //-- create (txt_byte_index => cx_record_or_NULL) lookup vector
  init_txtb2ci();
#ifdef VERBOSE_IO
  fprintf(stderr, "%s: initialized %lu-element .txt-byte => .cx-record index\n", prog, ntxtb);
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

    assert(cxdata != NULL /* profile: require cxdata */);
    assert(ncxdata > 0 /* profile: require non-empty cxdata */);
    nxbytes = cxdata[ncxdata-1].xoff + cxdata[ncxdata-1].xlen; //-- approximate number of original source XML bytes


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
