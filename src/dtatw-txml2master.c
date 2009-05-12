#include "dtatwCommon.h"
#include "dtatwExpat.h"

/*======================================================================
 * Globals
 */

// VERBOSE_IO : whether to print progress messages for load/save
//#define VERBOSE_IO 1
#undef VERBOSE_IO

// WARN_ON_OVERLAP : whether to output warnings when token overlap is detected
//  + whether or not this is defined, an "overlap" attribute will be written
//    for overlapping tokens if 'olAttr' is non-NULL (see xml structure constants, below)
//#define WARN_ON_OVERLAP 1
#undef WARN_ON_OVERLAP

//-- xml structure constants (should jive with 'mkbx0', 'mkbx')
const char *sElt   = "s";          //-- output sentence element
const char *wElt   = "w";          //-- output token element

/*======================================================================
 * Utils: .cx file: see dtatwCommon.[ch]
 */
cxData cxdata = {NULL,0,0};


/*======================================================================
 * Utils: .t.xml file(s): general
 */

//--------------------------------------------------------------
typedef struct {
  char *w_id;   //-- xml:id of this token
  char *s_id;   //-- xml:id of the parent sentence
  cxRecord *cx; //-- vector of pointers to associated cx records (NULL-terminated)
} txmlToken;

typedef struct {
  txmlToken *data;
  ByteOffset len;
  ByteOffset alloc;
} txmlData;

#ifndef TXML_DEFAULT_ALLOC
# define TXML_DEFAULT_ALLOC 8192
#endif

//--------------------------------------------------------------
txmlData *txmlDataInit(txmlData *txd, ByteOffset size)
{
  if (size==0) size = TXML_DEFAULT_ALLOC;
  if (!txd) {
    txd = (txmlData*)malloc(sizeof(txmlData));
    assert(txd != NULL /* malloc failed */);
  }
  txd->data = (txmlToken*)malloc(size*sizeof(txmlToken));
  assert(txd->data != NULL /* malloc failed */);
  txd->len   = 0;
  txd->alloc = size;
  return txd;
}

//--------------------------------------------------------------
txmlData *txmlDataPush(txmlData *txd, txmlToken *tx)
{
  if (txd->len+1 >= txd->alloc) {
    //-- whoops: must reallocate
    txd->data = (txmlToken*)realloc(txd->data, txd->alloc*2*sizeof(txmlToken));
    assert(txd->data != NULL /* realloc failed */);
    txd->alloc *= 2;
  }
  //-- just push copy raw data, pointers & all
  memcpy(&txd->data[txd->len], bx, sizeof(txmlToken));
  return &txd->data[txd->len++];
}

//--------------------------------------------------------------
#define ID_BUFLEN 256
typedef struct {
  XML_Parser xp;         //-- underlying expat parser
  txmlData *txd;         //-- token data
  char s_id[ID_BUFLEN];  //-- @xml:id of current <s>, or empty
  char w_id[ID_BUFLEN];  //-- @xml:id of current <w>, or empty
} txmlParseData;

//--------------------------------------------------------------
void txml_cb_start(txmlParseData *data, const XML_Char *name, const XML_Char **attrs)
{
  if (strcmp(name,"s")==0) {
    //-- s: parse relevant attribute(s)
    const XML_Char *s_id = get_attr("xml:id", attrs);
    if (s_id) {
      assert(strlen(s_id) < ID_BUFLEN /* buffer overflow */);
      strcpy(data->s_id,s_id);
    } else {
      data->s_id[0] = '\0';
    }
  }
  else if (strcmp(name,"w")==0) {
    //-- w: parse relevant attribute(s)
    const XML_Char *w_id=NULL, *w_c=NULL;
    txmlToken tok = { NULL, NULL, NULL };
    int i;
    for (i=0; attrs[i] && (!w_id || !w_c); i += 2) {
      if      (strcmp(attrs[i],"xml:id")==0) w_id=attrs[i+1];
      else if (strcmp(attrs[i],"c")==0)      w_c =attrs[i+1];
    }
    //-- TODO: what now?!
  }
}


//--------------------------------------------------------------
txmlData *txmlDataLoad(txmlData *txd, FILE *f, const char *filename)
{
  assert(0 /* not yet implemented */);

  //-- maybe (re-)initialize
  if (txd==NULL || txd->data==NULL) txd=txmlDataInit(txd,0);
  assert(f != NULL /* require .t.xml file */);

  expat_parse_file(xp, f_in, filename);
  return txd;
}

/*======================================================================
 * MAIN
 */
int main(int argc, char **argv)
{
  char *filename_txml = "-";
  char *filename_cxml = NULL;
  char *filename_cx   = NULL;
  char *filename_out  = "-";
  char *xmlsuff = "";    //-- additional suffix for root @xml:base
  FILE *f_txml = stdin;   //-- input .t.xml file
  FILE *f_cxml = NULL;    //-- input .char.xml file
  FILE *f_cx   = NULL;    //-- input .cx file
  FILE *f_out  = stdout;  //-- output .char.sw.xml file
  int i;

  //-- initialize: globals
  prog = argv[0];

  //-- command-line: usage
  if (argc <= 3) {
    fprintf(stderr, "(%s version %s / %s)\n", PACKAGE, PACKAGE_VERSION, PACKAGE_SVNID);
    fprintf(stderr, "Usage:\n");
    fprintf(stderr, " %s TXMLFILE CXMLFILE CXFILE [OUTFILE]\n", prog);
    fprintf(stderr, " + TXMLFILE : xml tokenizer output as created by dtatw-tok2xml\n");
    fprintf(stderr, " + CXMLFILE : base-format .chr.xml input file\n");
    fprintf(stderr, " + CXFILE   : character index file as created by dtatw-mkindex\n");
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
    if ( !(f_cx=fopen(filename_cx,"rb")) ) {
      fprintf(stderr, "%s: open failed for input .cx file `%s': %s\n", prog, filename_cx, strerror(errno));
      exit(1);
    }
  }

  //-- command-line: output file
  if (argc > 4) {
    filename_out = argv[4];
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
  fprintf(stderr, "%s: parsed %lu records from .cx file '%s'\n", prog, cxdata->len, filename_cx);
#endif
  
  //-- create (tx_byte_index => cx_record) lookup vector
  tx2cxIndex(&txb2cx, &cxdata);
#ifdef VERBOSE_IO
  fprintf(stderr, "%s: initialized %lu-element .tx-byte => .cx-record index\n", prog, txb2cx->len);
#endif


  //-- cleanup
  if (f_txml) fclose(f_txml);
  if (f_cxml) fclose(f_cxml);
  if (f_cx)   fclose(f_cx);
  if (f_out)  fclose(f_out);

  return 0;
}
