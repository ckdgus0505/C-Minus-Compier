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

typedef struct t_type_struct {  /* type attribute for type_specifier */
  unsigned char type;
} t_type;

typedef struct r_type_struct {
  unsigned char regi;
} r_type;

typedef struct p_type_struct {
  unsigned int ip;
} p_type;

%}

/* ====================================================================== */

%start program

%union {
  l_type lval;
  t_type tval;
  r_type rval;
  p_type pval;
}

%token VOID INT
%token IF ELSE WHILE RETURN
%token INPUT OUTPUT
%token PLUS MINUS MULTIPLY DIVIDE
%token LT LE GT GE EQ NE
%token ASSIGN
%token SEMICOLON COMMA
%token LPAR RPAR LBRACKET RBRACKET LBRACE RBRACE
%token ID NUM
%token UNDEFINED

%type <lval> var num
%type <tval> type_specifier
%type <rval> simple_expression additive_expression term factor call
%type <pval> if_rpar if_else while_lpar while_rpar

%%

/* ====================================================================== */

program
  :
  {

    struct symbol *symbolp;
    position=GLOBAL;

    current_table=global_table=create_table("_global");
    current_offset=&global_offset;
    *current_offset=0;
    fprintf(stdout,
        "---------- ---------- ---------- ---------- ---------- ----------\n");
    fprintf(stdout, "%-10s %-10s %-10s %-10s %10s %10s\n", "table", "symbol", "kind", "type", "size", "offset");
    fprintf(stdout,
        "---------- ---------- ---------- ---------- ---------- ----------\n");

    generate("%d: ld gp, 0(0)", ip++);    // tm의 명령어 주소 = 0 (ip == 0)
    generate("%d: st 0, 0(0)", ip++);
    generate("%d: lda fp, -%%d(gp)", ip++); // (ip == 2)
    generate("%d: lda sp, -%%d(gp)", ip++); // (ip == 3)
    generate("%d: push fp", ip++);
    generate("%d: lda 0, 2(pc)", ip++);
    generate("%d: push 0", ip++);
    symbolp = add_symbol(global_table, "main", FUNCTIONI, VOID_TYPE, 0, 0);
    generate("%d: ldc pc, %%d", ip++);
    symbolp->ip[0] = ip - 1;
    symbolp->ipc = 1;
    generate("%d: halt", ip++);
  }
    var_declaration_list fun_declaration_list
  {
    backpatch(2, global_offset); // (ip==2 위치에 global_offset을 backpatching 해준다.)
    backpatch(3, global_offset);
    backpatch_funcalls();

    print_table(global_table);
    free_table(global_table);
    fprintf(stdout,
        "---------- ---------- ---------- ---------- ---------- ----------\n");
  }
;

var_declaration_list
  : var_declaration_list var_declaration
  | empty
;

fun_declaration_list
  : fun_declaration_list fun_declaration
  | fun_declaration
;

var_declaration
  : type_specifier var SEMICOLON
  {
    if($<tval>1.type == VOID_TYPE)
      error("error 00: wrong void variable \"%s\"",$<lval>2.lex);
    else if (find_symbol( current_table, $<lval>2.lex))
      error("error 10: redefined variable \"%s\"", $<lval>2.lex);
    else
    {
      add_symbol (current_table, $<lval>2.lex, position,  $<tval>1.type, 1, *current_offset);
      *current_offset = *current_offset+1;
    }
  }
  | type_specifier var LBRACKET num RBRACKET SEMICOLON
  {
    if($<tval>1.type == VOID_TYPE)
      error("error 01: wrong void array \"%s\"", $<lval>2.lex);
    else if (find_symbol (current_table, $<lval>2.lex))
      error("error 11: redefined array \"%s\"", $<lval>2.lex);
    else
    {
      int n = atoi($<lval>4.lex);
      add_symbol (current_table, $<lval>2.lex, position, INT_ARRAY_TYPE, n, *current_offset + n - 1);
      *current_offset = *current_offset + n;
    }
  }
;

type_specifier
  : INT
  {
    $<tval>$.type = INT_TYPE;
  }
  | VOID
  {
    $<tval>$.type = VOID_TYPE;  // 내가 임의로 넣음
  }
;

var
  : ID
  {
    $<lval>$.lex = lex;
  }
;

num
  : NUM
  {
    $<lval>$.lex = lex;
    int regi = regi_new();
    int num = atoi(lex);
    generate("%d: ldc %d, %d", ip++, regi, num);
    $<rval>$.regi = regi;
  }
;

fun_declaration
  : type_specifier var
  {
    position = ARGUMENT;
    current_table = local_table = create_table($<lval>2.lex);
    if(find_symbol(global_table, $<lval>2.lex)) // null이면 수행
    {
      error("error 12: redefined function \"%s\"", $<lval>2.lex);
    }
    current_offset = &local_offset;
    *current_offset = 0;
    farg_count = 0;
  }
    LPAR params RPAR
  {
    add_symbol (global_table, $<lval>2.lex, FUNCTION, $<tval>1.type, farg_count, ip);
    position=LOCAL;
  }
    LBRACE local_declarations statement_list RBRACE
  {
    print_table(current_table);
    free_table(current_table);
    current_table = global_table;
    fprintf(stdout,
        "---------- ---------- ---------- ---------- ---------- ----------\n");
  }
;

params
  : param_list
  | VOID
;

param_list
  : param_list COMMA param
  {
    farg_count++;
  }
  | param
  {
    farg_count = 1;
  }
;

param
  : type_specifier var
  {
    if($<tval>1.type == VOID_TYPE)
      error("error 02: wrong void argument \"%s\"",$<lval>2.lex);
    {
      if(find_symbol (local_table, $<lval>2.lex))
      error("error 13: redefined argument \"%s\"",$<lval>2.lex);
      else
      {
        add_symbol (current_table, $<lval>2.lex, position, $<tval>1.type, 1, *current_offset);
        *current_offset = *current_offset + 1;
      }
    }
  }
  | type_specifier var LBRACKET RBRACKET
  {
    if($<tval>1.type == VOID_TYPE)
      error("error 03: wrong void array argument \"%s\"",$<lval>2.lex);
    {
      if(find_symbol (local_table, $<lval>2.lex))
        error("error 14: redefined arry argument \"%s\"",$<lval>2.lex);
      else
      {
        add_symbol (current_table, $<lval>2.lex, position, INT_P_TYPE, 1, *current_offset);
        *current_offset = *current_offset + 1;
      }
    }
  }
;

local_declarations
  : local_declarations var_declaration
  | empty
;

statement_list
  : statement_list statement
  | empty
;

statement
  : compound_stmt
  | expression_stmt
  | selection_stmt
  | iteration_stmt
  | funcall_stmt
  | return_stmt
  | input_stmt
  | output_stmt
;

compound_stmt
  : LBRACE statement_list RBRACE
;

expression_stmt
  : expression SEMICOLON
  | SEMICOLON
;

expression
  : var ASSIGN expression
  {
    char *var = $<lval>1.lex;
    struct symbol *symbolp;
    symbolp = lookup_symbol(var);
    if (symbolp == NULL)
      error("error 20: undefined variable \"%s\"", var);
    else if(symbolp->kind == GLOBAL || symbolp->kind == FUNCTION || symbolp->kind == FUNCTIONI || symbolp->kind == ARGUMENT)
      error("error 30: type error variable \"%s\"", var);
    if(symbolp->kind == GLOBAL) {
      int offset = symbolp->offset;
      generate("%d: st %d, -%d(gp)", ip++, $<rval>3.regi, offset);
      $<rval>$.regi = $<rval>3.regi;
    }
    else  {
      int offset = symbolp->offset;
      generate("%d: st %d, -%d(fp)", ip++, $<rval>3.regi, offset+2);
      $<rval>$.regi = $<rval>3.regi;
    }
    regi_free($<rval>3.regi);
  }
  | var LBRACKET expression RBRACKET ASSIGN expression
  {
    char *var = $<lval>1.lex;
    struct symbol *symbolp;
    symbolp = lookup_symbol(var);
    if(symbolp == NULL)
      error("error 21: undefined array \"%s\"", var);
    else if(symbolp->type != INT_ARRAY_TYPE)
      error("error 31: type error array \"%s\"", var);
    if(symbolp->kind == GLOBAL) {    ///////////////////// 오류생기면 바꿔보기
      int regi1 = regi_new();
      int offset = symbolp->offset;
      generate("%d: add %d, gp, %d", ip++, regi1, $<rval>3.regi);
      generate("%d: st %d, -%d(%d)", ip++, $<rval>3.regi, offset, regi1);
      regi_free(regi1);
      $<rval>$.regi = $<rval>3.regi;
    }
    else  {
      int regi1 = regi_new();
      int offset = symbolp->offset;
      generate("%d: add %d, gp, %d", ip++, regi1, $<rval>3.regi);
      generate("%d: st %d, -%d(fp)", ip++, $<rval>3.regi, offset+2);
      regi_free(regi1);
      $<rval>$.regi = $<rval>3.regi;
    }
  }
  | simple_expression
;

simple_expression
  : additive_expression relop additive_expression
  | additive_expression
;

relop
  : LT
  | LE
  | GT
  | GE
  | EQ
  | NE
;

additive_expression
  : additive_expression addop term
  {
    int regi = regi_new();
    generate("%d: add %d, %d, %d", ip++, regi, $<rval>1.regi, $<rval>3.regi);
    regi_free($<rval>1.regi);
    regi_free($<rval>3.regi);
    $<rval>$.regi = regi;
  }
  | term
;

addop
  : PLUS
  | MINUS
;

term
  : term MULTIPLY factor
  {
    int regi = regi_new();
    generate("%d: mul %d, %d, %d", ip++, regi, $<rval>1.regi, $<rval>3.regi);
    regi_free($<rval>1.regi);
    regi_free($<rval>3.regi);
    $<rval>$.regi = regi;
  }
  | term DIVIDE factor
  {
    int regi = regi_new();
    generate("%d: div %d, %d, %d", ip++, regi, $<rval>1.regi, $<rval>3.regi);
    regi_free($<rval>1.regi);
    regi_free($<rval>3.regi);
    $<rval>$.regi = regi;
  }
  | factor
;

factor
  : LPAR expression RPAR
  {
    $<rval>$.regi = $<rval>2.regi;
  }
  | var
  {
    char *var = $<lval>1.lex;
    struct symbol *symbolp;
    symbolp = lookup_symbol(var);
    if(symbolp == NULL)
      error("error 20: undefined variable \"%s\"", var);
    if(symbolp->kind == GLOBAL) {
      int regi = regi_new();
      int offset = symbolp->offset;
      if(symbolp->type == INT_ARRAY_TYPE)
        generate("%d: lda %d, -%d(gp)", ip++, regi, offset);
      else
        generate("%d: ld %d, -%d(gp)", ip++, regi, offset);
      $<rval>$.regi = regi;
    }
    else {
      int regi = regi_new();
      int offset = symbolp->offset;
      if(symbolp->type == INT_ARRAY_TYPE)
        generate("%d: lda %d, -%d(fp)", ip++, regi, offset+2);
      else
        generate("%d: ld %d, -%d(fp)", ip++, regi, offset+2);
      $<rval>$.regi = regi;
    }
    

  }
  | var LBRACKET expression RBRACKET
  {
    char *var = $<lval>1.lex;
    struct symbol *symbolp;
    symbolp = lookup_symbol(var);
    if(symbolp == NULL)
      error("error 21: undefined array \"%s\"", var);
    if(symbolp->kind == GLOBAL) {
      int regi1 = regi_new();
      int regi2 = regi_new();
      int offset = symbolp->offset;
      generate("%d: add %d, gp, %d", ip++, regi1, $<rval>3.regi);
      generate("%d: ld %d, -%d(%d)", ip++, regi2, offset, regi1);
      regi_free(regi1);
      regi_free($<rval>3.regi);
      $<rval>$.regi = regi2;
    }
    else {
      int regi1 = regi_new();
      int regi2 = regi_new();
      int offset = symbolp->offset;
      generate("%d: add %d, fp, %d", ip++, regi1, $<rval>3.regi);
      generate("%d: ld %d, -%d(%d)", ip++, regi2, offset+2, regi1);
      regi_free(regi1);
      regi_free($<rval>3.regi);
      $<rval>$.regi = regi2;
    }
  }
  | num           /////////////// 오류 생길수도 있음 ㅠㅠ
  {
    $<rval>$.regi = $<rval>1.regi;

  }
  | PLUS num
  {
    $<rval>$.regi = $<rval>2.regi;
  }
  | MINUS num
  {
    $<rval>$.regi = $<rval>2.regi * (-1);
  }
;

selection_stmt
  : IF LPAR expression
  {
    generate("%d: jle %d, %%d(pc)", ip++, $<rval>3.regi);
    regi_free($<rval>3.regi);
  }
    if_rpar statement
  {
    generate("%d: ldc pc, %%d", ip++);
    backpatch($<pval>5.ip-1, ip - $<pval>5.ip);
  }
    if_else statement
  {
    backpatch($<pval>8.ip - 1, ip);
  }
;

if_rpar
  : RPAR
  {
    $<pval>$.ip = ip;
  }
;

if_else
  :
  {
    $<pval>$.ip = ip;
  }
;

iteration_stmt
  : WHILE while_lpar expression
  {
    generate("%d: jle %d, %%d(pc)", ip++, $<rval>3.regi);
    regi_free($<rval>3.regi);
  }
    while_rpar statement
  {
    generate("%d: ldc pc, %d", ip++, $<pval>2.ip);
    backpatch($<pval>5.ip-1, ip - $<pval>2.ip);  /////////////////////// 백패칭 계산 잘 해보
  }
;

while_lpar
  :
  {
    $<pval>$.ip = ip;
  }
;

while_rpar
  :
  {
    $<pval>$.ip = ip;
  }
;

funcall_stmt
  : var ASSIGN call
  {
    char *var = $<lval>1.lex;
    struct symbol *symbolp;
    symbolp = lookup_symbol(var);
    if (symbolp == NULL)
      error("error??: funcall error");
    if(symbolp->kind == GLOBAL) {
      int offset = symbolp->offset;
      generate("%d: st %d, -%d(gp)", ip++, $<rval>3.regi, offset);
      regi_free($<rval>3.regi);
    }
    else {
      int offset = symbolp->offset;
      generate("%d: st %d, -%d(fp)", ip++, $<rval>3.regi, offset + 2);
      regi_free($<rval>3.regi);
    }
  }
  | var LBRACKET expression RBRACKET ASSIGN call
  {
    char *var = $<lval>1.lex;
    struct symbol *symbolp;
    symbolp = lookup_symbol(var);
    if (symbolp == NULL)
      error("error??: funcall arr error");
    if(symbolp->kind == GLOBAL) {
      int offset = symbolp->offset;
      int regi = regi_new();
      generate("%d: add %d, gp, %d", ip++, regi, $<rval>3.regi);
      generate("%d: st %d, -%d(gp)", ip++, $<rval>6.regi, regi);
      regi_free(regi);
      regi_free($<rval>3.regi);
    }
    else {
      int offset = symbolp->offset;
      int regi = regi_new();
      generate("%d: add, fp, %d", ip++, regi, $<rval>3.regi);
      generate("%d: st %d, -%d(fp)", ip++, $<rval>6.regi, regi);
      regi_free(regi);
      regi_free($<rval>3.regi);
    }
  }
  | call
;

call
  : var
  {
    struct symbol *symbolp;
    symbolp = lookup_symbol($<lval>1.lex);
    if(symbolp == NULL)
    {
      error("error 22: undefined function call \"%s\"", $<lval>1.lex);
      aarg_count = 0;
    }
    if(symbolp->kind != FUNCTION || symbolp->kind != FUNCTIONI)
      error("error 32: type error function \"%s\"", $<lval>1.lex);
    aarg_count = 0;
    generate("%d: lda sp, -2(sp)", ip++);
  }
    LPAR args RPAR
  {
    int regi;
    if(!lookup_symbol($<lval>1.lex) == NULL)
    {
      struct symbol *symbolp;
      symbolp = lookup_symbol($<lval>1.lex);
      if(symbolp->size != aarg_count)
        error("error 40: wrong no argument function \"%s\"", $<lval>1.lex);
      generate("%d: st fp, -%d(fp)", ip++, *current_offset +2);
      generate("%d: lda fp, -%d(fp)", ip++, *current_offset +2);
      regi = regi_new();
      generate("%d: lda %d, 2(pc)", ip++, regi);
      generate("%d: st %d, -1(fp)", ip++, regi);
      regi_free(regi);
      if(symbolp->offset !=0) {
        generate("%d: ldc pc, %d", ip++, symbolp->offset);
      }
      else {
        generate("%d: ldc pc, %%d", ip++);
        symbolp->ip[symbolp->ipc] = ip-1;
        symbolp->ipc = symbolp ->ipc+1;
      }
      regi = regi_new();
      generate ("%d: lda %d, 0(%d)", ip++, regi, REGI_RETURN);
      $<rval>$.regi = regi;
    }
  }
;

args
  : arg_list
  | empty
;

arg_list
  : arg_list COMMA expression
  {
    aarg_count++;
    generate("%d: push %d", ip++, $<rval>3.regi);
    regi_free($<rval>3.regi);
  }
  | expression
  {
    aarg_count++;
    generate("%d: push %d", ip++, $<rval>1.regi);
    regi_free($<rval>1.regi);
  }
;

return_stmt
  : RETURN SEMICOLON
  {
    generate("%d: ldc %d, 0", ip++, REGI_RETURN);
    generate("%d: lda sp, 0(fp)", ip++);
    generate("%d: ld fp, 0(fp)", ip++);
    generate("%d: ld pc, -1(sp)", ip++);
  }
  | RETURN expression SEMICOLON
  {
    generate("%d: lda %d, 0(%d)", ip++, REGI_RETURN, $<rval>2.regi);
    generate("%d: lda sp, 0(fp)", ip++);
    generate("%d: ld fp, 0(fp)", ip++);
    generate("%d: ld pc, -1(sp)", ip++);
    regi_free($<rval>2.regi);
  }
;

input_stmt
  : INPUT var SEMICOLON
  {
    char *var = $<lval>2.lex;
    struct symbol *symbolp;
    symbolp = lookup_symbol(var);
    //////////////////////////////////보통 이런곳에 에러...

    if(symbolp == NULL)
      error("error ??: input error");
    if (symbolp->kind == GLOBAL) {
      int regi = regi_new();
      int offset = symbolp->offset;
      generate("%d: in %d", ip++, regi);
      generate("%d: st %d, -%d(gp)", ip++, regi, offset);
      regi_free(regi);
    }
    else {
      int regi = regi_new();
      int offset = symbolp->offset;
      generate("%d: in %d", ip++, regi);
      generate("%d: st %d, -%d(fp)", ip++, regi, offset+2);
      regi_free(regi);
    }
  }
  | INPUT var LBRACKET expression RBRACKET SEMICOLON
  {
    char *var = $<lval>2.lex;
    struct symbol *symbolp;
    symbolp = lookup_symbol(var);
    //////////////////////////////////보통 이런곳에 에러...

    if(symbolp == NULL)
      error("error ??: input arr error");
    if (symbolp->kind == GLOBAL) {
      int regi1 = regi_new();
      int regi2 = regi_new();
      int offset = symbolp->offset;
      generate("%d: in %d", ip++, regi1);
      generate("%d: add %d, gp, %d", ip++, regi2, $<rval>4.regi);
      generate("%d: st %d, -%d(gp)", ip++, regi1, regi2);
      regi_free(regi1);
      regi_free(regi2);
    }
    else {
      int regi1 = regi_new();
      int regi2 = regi_new();
      int offset = symbolp->offset;
      generate("%d: in %d", ip++, regi1);
      generate("%d: add %d, gp, %d", ip++, regi2, $<rval>4.regi); 
      generate("%d: st %d, -%d(fp)", ip++, regi1, regi2);
      regi_free(regi1);
      regi_free(regi2);
    }
  }
;

output_stmt
  : OUTPUT expression SEMICOLON
  {
    generate ("%d: out %d", ip++, $<rval>2.regi);
    regi_free($<rval>2.regi);
  }
;

empty
  :
;

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
  fprintf(stdout, "파싱 끝!!!\n");
  print_code();
  return 0;
}

/* ====================================================================== */
