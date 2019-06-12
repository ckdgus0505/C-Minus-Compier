/* ====================================================================== */

%{

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include "symbol.c"

/* ====================================================================== */

#define MAX_NO_CODES	1024	/* maximum number of codes generated */
#define MAX_LINE	256	/* max code line length */
#define NO_TMP_REGIS	27	/* r0 ~ r26 for temporaly registers */
#define REGI_RETURN	27	/* r27 is for return value */

/* ====================================================================== */

extern FILE *yyin;		/* FILE * for input file */
extern char *yytext;		/* current lexeme is stored here */

extern char *lex;		/* lexeme of ID and NUM from scanner */
extern int source_line_no;	/* souce line number */

/* ====================================================================== */

void regi_init(void);
void regi_print(void);
void regi_free(int i);
int regi_new(void);
void backpatch(unsigned int ip1, unsigned int ip2);
void backpatch_funcalls(void);
void print_code(void);
int yyerror(char *message);

/* ====================================================================== */

char *prog_name;		/* program file name from argv[] */
char option_symbol;		/* -s option means print symbol table */

int position;			/* current symbol's kind */

int global_offset;		/* global variable offset */
int local_offset;		/* local variable offset */
int *current_offset;		/* current offset pointer */

int farg_count;			/* no of formal args in function declaration */
int aarg_count;			/* no of actual args in function call */

char *current_fun_name = 0;	/* current function name */

unsigned int ip = 0;		/* instruction pointer */

char *code[MAX_NO_CODES];	/* generated codes */
char regi_used[NO_TMP_REGIS];	/* 1 if register is used */

/* ====================================================================== */

typedef struct l_type_struct {	/* lex attribute for var and num */
  char *lex;
} l_type;

...

%}

/* ====================================================================== */

%start program

%union {
  l_type lval;
...
}

%token VOID INT
...

%type <lval> var num
...

%%

/* ====================================================================== */

program

...

%%

/* ====================================================================== */

void regi_init(void)
{
  int i;

  for (i = 0; i < NO_TMP_REGIS; i++)
    regi_used[i] = 0;
}

/* ====================================================================== */

void regi_free(int i)
{
  regi_used[i] = 0;
}

/* ====================================================================== */

int regi_new(void)
{
  int i;

  for (i = 0; i < NO_TMP_REGIS; i++) {
    if (regi_used[i] == 0) {
      regi_used[i] = 1;
      return i;
    }
  }
  error("error 50: all registers are used!");
}

/* ====================================================================== */

int generate(char *fmt, int i1, int i2, int i3, int i4)
{
  char tmp[MAX_LINE];
  char *p;

  sprintf(tmp, fmt, i1, i2, i3, i4);
  p = (char *) malloc(strlen(tmp) + 1);
  strcpy(p, tmp);
  code[ip - 1] = p;
}

/* ====================================================================== */

void backpatch(unsigned int ip1, unsigned int ip2)
{
  char tmp[MAX_LINE];
  char *p;

  sprintf(tmp, code[ip1], ip2);
  p = (char *) malloc(strlen(tmp) + 1);
  strcpy(p, tmp);
  free(code[ip1]);
  code[ip1] = p;
}

/* ====================================================================== */

void backpatch_funcalls(void)
{
  int i, j;
  struct symbol *symbolp;
  
  for (i = 0; i < HASH_SIZE; i++)
    for (symbolp = global_table->hash[i]; symbolp != NULL;
	 symbolp = symbolp->next)
      for (j = 0; j < symbolp->ipc; j++)
	backpatch(symbolp->ip[j], symbolp->offset);
}

/* ====================================================================== */

void print_code(void)
{
  int i;
  char file[MAX_LINE];
  FILE *fp;
  
  i = strlen(prog_name);
  if ((i > 2) && (prog_name[i - 2] == '.') && (prog_name[i - 1] == 'c'))
    prog_name[i - 2] = '\0';
  else if ((i > 2) && (prog_name[i - 2] == '.') && (prog_name[i - 1] == 'C'))
    prog_name[i - 2] = '\0';

  sprintf(file, "%s.tm", prog_name);
  if ((fp = fopen(file, "w")) == NULL) {
    fprintf(stderr, "%s: %s\n", file, strerror(errno));
    exit(1);
  }
  
  fprintf(fp, "// ====================\n");
  fprintf(fp, "// c startup\n");
  fprintf(fp, "// ====================\n");
  for (i = 0; i < ip; i++)
    fprintf(fp, "%s\n", code[i]);
  fprintf(fp, "// ====================\n");
  fclose(fp);
}

/* ====================================================================== */

int yyerror(char *message)
{
  if (option_symbol == 1) {
    print_table(current_table);
    fprintf(stdout,
	    "---------- ---------- ---------- ---------- ---------- ----------\n");
    print_table(global_table);
    fprintf(stdout,
	    "---------- ---------- ---------- ---------- ---------- ----------\n");
  }
  fprintf(stderr, "line %d: %s at \"%s\"\n", source_line_no, message,
	  yytext);
}

/* ====================================================================== */

int error(char *fmt, char *s1, char *s2, char *s3, char *s4)
{
  if (option_symbol == 1) {
    print_table(current_table);
    fprintf(stdout,
	    "---------- ---------- ---------- ---------- ---------- ----------\n");
    print_table(global_table);
    fprintf(stdout,
	    "---------- ---------- ---------- ---------- ---------- ----------\n");
  }
  fprintf(stdout, "line %d: ", source_line_no);
  fprintf(stdout, fmt, s1, s2, s3, s4);
  fprintf(stdout, "\n");
  fflush(stdout);
  exit(-1);
}

/* ====================================================================== */

int main(int argc, char *argv[])
{
  if (argc == 2) {
    option_symbol = 0;
    prog_name = argv[1];
  } else if (argc == 3) {
    if (strcmp(argv[1], "-s") != 0) {
      fprintf(stderr, "usage: cm [-s] file\n");
      exit(1);
    }
    option_symbol = 1;
    prog_name = argv[2];
  } else {
    fprintf(stderr, "usage: cm [-s] file\n");
    exit(1);
  }

  yyin = fopen(prog_name, "r");
  if (yyin == NULL) {
    fprintf(stderr, "%s: %s\n", prog_name, strerror(errno));
    exit(1);
  }
  yyparse();

  return 0;
}

/* ====================================================================== */
