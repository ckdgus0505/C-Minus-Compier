// ====================
// c startup
// ====================
0: ld gp, 0(0)
1: st 0, 0(0)
2: lda fp, -0(gp)
3: lda sp, -0(gp)
4: push fp
5: lda 0, 2(pc)
6: push 0
7: ldc pc, 0
8: halt
9: ldc 0, 0
10: st 0, -2(fp)
11: ldc 0, 1
12: st 0, -3(fp)
13: ld 0, -2(fp)
14: out 0
15: ld 0, -3(fp)
16: out 0
// ====================
