# ======================================================================

DIR = compiler
#FILES = Makefile parser.y scanner.l symbol.c

# ======================================================================

cm:
	cd ../; make	
	../cm 00-local-variable.c
	../cm 01-local-array.c
	../cm 10-global-variable.c
	../cm 11-global-array.c
	../cm 20-expression-0.c
	../cm 21-expression-1.c
	../cm 30-if-0.c
	../cm 31-if-1.c
	../cm 40-while-0.c
	../cm 41-while-1.c
	../cm 50-input-output-0.c
	../cm 60-array-argument-0.c
	../cm 61-array-argument-1.c
	../cm 70-add.c
	../cm 71-sum.c
	../cm 72-fact.c
	../cm 73-gcd.c
	../cm 74-sort.c

tm:
	tm 00-local-variable.tm
	tm 01-local-array.tm
	tm 10-global-variable.tm
	tm 11-global-array.tm
	tm 20-expression-0.tm
	tm 21-expression-1.tm
	tm 30-if-0.tm
	tm 31-if-1.tm
	tm 40-while-0.tm
	tm 41-while-1.tm
	tm 50-input-output-0.tm
	tm 60-array-argument-0.tm
	tm 61-array-argument-1.tm
	tm 70-add.tm
	tm 71-sum.tm
	tm 72-fact.tm
	tm 73-gcd.tm
	tm 74-sort.tm

diff:
	diff 00-local-variable.tm ../tests/00-local-variable.tm
	diff 01-local-array.tm ../tests/01-local-array.tm
	diff 10-global-variable.tm ../tests/10-global-variable.tm
	diff 11-global-array.tm ../tests/11-global-array.tm
	diff 20-expression-0.tm ../tests/20-expression-0.tm
	diff 21-expression-1.tm ../tests/21-expression-1.tm
	diff 30-if-0.tm ../tests/30-if-0.tm
	diff 31-if-1.tm ../tests/31-if-1.tm
	diff 40-while-0.tm ../tests/40-while-0.tm
	diff 41-while-1.tm ../tests/41-while-1.tm
	diff 50-input-output-0.tm ../tests/50-input-output-0.tm
	diff 60-array-argument-0.tm ../tests/60-array-argument-0.tm
	diff 61-array-argument-1.tm ../tests/61-array-argument-1.tm
	diff 70-add.tm ../tests/70-add.tm
	diff 71-sum.tm ../tests/71-sum.tm
	diff 72-fact.tm ../tests/72-fact.tm
	diff 73-gcd.tm ../tests/73-gcd.tm
	diff 74-sort.tm ../tests/74-sort.tm
#cm:	parser.o scanner.o
#	gcc -O -o cm parser.o scanner.o -lfl

#parser.o:	parser.c
#	gcc -O -c parser.c

#parser.c:	parser.y symbol.c
#	bison -d parser.y
#	mv parser.tab.c parser.c
#	mv parser.tab.h parser.h

#scanner.o:	scanner.c
#	gcc -O -c scanner.c

#scanner.c:	scanner.l
#	flex scanner.l
#	mv lex.yy.c scanner.c

# ======================================================================

clean:
	@rm -rf .*~ *~ cm parser.c parser.h scanner.c *.o *.tm *.ps *.pdf
#	cd tests; make clean

# ======================================================================
