#include <locale.h>
#include "dtatwCommon.h"
/*#include "dtatw-cxlexer.h"*/

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
  ByteLen    tlen;      //-- .tx byte length
  char      *text;      //-- output text
} cxRecord;

// CXDATA_INITIAL_ALLOC : original buffer size for cxdata[], in number of records
#define CXDATA_INITIAL_ALLOC 65536

// cxdata : cxRecord[ncxdata_alloc]
cxRecord *cxdata = NULL;
ByteOffset ncxdata_alloc = 0;  //-- number of records allocated in cxdata
ByteOffset ncxdata = 0;        //-- number of records used in cxdata (index of 1st unused record)

int cxRecordSize = sizeof(cxRecord);

#define STATIC inline static
//#define STATIC static
//#define STATIC

/*======================================================================
 * Utils: .cx file
 */
STATIC void initCxData(void)
{
  cxdata = (cxRecord*)malloc(CXDATA_INITIAL_ALLOC*sizeof(cxRecord));
  assert(cxdata != NULL /* memory full on malloc */);
  ncxdata_alloc = CXDATA_INITIAL_ALLOC;
  ncxdata = 0;
}

STATIC void pushCxRecord(cxRecord *cx)
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

#define INITIAL_LINEBUF_SIZE 8192
STATIC void loadCxFile(FILE *f)
{
  cxRecord cx;
  char *linebuf=NULL;
  size_t linebuf_alloc=0;
  ssize_t linelen;
  char *id_s, *xoff_s,*xlen_s, *toff_s,*tlen_s, *text_s;

  if (cxdata==NULL) initCxData();
  assert(f!=NULL /* require .cx file */);

  //-- init line buffer
  linebuf = (char*)malloc(INITIAL_LINEBUF_SIZE);
  assert(linebuf != NULL /* malloc failed */);
  linebuf_alloc = INITIAL_LINEBUF_SIZE;

  while ( (linelen=getline(&linebuf,&linebuf_alloc,f)) >= 0 ) {
    char *tail=NULL;
    if (linebuf[0]=='%' && linebuf[1]=='%') continue;  //-- skip comments

    id_s = linebuf;

    for (xoff_s=id_s;   *xoff_s && *xoff_s!='\t' && *xoff_s!='\n'; xoff_s++) ;
    *xoff_s='\0';
    xoff_s++;

    for (xlen_s=xoff_s; *xlen_s && *xlen_s!='\t' && *xlen_s!='\n'; xlen_s++) ;
    *xlen_s='\0';
    xlen_s++;

    for (toff_s=xlen_s; *toff_s && (*toff_s!='\t' && *toff_s!='\n'); toff_s++) ;
    *toff_s='\0';
    toff_s++;

    for (tlen_s=toff_s; *tlen_s && (*tlen_s!='\t' && *tlen_s!='\n'); tlen_s++) ;
    *tlen_s='\0';
    tlen_s++;

    for (text_s=tlen_s; *text_s && (*text_s!='\t' && *text_s!='\n'); text_s++) ;
    *text_s='\0';
    text_s++;

    if (linelen>0 && linebuf[linelen-1]=='\n') linebuf[linelen-1] = '\0';

    cx.id   = strdup(id_s);
    cx.xoff = strtoul(xoff_s,&tail,0);
    cx.xlen = strtol(xlen_s,&tail,0);
    cx.toff = strtoul(toff_s,&tail,0);
    cx.tlen = strtol(tlen_s,&tail,0);
    cx.text = strdup(text_s);

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
  setlocale(LC_ALL, "");
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
