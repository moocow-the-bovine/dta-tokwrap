#include "dtatwCommon.h"
#include "dtatwExpat.h"

/*======================================================================
 * Globals
 */

// VERBOSE_IO : whether to print progress messages for load/save
#define VERBOSE_IO 1
//#undef VERBOSE_IO

// VERBOSE_INIT : whether to print progress messages for initialize & allocate
#if VERBOSE_IO
# define VERBOSE_INIT 1
#else
# undef VERBOSE_INIT
#endif

// CXML_ADJACENCY_TOLERANCE
//  + number of bytes which may appear between end of one <c> and beginning of the next <c>
//    while still allowing them to be considered "adjacent"
//  + no guarantee is made for the content of such bytes, if they exist!
//  + a value of 0 (zero) gives a safe, strict adjanency criterion
//  + a value of 1 (one) allows e.g. UNIX-style newlines ("\n") between <c>s
//  + a value of 2 (two) allows e.g. DOS-style newlines ("\r\n") between <c>s
//  + a value of 7 (secen) allows e.g. redundantly coded ("<lb/>\r\n") between <c>s
#define CXML_ADJACENCY_TOLERANCE 0

//-- xml structure constants (should jive with 'tok2xml')
const char *sElt   = "s";          //-- .t.xml sentence element
const char *wElt   = "w";          //-- .t.xml token element
const char *posAttr = "b";         //-- .t.xml byte-position attribute
const char *cAttr    = "c";        //-- .t.xml token-chars attribute (space-separated xml:ids from .cx file)
const char *idAttr   = "xml:id";   //-- .t.xml id attribute

/*======================================================================
 * Utils: .cx, .tx, .bx files (see also dtatwCommon.[ch])
 */
cxData cxdata = {NULL,0,0};       //-- cxRecord *cx = &cxdata->data[c_index]
bxData bxdata = {NULL,0,0};       //-- bxRecord *bx = &bxdata->data[block_index]

Offset2CxIndex txb2cx = {NULL,0};   //-- cxRecord *cx =  txb2cx->data[ tx_byte_index]
Offset2CxIndex txtb2cx = {NULL,0};  //-- cxRecord *cx = txtb2cx->data[txt_byte_index]

/*======================================================================
 * Utils: .t.xml file(s): general
 */

//--------------------------------------------------------------

// TXML_ID_BUFLEN : buffer length for IDs in fixed-with token records
#define TXML_ID_BUFLEN 16

typedef struct {
  char        s_id[TXML_ID_BUFLEN];   //-- xml:id of this sentence
} txmlSentence;

typedef struct {
  ByteOffset  s_i;                    //-- index of sentence claiming this token
  char        w_id[TXML_ID_BUFLEN];   //-- xml:id of this token
} txmlToken;


typedef struct {
  txmlSentence *sdata;     //-- sentence data vector
  ByteOffset    slen;      //-- number of populated sentence records
  ByteOffset    salloc;    //-- number of allocated sentence records
  //
  txmlToken    *wdata;     //-- token data vector
  ByteOffset    wlen;      //-- number of populated token records
  ByteOffset    walloc;    //-- number of allocated token records
} txmlData;

#ifndef TXML_DEFAULT_SALLOC
# define TXML_DEFAULT_SALLOC 8192
#endif
#ifndef TXML_DEFAULT_WALLOC
# define TXML_DEFAULT_WALLOC 8192
#endif

//-- txmlToken     *tok = &txmldata->wdata[token_index]
//-- txmlSentence *sent = &txmldata->sdata[sentence_index]
txmlData txmldata = { NULL,0,0, NULL,0,0 };

//--------------------------------------------------------------
typedef enum {
  cxafNone    = 0x0000,  //-- nothing special
  //
  cxafWAny    = 0x0001,  //-- set iff this <c> is claimed by some <w>
  cxafWBegin  = 0x0002,  //-- set iff this is first <c> of the claiming <w>
  cxafWxBegin = 0x0004,  //-- set iff this is first <c> of some segment of the claiming <w>
  cxafWxEnd   = 0x0008,  //-- set iff this is last  <c> of some segment of the claiming <w>
  cxafWEnd    = 0x0010,  //-- set iff this is last  <c> of the claiming <w>
  //
  cxafSAny    = 0x0100,  //-- set iff this <c> is claimed by some <s>
  cxafSBegin  = 0x0200,  //-- set iff this is first <c> of the claiming <s>
  cxafSxBegin = 0x0400,  //-- set iff this is first <c> of some segment of the claiming <s>
  cxafSxEnd   = 0x0800,  //-- set iff this is last  <c> of some segment of the claiming <s>
  cxafSEnd    = 0x1000,  //-- set iff this is last  <c> of the claiming <s>
  cxafAll     = 0xffff   //-- mask of all known flags
} cxAuxFlagsE;
typedef unsigned int cxAuxFlags;

typedef struct {
  ByteOffset  w_i;       //-- index of token claiming this <c> [NOT a pointer, since realloc() invalidates those!]
  cxAuxFlags flags;      //-- mask of 'cxaf*' flags
} cxAuxRecord;

cxAuxRecord  *cxaux = NULL; //-- cxAuxRecord *cxa = &cxaux[c_index]

//--------------------------------------------------------------
txmlData *txmlDataInit(txmlData *txd, size_t sent_size, size_t tok_size)
{
  //-- init: txd
  if (!txd) {
    txd = (txmlData*)malloc(sizeof(txmlData));
    assert(txd != NULL /* malloc failed */);
  }

  //-- init: sentences
  if (sent_size==0) sent_size = TXML_DEFAULT_SALLOC;
  txd->sdata = (txmlSentence*)malloc(sent_size*sizeof(txmlSentence));
  assert(txd->sdata != NULL /* malloc failed */);
  txd->slen   = 0;
  txd->salloc = sent_size;

  //-- init: tokens
  if (tok_size==0) tok_size = TXML_DEFAULT_WALLOC;
  txd->wdata = (txmlToken*)malloc(tok_size*sizeof(txmlToken));
  assert(txd->wdata != NULL /* malloc failed */);
  txd->wlen   = 0;
  txd->walloc = tok_size;

  //-- return
  return txd;
}

//--------------------------------------------------------------
txmlSentence *txmlDataPushSentence(txmlData *txd, txmlSentence *sx)
{
  if (txd->slen+1 >= txd->salloc) {
    //-- whoops: must reallocate
    txd->sdata = (txmlSentence*)realloc(txd->sdata, txd->salloc*2*sizeof(txmlSentence));
    assert(txd->sdata != NULL /* realloc failed */);
    txd->salloc *= 2;
  }
  //-- just copy raw data, pointers & all
  //  + i.e. if you need a pointer copied, do it before calling this function!
  memcpy(&txd->sdata[txd->slen], sx, sizeof(txmlSentence));
  return &txd->sdata[txd->slen++];
}

//--------------------------------------------------------------
txmlToken *txmlDataPushToken(txmlData *txd, txmlToken *tx)
{
  if (txd->wlen+1 >= txd->walloc) {
    //-- whoops: must reallocate
    txd->wdata = (txmlToken*)realloc(txd->wdata, txd->walloc*2*sizeof(txmlToken));
    assert(txd->wdata != NULL /* realloc failed */);
    txd->walloc *= 2;
  }
  //-- just copy raw data, pointers & all
  //  + i.e. if you need a pointer copied, do it before calling this function!
  memcpy(&txd->wdata[txd->wlen], tx, sizeof(txmlToken));
  return &txd->wdata[txd->wlen++];
}


//--------------------------------------------------------------
typedef struct {
  XML_Parser   xp;             //-- underlying expat parser
  txmlData    *txd;            //-- vector of token records being populated
  txmlToken    w_cur;          //-- temporary token being parsed
  txmlSentence s_cur;          //-- temporary sentence being parsed          
  int          saw_s_start;    //-- whether we need to mark the next char as sentence-initial (cxafSBegin)
  cxAuxRecord *cxa;            //-- last cx aux record to have been parsed & pushed, for marking sentence-final (cxafSEnd)
} txmlParseData;

//--------------------------------------------------------------
void txml_cb_start(txmlParseData *data, const XML_Char *name, const XML_Char **attrs)
{
  if (strcmp(name,sElt)==0) {
    //-- s: parse relevant attribute(s)
    const XML_Char *s_id = get_attr(idAttr, attrs);
    if (s_id) {
      assert2((strlen(s_id) < TXML_ID_BUFLEN), "buffer overflow for s/@xml:id");
      strcpy(data->s_cur.s_id,s_id);
    } else {
      data->s_cur.s_id[0] = '\0';
    }
    data->saw_s_start = 1;
    data->w_cur.s_i   = data->txd->slen;
    txmlDataPushSentence(data->txd, &data->s_cur);
  }
  else if (strcmp(name,wElt)==0) {
    //-- w: parse relevant attribute(s)
    const XML_Char *w_id=NULL, *w_loc=NULL; //, *w_c=NULL
    char *w_loc_tail;
    ByteOffset w_txtoff, w_txtlen;
    ByteOffset w_i;
    int i;
    for (i=0; attrs[i] && (!w_id || !w_loc); i += 2) {
      if      (strcmp(attrs[i],  idAttr)==0) w_id =attrs[i+1];
      else if (strcmp(attrs[i], posAttr)==0) w_loc=attrs[i+1];
    }

    //-- w: populate token record
    if (w_id) {
      assert2((strlen(w_id) < TXML_ID_BUFLEN), "buffer overflow for w/@xml:id");
      strcpy(data->w_cur.w_id, w_id);
    } else {
      data->w_cur.w_id[0] = '\0';
    }

    //-- w: push token record
    w_i = data->txd->wlen;
    txmlDataPushToken(data->txd, &data->w_cur);

    //-- w: parse .txt location
    w_txtoff = strtoul(w_loc,      &w_loc_tail, 0);
    w_txtlen = strtoul(w_loc_tail, NULL,        0);

    //-- w: populate cxaux
    // + note that we don't actually parse the c-ids from the 'c' attribute
    // + rather, we iterate lookup in a handy index vector (txtb2cx->data[])
    // + advantage: O(1) lookup for each <c>, so O(length(w.text)) for each token <w>
    // + disadvantage: requires that our indices (.t.xml, .cx, .bx) are consistent with the input file (.char.xml)
    for (i=0; i < w_txtlen; i++) {
      cxRecord *cx = txtb2cx.data[w_txtoff+i];
      if (cx != NULL) {
	cxAuxRecord *cxa = &cxaux[ cx - cxdata.data ];
	cxa->w_i    = w_i;
	cxa->flags |= cxafWAny;
	cxa->flags |= cxafSAny; //-- hack: we're just blithely assuming all <w>s are claimed by valid <s>s

	//-- cxa flags: WBegin, SBegin
	if (i==0) {
          cxa->flags |= cxafWBegin;
	  if (data->saw_s_start) {
	    cxa->flags |= cxafSBegin;
	    data->saw_s_start = 0;
	  }
	}

	//-- cxa flags: WEnd
	if (i==w_txtlen-1) {
	  cxa->flags |= cxafWEnd;
	}

	//-- update
	data->cxa = cxa;
      }
    }
  }
  return;
}

//--------------------------------------------------------------
void txml_cb_end(txmlParseData *data, const XML_Char *name)
{
  if (strcmp(name,sElt)==0) {
    //-- mark last parsed 'cxa' as sentence-final
    if (data->cxa) data->cxa->flags |= cxafSEnd;
  }
  return;
}


//--------------------------------------------------------------
txmlData *txmlDataLoad(txmlData *txd, FILE *f, const char *filename)
{
  XML_Parser xp;
  txmlParseData data;

  //-- maybe (re-)initialize indices
  if (txd==NULL || txd->sdata==NULL || txd->wdata==NULL) txd=txmlDataInit(txd,0,0);
  assert(f != NULL /* require .t.xml file */);
  assert(cxdata.data != NULL && cxdata.len > 0 /* require non-empty cx data */);
  assert(cxaux != NULL /* require cxaux data */);
  assert(txtb2cx.len > 0 /* require populated txtb2cx index */);

  //-- setup expat parser
  xp = XML_ParserCreate("UTF-8");
  assert2((xp != NULL), "XML_ParserCreate() failed");
  XML_SetUserData(xp, &data);
  XML_SetElementHandler(xp, (XML_StartElementHandler)txml_cb_start, (XML_EndElementHandler)txml_cb_end);

  //-- setup callback data
  memset(&data,0,sizeof(data));
  data.xp  = xp;
  data.txd = txd;

  //-- parse XML
  expat_parse_file(xp, f, filename);

  return txd;
}

/*======================================================================
 * Misc
 */

//--------------------------------------------------------------
ByteOffset mark_discontinuous_segments(txmlData *txmld, bxData *bxd, cxData *cxd, cxAuxRecord *cxaux)
{
  ByteOffset txtbi, ndiscont=0;
  bxRecord    *bx;
  cxRecord    *cx,  *cx_prev=NULL;
  cxAuxRecord *cxa, *cxa_prev=NULL;
  txmlToken    *w,  *w_prev=NULL;
  txmlSentence *s,  *s_prev=NULL;

  //-- sanity checks
  assert(txmld != NULL);
  assert(bxd   != NULL);
  assert(cxd   != NULL);
  assert(cxaux != NULL);
  //
  assert(txmld->wdata != NULL);
  assert(txmld->sdata != NULL);
  assert(bxd->data    != NULL);
  assert(cxd->data    != NULL);

  //-- we iterate over (serialized) .txt-byte indices: this gets us the token- and sentence-order

  //-- scan for first <c>
  for (cx_prev=NULL,txtbi=0; cx_prev==NULL && txtbi < txtb2cx.len; txtbi++) {
    cx_prev = txtb2cx.data[txtbi];
  }
  cxa_prev = &cxaux[ cx_prev - &cxd->data[0] ];
  w_prev   = NULL;
  s_prev   = NULL;

  //-- ye olde loope
  //  + visit <c> elements in same order as tokenizer did
  //  + i.e. (".bx" | ".txt" | ".t" | ".t.xml")-file document order
  //  + specifically NOT ".char.xml"-file document order
  for ( ; txtbi < txtb2cx.len; txtbi++) {
    cx  = txtb2cx.data[txtbi];
    if (cx==NULL)    continue;  //-- ignore "hints" & any other non-<c> stuff in .txt file
    if (cx==cx_prev) continue;  //-- skip multibyte-<c>s we've already considered
    cxa = &cxaux[ cx - &cxd->data[0] ];

    //-- get current token- and sentence-pointers
    if ( cxa->flags & cxafWAny ) {
      w = &txmld->wdata[cxa->w_i];
      s = &txmld->sdata[w->s_i];
    } else {
      w = NULL;
      s = NULL;
    }

    //-- check for discontinuity
    if ( cx->xoff > cx_prev->xoff + cx_prev->xlen + CXML_ADJACENCY_TOLERANCE ) {

      //-- discontinuity detected: token discontinuity?
      if ( w && w==w_prev ) {
	ndiscont++;
	cxa->flags      |= cxafWxBegin;
	cxa_prev->flags |= cxafWxEnd;
#if 1
	fprintf(stderr, "w discontinuity[%s/%s] (tol=%d): c=%s[%lu..%lu] ...[+%lu]... c=%s[%lu..%lu] \n",
		(s ? s->s_id: "(null)"), (w ? w->w_id : "(null)"), CXML_ADJACENCY_TOLERANCE,
		cx_prev->id, cx_prev->xoff, (cx_prev->xoff+cx_prev->xlen),
		(cx->xoff - cx_prev->xoff+cx_prev->xlen),
		cx->id, cx->xoff, (cx->xoff+cx->xlen));
#endif
      }

      //-- discontinuity detected: sentence discontinuity?
      if ( s && s==s_prev ) {
	ndiscont++;
	cxa->flags      |= cxafSxBegin;
	cxa_prev->flags |= cxafSxEnd;
#if 1
	fprintf(stderr, "s discontinuity[%s/%s] (tol=%d): c=%s[%lu..%lu] ...[+%lu]... c=%s[%lu..%lu] \n",
		(s ? s->s_id: "(null)"), (w ? w->w_id : "(null)"), CXML_ADJACENCY_TOLERANCE,
		cx_prev->id, cx_prev->xoff, (cx_prev->xoff+cx_prev->xlen),
		(cx->xoff - cx_prev->xoff+cx_prev->xlen),
		cx->id, cx->xoff, (cx->xoff+cx->xlen));
#endif
      }
    }

    //-- update
    cx_prev  = cx;
    cxa_prev = cxa;
    w_prev   = w;
    s_prev   = s;
  }

  return ndiscont;
}


/*======================================================================
 * MAIN
 */
int main(int argc, char **argv)
{
  char *filename_txml = "-";
  char *filename_cxml = NULL;
  char *filename_cx   = NULL;
  char *filename_bx   = NULL;
  char *filename_out  = "-";
  char *xmlsuff = "";    //-- additional suffix for root @xml:base
  FILE *f_txml = stdin;   //-- input .t.xml file
  FILE *f_cxml = NULL;    //-- input .char.xml file
  FILE *f_cx   = NULL;    //-- input .cx file
  FILE *f_bx   = NULL;    //-- input .bx file
  FILE *f_out  = stdout;  //-- output .char.sw.xml file
  int i;
  ByteOffset ndiscont;

  //-- initialize: globals
  prog = argv[0];

  //-- command-line: usage
  if (argc <= 4) {
    fprintf(stderr, "(%s version %s / %s)\n", PACKAGE, PACKAGE_VERSION, PACKAGE_SVNID);
    fprintf(stderr, "Usage:\n");
    fprintf(stderr, " %s TXMLFILE CXMLFILE CXFILE BXFILE [OUTFILE]\n", prog);
    fprintf(stderr, " + TXMLFILE : xml tokenizer output as created by dtatw-tok2xml\n");
    fprintf(stderr, " + CXMLFILE : base-format .chr.xml input file\n");
    fprintf(stderr, " + CXFILE   : character index file as created by dtatw-mkindex\n");
    fprintf(stderr, " + BXFILE   : block index file as created by dta-tokwrap.perl\n");
    fprintf(stderr, " + OUTFILE  : output XML file (default=stdout)\n");
    fprintf(stderr, " + \"-\" may be used in place of any filename to indicate standard (in|out)put\n");
    exit(1);
  }

  //-- command-line: .t.xml file
  if (argc > 1) {
    filename_txml = argv[1];
    if (strcmp(filename_txml,"-")==0) f_txml = stdin;
    else if ( !(f_txml=fopen(filename_txml,"rb")) ) {
      fprintf(stderr, "%s: open failed for input .t.xml file `%s': %s\n", prog, filename_txml, strerror(errno));
      exit(1);
    }
  }

  //-- command-line: .char.xml file
  if (argc > 2) {
    filename_cxml = argv[2];
    if (strcmp(filename_cxml,"-")==0) f_cxml = stdin;
    else if ( !(f_cxml=fopen(filename_cxml,"rb")) ) {
      fprintf(stderr, "%s: open failed for input .cx file `%s': %s\n", prog, filename_cxml, strerror(errno));
      exit(1);
    }
  }

  //-- command-line: .cx file
  if (argc > 3) {
    filename_cx = argv[3];
    if (strcmp(filename_cx,"-")==0) f_cx = stdin;
    else if ( !(f_cx=fopen(filename_cx,"rb")) ) {
      fprintf(stderr, "%s: open failed for input .cx file `%s': %s\n", prog, filename_cx, strerror(errno));
      exit(1);
    }
  }

  //-- command-line: .bx file
  if (argc > 4) {
    filename_bx = argv[4];
    if (strcmp(filename_bx,"-")==0) f_bx = stdin;
    else if ( !(f_bx=fopen(filename_bx,"rb")) ) {
      fprintf(stderr, "%s: open failed for input .bx file `%s': %s\n", prog, filename_bx, strerror(errno));
      exit(1);
    }
  }

  //-- command-line: output file
  if (argc > 5) {
    filename_out = argv[5];
    if (strcmp(filename_out,"")==0) f_out = NULL;
    else if ( strcmp(filename_out,"-")==0 ) f_out = stdout;
    else if ( !(f_out=fopen(filename_out,"wb")) ) {
      fprintf(stderr, "%s: open failed for output XML file `%s': %s\n", prog, filename_out, strerror(errno));
      exit(1);
    }
  }

  //-- load .cx data
  cxDataLoad(&cxdata, f_cx);
  fclose(f_cx);
  f_cx = NULL;
#ifdef VERBOSE_IO
  fprintf(stderr, "%s: loaded %lu records from .cx file '%s'\n", prog, cxdata.len, filename_cx);
#endif

  //-- load .bx data
  bxDataLoad(&bxdata, f_bx);
  if (f_bx != stdin) fclose(f_bx);
  f_bx = NULL;

#ifdef VERBOSE_IO
  fprintf(stderr, "%s: loaded %lu records from .bx file '%s'\n", prog, bxdata.len, filename_bx);
#endif
  
  //-- create (tx_byte_index => cx_record) lookup vector
  tx2cxIndex(&txb2cx, &cxdata);
#ifdef VERBOSE_INIT
  fprintf(stderr, "%s: initialized %lu-element .tx-byte => .cx-record index\n", prog, txb2cx.len);
#endif

  //-- create (txt_byte_index => cx_record_or_NULL) lookup vector
 txt2cxIndex(&txtb2cx, &bxdata, &txb2cx);
#ifdef VERBOSE_INIT
  fprintf(stderr, "%s: initialized %lu-element .txt-byte => .cx-record index\n", prog, txtb2cx.len);
#endif

  //-- allocate (c_index => cxAuxRecord) lookup vector
  cxaux = (cxAuxRecord*)malloc(cxdata.len*sizeof(cxAuxRecord));
  assert2( (cxaux!=NULL), "malloc failed");
  memset(cxaux, 0, cxdata.len*sizeof(cxAuxRecord)); //-- ... and zero the block
#ifdef VERBOSE_INIT
  fprintf(stderr, "%s: allocated %lu-element auxilliary .cx-record index\n", prog, cxdata.len);
#endif

  //-- load .t.xml data (expat)
  txmlDataLoad(&txmldata, f_txml, filename_txml);
#ifdef VERBOSE_IO
  fprintf(stderr, "%s: parsed %lu tokens in %lu sentences from .t.xml file '%s'\n", prog, txmldata.wlen, txmldata.slen, filename_txml);
#endif

  //-- mark discontinuous segments
  ndiscont = mark_discontinuous_segments(&txmldata, &bxdata, &cxdata, cxaux);
#ifdef VERBOSE_INIT
  fprintf(stderr, "%s: found %lu discontinuities\n", prog, ndiscont);
#endif

  //-- CONTINUE HERE: NOW WHAT ?!

  //-- cleanup
  if (f_txml && f_txml != stdin) fclose(f_txml);
  if (f_cxml && f_cxml != stdin) fclose(f_cxml);
  if (f_cx   && f_cx   != stdin) fclose(f_cx);
  if (f_bx   && f_bx   != stdin) fclose(f_bx);
  if (f_out  && f_out  != stdout) fclose(f_out);

  return 0;
}
