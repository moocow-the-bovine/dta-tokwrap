#include "dtatwCommon.h"
#include "dtatw-cxlexer.h"

/*======================================================================
 * Globals
 */

typedef struct {
  XML_Parser xp;        //-- expat parser
  FILE *f_out;          //-- output file
} ParseData;

typedef struct {
  char        *id;      //-- xml:id of source <c>
  ByteOffset xoff;      //-- original xml byte offset
  ByteLen    xlen;      //-- original xml byte length
  ByteOffset toff;      //-- .tx byte offset
  ByteOffset tlen;      //-- .tx byte length
  char      *text;      //-- output text
} cxRecord;

// CXDATA_INITIAL_ALLOC : original buffer size for cxdata[]
#define CXDATA_INITIAL_ALLOC 65536

// cxdata : cxRecord[ncxdata_alloc]
cxRecord *cxdata = NULL;
ByteOffset ncxdata_alloc = 0;
ByteOffset ncxdata = 0;

//-- definitions from dtatw-cxlexer.l, which I'm too stupid to get flex to export
extern char cx_id[];
extern char cx_xoff[];
extern char cx_xlen[];
extern char cx_toff[];
extern char cx_tlen[];
extern char cx_text[];

/*======================================================================
 * Utils: .cx file
 */
static void initCxData(void)
{
  cxdata = (cxRecord*)malloc(CXDATA_INITIAL_ALLOC*sizeof(ncxdata));
  assert(cxdata != NULL /* memory full on malloc */);
  ncxdata_alloc = CXDATA_INITIAL_ALLOC;
  ncxdata = 0;
}

static void pushCxRecord(cxRecord *cx)
{
  if (ncxdata+1 >= ncxdata_alloc) {
    //-- whoops: must reallocate
    cxdata = (cxRecord*)realloc(cxdata, ncxdata_alloc*2);
    assert(cxdata != NULL /* memory full on realloc */);
    ncxdata_alloc *= 2;
  }
  //-- just push, strdup()ing strings
  memcpy(cxdata+ncxdata, cx, sizeof(cxRecord));
  if (cx->id)   cxdata[ncxdata].id   = strdup(cx->id);
  if (cx->text) cxdata[ncxdata].text = strdup(cx->text);
  ncxdata++;
}

static void loadCxFile(FILE *f)
{
  cxRecord cx;
  if (cxdata==NULL) initCxData();

  assert(f!=NULL /* require .cx file */);
  yyin = f;
  cx.id   = cx_id;
  cx.text = cx_text;
  while (yylex()) {
    cx.xoff = strtoul(cx_xoff,NULL,0);
    cx.xlen = strtol (cx_xlen,NULL,0);
    cx.toff = strtoul(cx_toff,NULL,0);
    cx.tlen = strtol (cx_tlen,NULL,0);
    pushCxRecord(&cx);
  }
}


/*======================================================================
 * Expat Handlers
 */

//--------------------------------------------------------------
void cb_start(ParseData *data, const XML_Char *name, const XML_Char **attrs)
{
  return;
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
  char *filename_in  = "-";
  char *filename_cx  = NULL;
  char *filename_out = "-";
  char *xmlbase = NULL;
  FILE *f_in  = stdin;   //-- input .t file
  FILE *f_cx  = NULL;    //-- input .cx file
  FILE *f_out = stdout;  //-- output .xml file

  //-- initialize: globals
  prog = argv[0];

  //-- command-line: usage
  if (argc <= 2) {
    fprintf(stderr, "Usage: %s TFILE CXFILE [OUTFILE [XMLBASE]]\n", prog);
    fprintf(stderr, " + TFILE   : raw tokenizer output file\n");
    fprintf(stderr, " + CXFILE  : character index file as created by dtatw-mkindex\n");
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
  //-- command-line: output file
  if (argc > 3) {
    filename_out = argv[3];
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
  if (argc > 4) {
    xmlbase = argv[4];
  } else {
    xmlbase = filename_out;
  }

  //-- load cx file
  initCxData();
  loadCxFile(f_cx);
  fclose(f_cx);
  exit(0); //-- debug

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
	  "<sentences xml:base=\"%s\">",
	  (xmlbase ? xmlbase : "")
	  );

  //-- parse input file
  expat_parse_file(xp, f_in, filename_in);

  //-- print footer
  fprintf(f_out, "%s</sentences>\n", ""/*indent_root*/);

  //-- cleanup
  if (f_in)  fclose(f_in);
  //if (f_cx)  fclose(f_cx);
  if (f_out) fclose(f_out);
  if (xp) XML_ParserFree(xp);

  return 0;
}
