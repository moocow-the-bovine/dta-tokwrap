#include "dtatwCommon.h"
#include "dtatwExpat.h"

/*======================================================================
 * Globals
 */

#define XMLID_BUFLEN 1024 //-- maximum w/@xml:id length

typedef struct {
  XML_Parser xp;            //-- expat parser
  FILE *f_out;              //-- output file
  char  w_id[XMLID_BUFLEN]; //-- buffer for xml:id of currently open 'w' element
  int w_depth;              //-- number of open 'w' elements
  int a_depth;              //-- number of open 'a' elements in open 'w' elements
} ParseData;

//-- indentation/formatting
const char *indent_root = "\n";
const char *indent_a    = "\n  ";


/*======================================================================
 * Handlers
 */

//--------------------------------------------------------------
void cb_start(ParseData *data, const XML_Char *name, const XML_Char **attrs)
{
  if (strcmp(name,"w")==0) {
    const XML_Char *xml_id;
    assert(data->w_depth==0 /* can't handle nested 'w' elements */);
    xml_id = get_attr("xml:id", attrs);
    assert(strlen(xml_id) < XMLID_BUFLEN /* id buffer overflow */);
    strcpy(data->w_id, xml_id);
    data->w_depth++;
  }
  else if (data->w_depth > 0 && strcmp(name,"a")==0) {
    assert(data->a_depth==0 /* can't handle nested 'a' elements */);
    fprintf(data->f_out, "%s<a xml:id=\"%s\"/>", indent_a, data->w_id);
    data->a_depth++;
  }
}

//--------------------------------------------------------------
void cb_end(ParseData *data, const XML_Char *name)
{
  if (data->w_depth > 0 && strcmp(name,"w")==0) {
    data->w_id[0] = '\0';
    data->w_depth--;
  }
  else if (data->a_depth > 0 && strcmp(name,"a")==0) {
    data->a_depth--;
  }
}

/*======================================================================
 * MAIN
 */
int main(int argc, char **argv)
{
  ParseData data;
  XML_Parser xp;
  char *filename_in  = "-";
  char *filename_out = "-";
  char *xmlbase = NULL;
  FILE *f_in  = stdin;   //-- input file
  FILE *f_out = stdout;  //-- output file
  int i;

  //-- initialize: globals
  prog = argv[0];

  //-- command-line: usage
  if (argc <= 1) {
    fprintf(stderr, "(%s version %s / %s)\n", PACKAGE, PACKAGE_VERSION, PACKAGE_SVNID);
    fprintf(stderr, "Usage:\n");
    fprintf(stderr, " %s INFILE [OUTFILE [XMLBASE]]\n", prog);
    fprintf(stderr, " + INFILE  : XML-ified tokenizer output file\n");
    fprintf(stderr, " + OUTFILE : token-analysis-level standoff XML file\n");
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
  fprintf(f_out, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
  fprintf(f_out, "<analyses xml:base=\"%s\">", (xmlbase ? xmlbase : ""));
  //--
  fprintf(f_out, "%s<!--\n", indent_root);
  fprintf(f_out, " ! File created by %s (%s version %s)\n", prog, PACKAGE, PACKAGE_VERSION);
  fprintf(f_out, " ! Command-line: %s", argv[0]);
  for (i=1; i < argc; i++) {
    fprintf(f_out, " '%s'", (argv[i][0] ? argv[i] : ""));
  }
  fprintf(f_out, "\n !-->\n");

  //-- parse input file
  expat_parse_file(xp, f_in, filename_in);

  //-- print footer
  fprintf(f_out, "%s</analyses>\n", indent_root);

  //-- cleanup
  if (f_in)  fclose(f_in);
  if (f_out) fclose(f_out);
  if (xp) XML_ParserFree(xp);

  return 0;
}
