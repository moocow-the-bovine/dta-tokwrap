#include "dtatwCommon.h"
#include "dtatwExpat.h"

/*======================================================================
 * Globals
 */

typedef struct {
  XML_Parser xp;        //-- expat parser
  unsigned d_cur;
  unsigned d_max;
} ParseData;

/*======================================================================
 * Utils
 */


/*======================================================================
 * Handlers
 */

//--------------------------------------------------------------
void cb_start(ParseData *data, const XML_Char *name, const XML_Char **attrs)
{
  ++data->d_cur;
  if (data->d_cur > data->d_max) data->d_max = data->d_cur;
}

//--------------------------------------------------------------
void cb_end(ParseData *data, const XML_Char *name)
{
  --data->d_cur;
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
  FILE *f_in  = stdin;   //-- input file
  FILE *f_out = stdout;  //-- output file

  //-- initialize: globals
  prog = file_basename(NULL,argv[0],"",-1,0);

  //-- command-line: usage
  if (argc <= 1) {
    fprintf(stderr, "(%s version %s / %s)\n", PACKAGE, PACKAGE_VERSION, PACKAGE_SVNID);
    fprintf(stderr, "Usage:\n");
    fprintf(stderr, " %s INFILE [OUTFILE]\n", prog);
    fprintf(stderr, " + INFILE  : XML source file\n");
    fprintf(stderr, " + OUTFILE : output file\n");
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
  data.xp  = xp;
  data.d_cur = 0;
  data.d_max = 0;

  //-- parse input file
  expat_parse_file(xp, f_in, filename_in);

  //-- report
  fprintf(f_out, "%u\t%s\n", data.d_max, filename_in);

  //-- cleanup
  if (f_in)  fclose(f_in);
  if (f_out) fclose(f_out);
  if (xp) XML_ParserFree(xp);

  return 0;
}
