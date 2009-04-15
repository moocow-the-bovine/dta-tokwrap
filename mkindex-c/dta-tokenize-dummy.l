/*======================================================================
 * Flex Options
 */
%option outfile="dta-tokenize-dummy.c"
%option 8bit

%{
/*======================================================================
 * User C Header
 */
#include <stdio.h>
#include <string.h>
#include <ctype.h>

typedef unsigned long int ByteOffset;

static ByteOffset thebyte=0;
static int lastWasEOS=1;

static void print_token(const char *typ);
static void print_eos(void);

%}

/*======================================================================
 * Start States
 */

%s ATEOF


/*======================================================================
 * Flex Definitions
 */

DIGIT    [0-9]
SPACE    [[:space:]\#]
PUNCT    [[:punct:]\#]
ALPHA    [[:alpha:]\#]
WORDC    [^[:space:][:digit:]]
ROMAN_DIGIT [IVXLCDM\#]
NEWLINE  [\n\r]

SENTBREAK \$SB\$
WORDBREAK \$[WT]B\$

ABBR     (Prof|Dr|[[:alpha:L]]|([[:alpha:][:alpha:]]))\.

/*======================================================================
 * Rules
 */
%%

{SPACE}  { thebyte += yyleng; /* (mostly) ignore */ }

{SENTBREAK}  { thebyte += yyleng; print_eos(); }
{WORDBREAK}  { thebyte += yyleng; }

{ROMAN_DIGIT}+\.? { print_token("$ROMAN"); thebyte += yyleng; }

{DIGIT}+\/{DIGIT}+         { print_token("$FRACTION"); thebyte += yyleng; }
{DIGIT}+{PUNCT}           { print_token("$CARDPUNCT"); thebyte += yyleng; }
{DIGIT}+{ALPHA}+          { print_token("$CARDSUFFIX"); thebyte += yyleng; }
({DIGIT}*[,\.]{DIGIT}+)+  { print_token("$CARDSEPS"); thebyte += yyleng; }
{DIGIT}+                  { print_token("$CARD");   thebyte += yyleng; }

(,,)|(``)|(\'\')|`|\'|\"  { print_token("$QUOTE"); thebyte += yyleng; }
(\-+)|(\_+)|(\.\.+)       { print_token("$PUNCT"); thebyte += yyleng; }

{WORDC}+\-{NEWLINE}+{WORDC}+ { print_token(NULL); thebyte += yyleng; }

{ABBR}             { print_token("$ABBR"); thebyte += yyleng; }
{ALPHA}+           { print_token(NULL); thebyte += yyleng; }

\.|\!|\?           { print_token("$."); thebyte += yyleng; }
\,|\:|\;           { print_token("$,"); thebyte += yyleng; }
{PUNCT}            { print_token("$PUNCT"); thebyte += yyleng; }

[^[:punct:][:digit:][:space:]]+ { print_token(NULL); thebyte += yyleng; }

<INITIAL><<EOF>>   { print_eos(); BEGIN(ATEOF); }

%%
/*<<EOF>> { print_eos(); }*/

/*======================================================================
 * User C Code
 */


static void print_token(const char *typ)
{
  int i;
  for (i=0; i < yyleng; i++) {
    if (yytext[i]=='-') {
      if (i+1 < yyleng && (yytext[i+1]=='\n' || yytext[i+1]=='\r')) {
	i++;
      } else {
	fputc('-',stdout);
      }
    }
    else if (yytext[i]=='\n' || yytext[i]=='\r') {
      ;
    }
    else if (isspace(yytext[i])) {
      fputc('_', stdout);
    }
    else {
      fputc(yytext[i],stdout);
    }
  }
  printf("\t%lu %d", thebyte, yyleng);
  if (typ != NULL) { fputc('\t',stdout); fputs(typ,stdout); }
  fputc('\n',stdout);
  lastWasEOS = 0;

  //-- check for EOS
  if (strcmp(yytext,".")==0 || strcmp(yytext,"?")==0 || strcmp(yytext,"!")==0) {
    print_eos();
  }
}

static void print_eos(void)
{
  if (lastWasEOS) return;
  fputc('\n',stdout);
  lastWasEOS = 1;
}
