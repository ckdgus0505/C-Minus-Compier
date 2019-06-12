/* ====================================================================== */

%{

typedef struct l_type_struct {	/* lex for var and num */
  char *lex;
} l_type;

typedef struct t_type_struct {  /* type for type_specifier */
  unsigned char type;
} t_type;

typedef struct r_type_struct {
  unsigned char regi;
} r_type;

typedef struct p_type_struct {
  unsigned int ip;
} p_type;



/* ====================================================================== */

#include "parser.h"
#include <string.h>

/* ====================================================================== */

#define	ACCEPT(x) return(x)
#define	ACCEPT_LEX(x) \
{ \
  yytext[yyleng] = '\0'; \
  lex = malloc(yyleng + 1); \
  strcpy(lex, yytext); \
  return(x); \
}

/* ====================================================================== */

char *lex;			/* current lexeme of ID or NUM */
int source_line_no = 1;		/* source line number */

/* ====================================================================== */

%}

%x				comment
digit				[0-9]
letter				[a-zA-Z]

%%

"void"              ACCEPT(VOID);
"int"               ACCEPT(INT);
"if"                ACCEPT(IF);
"else"              ACCEPT(ELSE);
"while"             ACCEPT(WHILE);
"return"            ACCEPT(RETURN);
"input"             ACCEPT(INPUT);
"output"            ACCEPT(OUTPUT);

"+"                 ACCEPT(PLUS);
"-"                 ACCEPT(MINUS);
"*"                 ACCEPT(MULTIPLY);
"/"                 ACCEPT(DIVIDE);
"<"                 ACCEPT(LT);
"<="                ACCEPT(LE);
">"                 ACCEPT(GT);
">="                ACCEPT(GE);
"=="                ACCEPT(EQ);
"!="                ACCEPT(NE);
"="                 ACCEPT(ASSIGN);
","                 ACCEPT(COMMA);
";"                 ACCEPT(SEMICOLON);
"("                 ACCEPT(LPAR);
")"                 ACCEPT(RPAR);
"{"                 ACCEPT(LBRACE);
"}"                 ACCEPT(RBRACE);
"["                 ACCEPT(LBRACKET);
"]"                 ACCEPT(RBRACKET);

({letter}|_)({letter}|{digit}|_)*   ACCEPT_LEX(ID);
{digit}{digit}*         ACCEPT_LEX(NUM);

" "
\t
\r
\n              ++source_line_no;

"/*"                BEGIN(comment);
<comment>[^*\n]*
<comment>"*"+[^*/\n]*
<comment>\n         ++source_line_no;
<comment>"*"+"/"        BEGIN(INITIAL);


"//".*$

.               ACCEPT_LEX(UNDEFINED);

%%

/* ====================================================================== */
