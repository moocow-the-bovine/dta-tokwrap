#include "dtatwCommon.h"
#include "dtatwConfig.h"
/*#include "dtatw-cxlexer.h"*/

/*======================================================================
 * Globals
 */

// VERBOSE_IO : whether to print progress messages for load/save
#define VERBOSE_IO 1

// CX_USE_TEXT : whether to parse & store text data from .cx file
//#define CX_USE_TEXT 1
#undef CX_USE_TEXT

typedef struct {
  char        *id;      //-- xml:id of source <c>
  ByteOffset xoff;      //-- original xml byte offset
  ByteLen    xlen;      //-- original xml byte length
  ByteOffset toff;      //-- .tx byte offset
  ByteLen    tlen;      //-- .tx byte length
#ifdef CX_USE_TEXT
  char      *text;      //-- output text
#endif
} cxRecord;

// CXDATA_INITIAL_ALLOC : original buffer size for cxdata[], in number of records
#define CXDATA_INITIAL_ALLOC 8192

// cxdata : cxRecord[ncxdata_alloc]
cxRecord *cxdata = NULL;
ByteOffset ncxdata_alloc = 0;  //-- number of records allocated in cxdata
ByteOffset ncxdata = 0;        //-- number of records used in cxdata (index of 1st unused record)


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

//-- indentation constants
const char *indent_root = "\n";
const char *indent_s    = "\n  ";
const char *indent_w    = "\n    ";
const char *indent_a    = "\n      ";

//-- xml constants
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

#ifdef CX_USE_TEXT
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
    t_end = cx->toff+cx->tlen;
    for (txi=cx->toff; txi < t_end; txi++) {
      txb2cx[txi] = cx;
    }
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
/* init_txtb2ci()
 *  + allocates & populates txtb2ci lookup vector
 *  + requires:
 *    - populated cxdata[] vector (see loadCxFile())
 *    - populated txtb2ci[] vector (see init_txtb2ci())
 */
void process_tt_file(FILE *f_in, FILE *f_out, char *filename_in, char *filename_out)
{
  char *linebuf=NULL, *s0, *s1;
  size_t linebuf_alloc=0;
  ssize_t linelen;
  unsigned int wi=0, si=0; //-- id-generation trackers
  int s_open = 0;          //-- bool: is an <s> element currently open?
  char *w_text, *w_loc, *w_rest, *w_tail;
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

    //-- normal token: maybe open new <s>
    if (!s_open) {
      fprintf(f_out, "%s<%s xml:id=\"s%lu\">", indent_s, sElt, ++si);
      s_open = 1;
    }

    //-- normal token: begin open <w>
    fprintf(f_out, "%s<%s xml:id=\"w%lu\"", indent_w, wElt, ++wi);

    //-- normal token: inital parse into (text,loc,rest)
    w_text = linebuf;
    w_loc  = next_tab_z(w_text)+1;
    w_rest = next_tab_z(w_loc)+1;

    //-- parse & output loc
    w_loc_off = strtoul(w_loc,  &w_tail, 0);
    w_loc_len = strtoul(w_tail, NULL,    0);
    if (posAttr)
      fprintf(f_out, " %s=\"%lu %lu\"", posAttr, w_loc_off, w_loc_len);

    //-- output text
    if (textAttr) {
      fprintf(f_out, " %s=\"", textAttr);
      put_escaped_str(f_out, w_text, -1);
      fputc('"', f_out);
    }

    //-- output c-ids
    if (cAttr) {
      fprintf(f_out, " %s=\"", cAttr);
      fputs("--TODO--", f_out); //-- CONTINUE HERE
      fputc('"', f_out);
    }

    //-- output analyses (finishing <w ...>, also writing </w> if required)
    if (w_rest && *w_rest) {
      fputc('>',f_out);
      put_escaped_str(f_out, w_rest, -1); //-- HACK
      fprintf(f_out, "</w>");
    }
    else {
      fputs("/>", f_out);
    }

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
  char *xmlbase = NULL;
  FILE *f_in  = stdin;   //-- input .t file
  FILE *f_cx  = NULL;    //-- input .cx file
  FILE *f_bx  = NULL;    //-- input .tx file
  FILE *f_out = stdout;  //-- output .xml file
  int i;

  //-- initialize: globals
  prog = argv[0];

  //-- command-line: usage
  if (argc <= 2) {
    fprintf(stderr, "Usage: %s TFILE CXFILE BXFILE [OUTFILE [XMLBASE]]\n", prog);
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
  if (argc > 5) {
    xmlbase = argv[5];
  } else if (strcmp(filename_out,"-")==0) {
    xmlbase = NULL;
  } else {
    xmlbase = filename_out;
  }

  //-- print basic XML header
  fprintf(f_out, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
  fprintf(f_out, "<!--\n");
  fprintf(f_out, " ! File created by %s (%s v%s)\n", prog, PACKAGE, PACKAGE_VERSION);
  fprintf(f_out, " ! Command-line:");
  for (i=0; i < argc; i++) {
    fprintf(f_out, " %s", (argv[i][0] ? argv[i] : "''"));
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
    fprintf(f_out, " xml:base=\"%s\"", xmlbase);
  }
  fputc('>',f_out);

  //-- process .tt-format input data
  process_tt_file(f_in,f_out, filename_in,filename_out);

  //-- print footer
  fprintf(f_out, "%s</%s>\n", indent_root, docElt);

  //-- cleanup
  if (f_in)  fclose(f_in);
  if (f_cx)  fclose(f_cx);
  if (f_bx)  fclose(f_bx);
  if (f_out) fclose(f_out);

  return 0;
}
