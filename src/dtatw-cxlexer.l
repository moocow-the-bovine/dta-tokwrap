/*======================================================================
 * Flex Options
 */
/*%option outfile="dtatw-cxlexer.c"*/
%option header-file="dtatw-cxlexer.h"
%option 8bit

%{
/*======================================================================
 * User C-file definitions & prototypes
 */
#include "dtatwCommon.h"

#undef yywrap
static int yywrap(void);

#define CX_ID_MAXLEN     1024
#define CX_TEXT_MAXLEN   1024
#define CX_INT_MAXLEN      32

char cx_id[CX_ID_MAXLEN];
char cx_xoff[CX_INT_MAXLEN];
char cx_xlen[CX_INT_MAXLEN];
char cx_toff[CX_INT_MAXLEN];
char cx_tlen[CX_INT_MAXLEN];
char cx_text[CX_TEXT_MAXLEN];

//-- un-escapes src[0..srclen-1] to dst
void unescape_text_string(char *dst, char *src, int srclen);

%}

/*======================================================================
 * Start States
*/

%s XOFF XLEN TOFF TLEN TEXT ATEOF


/*======================================================================
 * Flex Definitions
 */

SEP     [\t\n]
NONSEP  [^\t\n]

/*======================================================================
 * Rules
 */
%%

<INITIAL>%%[^\n]*\n    { ; /* ignore comments */ }
<INITIAL>{NONSEP}*     { strcpy(cx_id,yytext); }
<INITIAL>{SEP}         { BEGIN(XOFF); }

<XOFF>{NONSEP}*        { /*cx_xoff = strtoul(yytext, NULL, 0);*/ strcpy(cx_xoff,yytext); }
<XOFF>{SEP}            { BEGIN(XLEN); }

<XLEN>{NONSEP}*        { /*cx_xlen = strtol(yytext, NULL, 0);*/ strcpy(cx_xlen,yytext); }
<XLEN>{SEP}            { BEGIN(TOFF); }

<TOFF>{NONSEP}*        { /*cx_toff = strtoul(yytext, NULL, 0);*/ strcpy(cx_toff,yytext); }
<TOFF>{SEP}            { BEGIN(TLEN); }

<TLEN>{NONSEP}*        { /*cx_tlen = strtol(yytext, NULL, 0);*/ strcpy(cx_tlen,yytext); }
<TLEN>{SEP}            { BEGIN(TEXT); }

<TEXT>{NONSEP}*        { assert(yyleng < CX_TEXT_MAXLEN); unescape_text_string(cx_text, yytext, yyleng); }
<TEXT>{SEP}            { BEGIN(INITIAL); return 1; }

\n          { BEGIN(INITIAL); return 1; }
.           { ; }
<<EOF>>     { return 0; }

%%
/*<<EOF>> { print_eos(); }*/

/*======================================================================
 * User C Code
 */

void unescape_text_string(char *dst, char *src, int srclen)
{
  int i,j;
  for (i=0,j=0; src[i] && i < srclen; i++,j++) {
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

static int yywrap(void)
{
  return 1;
}

#ifdef CXLEXER_MAIN
int main(int argc, char **argv)
{
  int rc;
  if (argc > 1) {
    if (!(yyin = fopen(argv[1],"rb"))) {
      fprintf(stderr, "%s: open failed for '%s': %s", *argv, argv[1], strerror(errno));
      exit(1);
    }
  } else {
    yyin = stdin;
  }
  while ((rc=yylex())) {
    printf("rc=%d, id={%s}, x={%lu %d}, t={%lu %d}, txt={%s}\n",
	   rc, cx_id, cx_xoff,cx_xlen, cx_toff,cx_tlen, cx_text);
  }
  return 0;
}
#endif /* CXLEXER_MAIN */
