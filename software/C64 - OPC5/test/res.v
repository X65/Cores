	code
_BinaryMergeTest:
	# 	return a + b + 1;
	      	add  	r8,r9,0
	      	add  	r8,r0,1
	      	mov  	r1,r8,0
BinaryMergeTest_4:
	      	mov  	r15,r13,0
	rodata
	extern	_BinaryMergeTest
#	code
	# void bug10() {
_bug10:
	      	   push 	r12,r14
	      	   mov  	r12,r14
	      	   sub  	r14,r0,335
	      	   push 	r3,r14
	# 	int x;
	      	   ld   	r3,r12,-1
	# 	for (x = 333; x > 0; x--) {
	      	   mov  	r3,r0,333
bug10_4:
	      	   cmp  	r3,r0
	      	mi.mov  	r15,r0,bug10_5
	      	   cmp  	r3,r0
	      	 z.inc  	r15,bug10_5-PC
	# 		pi[x] = 2;
	      	   mov  	r5,r12,-335
	      	   mov  	r1,r3
	      	   add  	r1,r5
	      	   mov  	r5,r0,2
	      	   sto  	r5,r1
	      	   dec  	r3,1
	      	   mov  	r15,r0,bug10_4
bug10_5:
	      	   pop  	r3,r14
	      	   mov  	r14,r12
	      	   pop  	r12,r14
	      	   mov  	r15,r13


#	rodata
#	global	_bug10
#	code
_bug12:
	# int bug12()
	      	   push 	r13,r14
	      	   push 	r12,r14
	      	   mov  	r12,r14
	      	   dec  	r14,2
	# 	int a = 123;
	      	   mov  	r5,r0,123
	      	   sto  	r5,r12,-1
	      	   ld   	r6,r12,-1
	      	   mov  	r5,r6
	      	   add  	r5,r5
	      	   sto  	r5,r12,-2
	# 	return b;
	      	   ld   	r5,r12,-2
	      	   mov  	r1,r5
	      	   mov  	r14,r12
	      	   pop  	r12,r14
	      	   pop  	r13,r14
	      	   mov  	r15,r13


#	rodata
#	global	_bug12
#	code
_print:
	# int print(char *ptr)
	      	   push 	r13,r14
	      	   push 	r12,r14
	      	   mov  	r12,r14
bug4_4:
	      	   ld   	r5,r12,2
	      	   inc  	r5,1
	      	   sto  	r5,r12,2
	      	   ld   	r5,r12,2
	      	   ld   	r5,r5
	      	   add  	r5,r0
	      	 z.inc  	r15,bug4_5-PC
	# 		outch(*ptr);
	      	   ld   	r5,r12,2
	      	   ld   	r5,r5
	      	   push 	r5,r14
	      	   jsr  	r13,r0,_outch
	      	   inc  	r14,1
	      	   mov  	r15,r0,bug4_4
bug4_5:
	      	   mov  	r14,r12
	      	   pop  	r12,r14
	      	   pop  	r13,r14
	      	   mov  	r15,r13
#	rodata
#	extern	_outch
#	extern	_print
#	code
_bug7:
	# int bug7(int d)
	      	   push 	r13,r14
	      	   push 	r12,r14
	      	   mov  	r12,r14
	# 	return (d/1000) % 10;
	      	   ld   	r7,r12,2
	      	   mov  	r1,r7
	      	   mov  	r2,r0,1000
	      	   jsr  	r13,r0,__div
	      	   mov  	r2,r0,10
	      	   jsr  	r13,r0,__mod
	      	   mov  	r14,r12
	      	   pop  	r12,r14
	      	   pop  	r13,r14
	      	   mov  	r15,r13
#	rodata
#	extern	_bug7
#	code
_bug8:
	# int bug8(int a, int b)
	      	   push 	r13,r14
	      	   push 	r12,r14
	      	   mov  	r12,r14
	# 	return a*b;
	      	   ld   	r6,r12,2
	      	   ld   	r7,r12,3
	      	   mov  	r1,r6
	      	   mov  	r2,r7
	      	   jsr  	r13,r0,__mul
	      	   mov  	r14,r12
	      	   pop  	r12,r14
	      	   pop  	r13,r14
	      	   mov  	r15,r13
#	rodata
#	extern	_bug8
#	code
	# class ClassTest
_ZBBAA_ClassTest:
	      	   push 	r12,r14
	      	   mov  	r12,r14
	      	   dec  	r14,2
	      	   push 	r3,r14
	# 	ClassTest a, b;
	      	   mov  	r3,r0,1
	# 	a.a = a.a + b.a;
	      	   mov  	r5,r12,-1
	      	   mov  	r1,r5
	      	   add  	r1,r3
	      	   mov  	r7,r12,-1
	      	   mov  	r6,r7
	      	   add  	r6,r3
	      	   ld   	r6,r6
	      	   push 	r1,r14
	      	   mov  	r1,r12,-2
	      	   mov  	r7,r1
	      	   add  	r7,r3
	      	   ld   	r7,r7
	      	   mov  	r5,r6
	      	   add  	r5,r7
	      	   sto  	r5,r1
	      	   pop  	r1,r14
	# 	return a.a;
	      	   mov  	r5,r12,-1
	      	   mov  	r1,r5
	      	   add  	r1,r3
	      	   ld   	r1,r1
	      	   pop  	r3,r14
	      	   mov  	r14,r12
	      	   pop  	r12,r14
	      	   mov  	r15,r13


_ZBBAAMBAA_AddQAAAQAAA:
	# class ClassTest
	      	   push 	r13,r14
	      	   push 	r12,r14
	      	   mov  	r12,r14
	# 	return a + b + c + d;
	      	   ld   	r3,r11,1
	      	   ld   	r4,r11,2
	      	   mov  	r7,r3
	      	   add  	r7,r4
	      	   ld   	r3,r12,2
	      	   mov  	r6,r7
	      	   add  	r6,r3
	      	   ld   	r7,r12,3
	      	   mov  	r5,r6
	      	   add  	r1,r7
	      	   mov  	r14,r12
	      	   pop  	r12,r14
	      	   pop  	r13,r14
	      	   mov  	r15,r13
#	rodata
#	global	_ClassTest
#	extern	_Add
#	bss
_nums:
	word	0
	word	0
	word	0
	word	0
	word	0
	word	0
	word	0
	word	0
	word	0
	word	0
	word	0
	word	0
	word	0
	word	0
	word	0
	word	0
	word	0
	word	0
	word	0
	word	0
	word	0
	word	0
	word	0
	word	0
	word	0
	word	0
	word	0
	word	0
	word	0
	word	0

#	code
	# int nums [30];
_main:
	      	   push 	r12
	      	   mov  	r12,r14
	      	   dec  	r14,4
	      	   push 	r3
	# 	int c,c1,c2;
	      	   push 	r4
	# 	c1 = 0;
	      	   sto  	r0,r12,-2
	# 	c2 = 1;
	      	   mov  	r4,r0,1
	# 	for (n = 0; n < 23; n++) {
	      	   sto  	r0,r12,-4
fibonnaci_4:
	      	   ld   	r1,r12,-4
	      	   cmp  	r1,r0,23
	      	mi.mov  	r15,r0,fibonnaci_5
	# 		if (n < 1) {
	      	   ld   	r1,r12,-4
	      	   cmp  	r1,r0,1
	      	mi.inc  	r15,fibonnaci_7-PC
	# 			nums[0] = 1;
	      	   mov  	r1,r0,1
	      	   sto  	r1,r0,_nums
	# 			c = 1;
	      	   mov  	r3,r0,1
	      	   inc  	r15,fibonnaci_8-PC
fibonnaci_7:
	# 			nums[n] = c;
	      	   ld   	r1,r12,-4
	      	   sto  	r3,r1,_nums
	# 			c = c1 + c2;
	      	   ld   	r5,r12,-2
	      	   mov  	r1,r5
	      	   add  	r1,r4
	      	   mov  	r3,r1
	# 			c1 = c2;
	      	   sto  	r4,r12,-2
	# 			c2 = c;
	      	   mov  	r4,r3
fibonnaci_8:
	      	   ld   	r1,r12,-4
	      	   inc  	r1,1
	      	   sto  	r1,r12,-4
	      	   mov  	r15,r0,fibonnaci_4
fibonnaci_5:
	      	   pop  	r4
	      	   pop  	r3
	      	   mov  	r14,r12
	      	   pop  	r12
	      	   mov  	r15,r13




#	rodata
#	global	_main
#	global	_nums
#	code
_main:
	# int main()
	      	   push 	r13,r14
	      	   push 	r12,r14
	      	   mov  	r12,r14
	# 	int nines;
	      	   dec  	r14,1
nines_4:
	      	   ld   	r5,r12,-1
	      	   add  	r5,r0
	      	 z.mov  	r15,r0,nines_5
	# 		putchar('0');
	      	   mov  	r5,r0,48
	      	   push 	r5,r14
	      	   jsr  	r13,r0,_putchar
	      	   inc  	r14,1
	# 		nines--;
	      	   ld   	r5,r12,-1
	      	   dec  	r5,1
	      	   sto  	r5,r12,-1
	      	   mov  	r15,r0,nines_4
nines_5:
	      	   mov  	r14,r12
	      	   pop  	r12,r14
	      	   pop  	r13,r14
	      	   mov  	r15,r13


#	rodata
#	global	_main
#	extern	_putchar
#	code
_main:
	# long main()
	      	   push 	r13,r14
	      	   push 	r12,r14
	      	   mov  	r12,r14
	# 	long pi[333];
	      	   sub  	r14,r0,672
	# 	x = 10 * pi[i] + q * i;
	      	   push 	r5,r14
	      	   push 	r6,r14
	      	   ld   	r5,r12,-670
	      	   ld   	r6,r12,-669
	      	   push 	r7,r14
	      	   mov  	r7,r12,-666
	      	   mov  	r4,r5
	      	   add  	r4,r7
	      	   ld   	r4,r4
	      	   ld   	r5,r4,1
	      	   mov  	r6,r0,10
	      	   mov  	r1,r4
	      	   mov  	r2,r5
	      	   push 	r3,r14
	      	   push 	r4,r14
	      	   mov  	r3,r6
	      	   mov  	r4,r0
	      	   jsr  	r13,r0,__mul32
	      	   pop  	r4,r14
	      	   pop  	r3,r14
	      	   mov  	r7,r1
	      	   mov  	r3,r2
	      	   ld   	r6,r12,-672
	      	   ld   	r7,r12,-671
	      	   push 	r3,r14
	      	   push 	r4,r14
	      	   ld   	r3,r12,-670
	      	   ld   	r4,r12,-669
	      	   mov  	r1,r6
	      	   mov  	r2,r7
	      	   push 	r3,r14
	      	   push 	r4,r14
	      	   jsr  	r13,r0,__mul32
	      	   pop  	r4,r14
	      	   pop  	r3,r14
	      	   mov  	r4,r1
	      	   mov  	r5,r2
	      	   mov  	r5,r7
	      	   mov  	r6,r3
	      	   add  	r5,r4
	      	   adc  	r6,r5
	      	   pop  	r4,r14
	      	   pop  	r3,r14
	      	   pop  	r7,r14
	      	   sto  	r5,r12,-668
	      	   sto  	r6,r12,-667
	      	   pop  	r6,r14
	      	   pop  	r5,r14
	      	   mov  	r14,r12
	      	   pop  	r12,r14
	      	   pop  	r13,r14
	      	   mov  	r15,r13


#	rodata
#	global	_main
#	bss
_pi:
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0

#	code
_main:
	# int pi[20];
	      	   push 	r13,r14
	      	   push 	r12,r14
	      	   mov  	r12,r14
	# 	int x, i;
	      	   dec  	r14,2
	# 	x = 10 * pi[i];
	      	   ld   	r7,r12,-2
	      	   mov  	r6,r7
	      	   ld   	r6,r6,_pi
	      	   mov  	r7,r0,10
	      	   mov  	r1,r6
	      	   mov  	r2,r7
	      	   jsr  	r13,r0,__mul
	      	   mov  	r5,r1
	      	   sto  	r5,r12,-1
	      	   mov  	r14,r12
	      	   pop  	r12,r14
	      	   pop  	r13,r14
	      	   mov  	r15,r13


#	rodata
#	global	_main
#	global	_pi
#	code
_main:
	# int main(int argc, char **argv)
	      	   push 	r13,r14
	      	   push 	r12,r14
	      	   mov  	r12,r14
	      	   dec  	r14,1
	      	   push 	r3,r14
	      	   push 	r4,r14
	      	   ld   	r3,r12,-1
	# 	int x;
	      	   mov  	r4,r0,_printf
	# 	for (x = 0; x < 10; x++)  {
	      	   mov  	r3,r0,0
Test1_8:
	      	   cmp  	r3,r0,10
	      	pl.inc  	r15,Test1_9-PC
	# 		printf("Hello World!");
	      	   mov  	r5,r0,Test1_1
	      	   push 	r5,r14
	      	   jsr  	r13,r4
	      	   inc  	r14,1
Test1_10:
	      	   inc  	r3,1
	      	   inc  	r15,Test1_8-PC
Test1_9:
	# 	switch(argc) {
	      	   ld   	r5,r12,2
	# 	case 1:	printf("One"); break;
	      	   cmp  	r6,r5,1
	      	 z.inc  	r15,Test1_17-PC
	# 	case 2:	printf("Two"); break;
	      	   cmp  	r6,r5,2
	      	 z.mov  	r15,r0,Test1_18
	# 	case 3:	printf("Three"); break;
	      	   cmp  	r6,r5,3
	      	 z.mov  	r15,r0,Test1_19
	      	   mov  	r15,r0,Test1_12
Test1_17:
	      	   mov  	r5,r0,Test1_2
	      	   push 	r5,r14
	      	   jsr  	r13,r4
	      	   inc  	r14,1
	      	   mov  	r15,r0,Test1_12
Test1_18:
	      	   mov  	r5,r0,Test1_3
	      	   push 	r5,r14
	      	   jsr  	r13,r4
	      	   inc  	r14,1
	      	   inc  	r15,Test1_12-PC
Test1_19:
	      	   mov  	r5,r0,Test1_4
	      	   push 	r5,r14
	      	   jsr  	r13,r4
	      	   inc  	r14,1
Test1_12:
	# 	exit(0);
	      	   push 	r0,r14
	      	   jsr  	r13,r0,_exit
	      	   inc  	r14,1
	      	   pop  	r4,r14
	      	   pop  	r3,r14
	      	   mov  	r14,r12
	      	   pop  	r12,r14
	      	   pop  	r13,r14
	      	   mov  	r15,r13
#	rodata
#	align	2
Test1_4:	# Three
	WORD	84,104,114,101,101,0
Test1_3:	# Two
	WORD	84,119,111,0
Test1_2:	# One
	WORD	79,110,101,0
Test1_1:	# Hello World!
	WORD	72,101,108,108,111,32,87,111
	WORD	114,108,100,33,0
#	extern	_main
#	extern	_exit
#	extern	_printf
#	bss
_ary:
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0
	WORD	0

#	code
_main:
	# int ary[20][45];
	      	   push 	r13,r14
	      	   push 	r12,r14
	      	   mov  	r12,r14
	      	   dec  	r14,3
	      	   push 	r3,r14
	      	   push 	r4,r14
	      	   ld   	r3,r12,-3
	# 	int x, y, z;
	      	   ld   	r4,r12,-2
	# 	for (y = 0; y < argc; y++) {
	      	   mov  	r4,r0,0
Test2_8:
	      	   ld   	r5,r12,2
	      	   cmp  	r4,r5
	      	pl.mov  	r15,r0,Test2_9
	# 		for (z = 0; z < 45; z++)
	      	   mov  	r3,r0,0
Test2_12:
	      	   cmp  	r3,r0,45
	      	pl.mov  	r15,r0,Test2_13
	# 			ary[y][z] = rand();
	      	   push 	r5,r14
	      	   mov  	r5,r0,45
	      	   mov  	r1,r4
	      	   mov  	r2,r5
	      	   jsr  	r13,r0,__mulu
	      	   mov  	r7,r1
	      	   add  	r6,r7,_ary
	      	   mov  	r5,r3
	      	   add  	r5,r6
	      	   jsr  	r13,r0,_rand
	      	   sto  	r1,r5
	      	   pop  	r5,r14
	      	   inc  	r3,1
	      	   mov  	r15,r0,Test2_12
Test2_13:
Test2_10:
	      	   inc  	r4,1
	      	   mov  	r15,r0,Test2_8
Test2_9:
	# 	for (x = 0; x < 10; x++)  {
	      	   sto  	r0,r12,-1
Test2_16:
	      	   ld   	r5,r12,-1
	      	   cmp  	r5,r0,10
	      	pl.mov  	r15,r0,Test2_17
	# 		printf("Hello World!");
	      	   mov  	r5,r0,Test2_1
	      	   push 	r5,r14
	      	   jsr  	r13,r0,_printf
	      	   inc  	r14,1
	      	   ld   	r5,r12,-1
	      	   inc  	r5,1
	      	   sto  	r5,r12,-1
	      	   mov  	r15,r0,Test2_16
Test2_17:
	# 	naked switch(argc) {
	      	   ld   	r5,r12,2
	# 	case 1:	printf("One"); break;
	      	   cmp  	r6,r5,1
	      	 z.inc  	r15,Test2_25-PC
	# 	case 2:	printf("Two"); break;
	      	   cmp  	r6,r5,2
	      	 z.mov  	r15,r0,Test2_26
	# 	case 3:	printf("Three"); break;
	      	   cmp  	r6,r5,3
	      	 z.mov  	r15,r0,Test2_27
	      	   mov  	r15,r0,Test2_20
Test2_25:
	      	   mov  	r5,r0,Test2_2
	      	   push 	r5,r14
	      	   jsr  	r13,r0,_printf
	      	   inc  	r14,1
	      	   mov  	r15,r0,Test2_20
Test2_26:
	      	   mov  	r5,r0,Test2_3
	      	   push 	r5,r14
	      	   jsr  	r13,r0,_printf
	      	   inc  	r14,1
	      	   inc  	r15,Test2_20-PC
Test2_27:
	      	   mov  	r5,r0,Test2_4
	      	   push 	r5,r14
	      	   jsr  	r13,r0,_printf
	      	   inc  	r14,1
Test2_20:
	# 	exit(0);
	      	   push 	r0,r14
	      	   jsr  	r13,r0,_exit
	      	   inc  	r14,1
	      	   pop  	r4,r14
	      	   pop  	r3,r14
	      	   mov  	r14,r12
	      	   pop  	r12,r14
	      	   pop  	r13,r14
	      	   mov  	r15,r13
#	rodata
#	align	2
Test2_4:	# Three
	WORD	84,104,114,101,101,0
Test2_3:	# Two
	WORD	84,119,111,0
Test2_2:	# One
	WORD	79,110,101,0
Test2_1:	# Hello World!
	WORD	72,101,108,108,111,32,87,111
	WORD	114,108,100,33,0
#	extern	_main
#	extern	_rand
#	extern	_exit
#	global	_ary
#	extern	_printf
#	code
_print:
	# void print(char *ptr)
	      	   push 	r13,r14
	      	   push 	r12,r14
	      	   mov  	r12,r14
	      	   push 	r3,r14
	      	   ld   	r3,r12,2
Test3_4:
	      	   ld   	r5,r3
	      	   add  	r5,r0
	      	 z.inc  	r15,Test3_5-PC
	# 		outch(*ptr);
	      	   ld   	r5,r3
	      	   push 	r5,r14
	      	   jsr  	r13,r0,_outch
	      	   inc  	r14,1
	# 		ptr++;
	      	   inc  	r3,1
	      	   dec  	r15,Test3_4-PC
Test3_5:
	      	   pop  	r3,r14
	      	   mov  	r14,r12
	      	   pop  	r12,r14
	      	   pop  	r13,r14
	      	   mov  	r15,r13
_main:
	# void print(char *ptr)
	      	   push 	r13,r14
	# 	print("Hello world\r\n");
	      	   mov  	r5,r0,Test3_7
	      	   push 	r5,r14
	      	   jsr  	r13,r0,_print
	      	   inc  	r14,1
	      	   pop  	r13,r14
	      	   mov  	r15,r13


#	rodata
#	align	2
Test3_7:	# Hello world
	word	72,101,108,108,111,32,119,111
	word	114,108,100,13,10,0
#	global	_main
#	extern	_outch
#	extern	_print
#	code
	# int abs(register int a)
_abs:
	# 	return a < 0 ? -a : a;
	      	   cmp  	r8,r0
	      	pl.inc  	r15,TestAbs_4-PC
	      	   not  	r1,r8,-1
	      	   inc  	r15,TestAbs_5-PC
TestAbs_4:
	      	   mov  	r1,r8
TestAbs_5:
	      	   mov  	r15,r13
	# int abs(register int a)
_min:
	# 	return a < b ? a : b;
	      	   cmp  	r8,r9
	      	pl.inc  	r15,TestAbs_11-PC
	      	   mov  	r1,r8
	      	   inc  	r15,TestAbs_12-PC
TestAbs_11:
	      	   mov  	r1,r9
TestAbs_12:
	      	   mov  	r15,r13
	# int abs(register int a)
_max:
	# 	return a > b ? a : b;
	      	   cmp  	r8,r9
	      	mi.inc  	r15,TestAbs_18-PC
	      	   cmp  	r8,r9
	      	 z.inc  	r15,TestAbs_18-PC
	      	   mov  	r1,r8
	      	   inc  	r15,TestAbs_19-PC
TestAbs_18:
	      	   mov  	r1,r9
TestAbs_19:
	      	   mov  	r15,r13
	# int abs(register int a)
_minu:
	# 	return a < b ? a : b;
	      	   cmp  	r8,r9
	      	nc.inc  	r15,TestAbs_24-PC
	      	   mov  	r1,r8
	      	   inc  	r15,TestAbs_25-PC
TestAbs_24:
	      	   mov  	r1,r9
TestAbs_25:
	      	   mov  	r15,r13
#	rodata
#	extern	_minu
#	extern	_abs
#	extern	_min
#	extern	_max
#	code
_TestArrayAssign:
	# void TestArrayAssign()
	      	   push 	r13,r14
	      	   push 	r12,r14
	      	   mov  	r12,r14
	      	   sub  	r14,r0,53
	      	   push 	r3,r14
	      	   push 	r4,r14
	      	   mov  	r5,r12,-15
	      	   mov  	r3,r5
	      	   mov  	r5,r12,-53
	# 	int x[3][5];
	      	   mov  	r4,r5
	# 	y[0] = 1;
	      	   mov  	r5,r0,1
	      	   sto  	r5,r12,-23
	# 	y[1] = 2;
	      	   mov  	r5,r12,-23
	      	   mov  	r6,r0,2
	      	   sto  	r6,r5,1
	# 	y[2] = 2;
	      	   mov  	r5,r12,-23
	      	   mov  	r6,r0,2
	      	   sto  	r6,r5,2
	# 	y[3] = 2;
	      	   mov  	r5,r12,-23
	      	   mov  	r6,r0,2
	      	   sto  	r6,r5,3
	# 	y[4] = 2;
	      	   mov  	r5,r12,-23
	      	   mov  	r6,r0,2
	      	   sto  	r6,r5,4
	# 	y[5] = 2;
	      	   mov  	r5,r12,-23
	      	   mov  	r6,r0,2
	      	   sto  	r6,r5,5
	# 	y[6] = 2;
	      	   mov  	r5,r12,-23
	      	   mov  	r6,r0,2
	      	   sto  	r6,r5,6
	# 	y[7] = 2;
	      	   mov  	r5,r12,-23
	      	   mov  	r6,r0,2
	      	   sto  	r6,r5,7
	# 	y = {1,2,3,4,5,6,7,8};
	      	   mov  	r5,r12,-23
	      	   mov  	r6,r5
	      	   mov  	r7,r0,1
	      	   sto  	r7,r6,0
	      	   mov  	r7,r0,2
	      	   sto  	r7,r6,1
	      	   mov  	r7,r0,3
	      	   sto  	r7,r6,2
	      	   mov  	r7,r0,4
	      	   sto  	r7,r6,3
	      	   mov  	r7,r0,5
	      	   sto  	r7,r6,4
	      	   mov  	r7,r0,6
	      	   sto  	r7,r6,5
	      	   mov  	r7,r0,7
	      	   sto  	r7,r6,6
	      	   mov  	r7,r0,8
	      	   sto  	r7,r6,7
	# 	x[0][0] = 1;
	      	   mov  	r5,r0,1
	      	   sto  	r5,r3
	# 	x[0][1] = 2;
	      	   mov  	r5,r0,2
	      	   sto  	r5,r3,1
	# 	x[0][2] = 2;
	      	   mov  	r5,r0,2
	      	   sto  	r5,r3,2
	# 	x[0][3] = 2;
	      	   mov  	r5,r0,2
	      	   sto  	r5,r3,3
	# 	x[0][4] = 2;
	      	   mov  	r5,r0,2
	      	   sto  	r5,r3,4
	# 	x[1][0] = 3;
	      	   mov  	r5,r0,3
	      	   sto  	r5,r3,5
	# 	x[1][1] = 3;
	      	   mov  	r5,r0,3
	      	   sto  	r5,r3,6
	# 	x[1][2] = 3;
	      	   mov  	r5,r0,3
	      	   sto  	r5,r3,7
	# 	x[1][3] = 3;
	      	   mov  	r5,r0,3
	      	   sto  	r5,r3,8
	# 	x[1][4] = 5;
	      	   mov  	r5,r0,5
	      	   sto  	r5,r3,9
	# 	x[2][0] = 5;
	      	   mov  	r5,r0,5
	      	   sto  	r5,r3,10
	# 	x[2][1] = 5;
	      	   mov  	r5,r0,5
	      	   sto  	r5,r3,11
	# 	x[2][2] = 5;
	      	   mov  	r5,r0,5
	      	   sto  	r5,r3,12
	# 	x[2][3] = 5;
	      	   mov  	r5,r0,5
	      	   sto  	r5,r3,13
	# 	x[2][4] = 5;
	      	   mov  	r5,r0,5
	      	   sto  	r5,r3,14
	# 	z[0][0][0] = 1;
	      	   mov  	r5,r0,1
	      	   sto  	r5,r4
	# 	z[0][0][1] = 1;
	      	   mov  	r5,r0,1
	      	   sto  	r5,r4,1
	# 	z[0][0][2] = 1;
	      	   mov  	r5,r0,1
	      	   sto  	r5,r4,2
	# 	z[0][0][3] = 1;
	      	   mov  	r5,r0,1
	      	   sto  	r5,r4,3
	# 	z[0][0][4] = 1;
	      	   mov  	r5,r0,1
	      	   sto  	r5,r4,4
	# 	z[0][1][0] = 2;
	      	   mov  	r5,r0,2
	      	   sto  	r5,r4,5
	# 	z[0][1][1] = 2;
	      	   mov  	r5,r0,2
	      	   sto  	r5,r4,6
	# 	z[0][1][2] = 2;
	      	   mov  	r5,r0,2
	      	   sto  	r5,r4,7
	# 	z[0][1][3] = 2;
	      	   mov  	r5,r0,2
	      	   sto  	r5,r4,8
	# 	z[0][1][4] = 2;
	      	   mov  	r5,r0,2
	      	   sto  	r5,r4,9
	# 	z[0][2][0] = 2;
	      	   mov  	r5,r0,2
	      	   sto  	r5,r4,10
TestArrayAssign_4:
	      	   pop  	r4,r14
	      	   pop  	r3,r14
	      	   mov  	r14,r12
	      	   pop  	r12,r14
	      	   pop  	r13,r14
	      	   mov  	r15,r13


_TestArrayAssign2:
	# void TestArrayAssign()
	      	   push 	r13,r14
	      	   push 	r12,r14
	      	   mov  	r12,r14
	# 	int x[3][5];
	      	   dec  	r14,15
	# 	x[2] = {10,9,8,7,6};
	      	   mov  	r6,r0,10
	      	   mov  	r7,r12,-15
	      	   mov  	r5,r6
	      	   add  	r5,r7
	      	   mov  	r6,r5
	      	   mov  	r7,r0,10
	      	   sto  	r7,r6,0
	      	   mov  	r7,r0,9
	      	   sto  	r7,r6,1
	      	   mov  	r7,r0,8
	      	   sto  	r7,r6,2
	      	   mov  	r7,r0,7
	      	   sto  	r7,r6,3
	      	   mov  	r7,r0,6
	      	   sto  	r7,r6,4
TestArrayAssign_8:
	      	   mov  	r14,r12
	      	   pop  	r12,r14
	      	   pop  	r13,r14
	      	   mov  	r15,r13


_TestArrayAssign3:
	# void TestArrayAssign()
	      	   push 	r13,r14
	      	   push 	r12,r14
	      	   mov  	r12,r14
	      	   sub  	r14,r0,63
	      	   push 	r3,r14
	      	   push 	r4,r14
	      	   ld   	r3,r12,-2
	# 	int j,k,m;
	      	   ld   	r4,r12,-3
	# 	for (m = 0; m < 3; m++) {
	      	   mov  	r4,r0,0
TestArrayAssign_12:
	      	   cmp  	r4,r0,3
	      	pl.mov  	r15,r0,TestArrayAssign_13
	# 		for (j = 0; j < 4; j++) {
	      	   sto  	r0,r12,-1
TestArrayAssign_16:
	      	   ld   	r5,r12,-1
	      	   cmp  	r5,r0,4
	      	pl.mov  	r15,r0,TestArrayAssign_17
	# 			for (k = 0; k < 5; k++)
	      	   mov  	r3,r0,0
TestArrayAssign_20:
	      	   cmp  	r3,r0,5
	      	pl.mov  	r15,r0,TestArrayAssign_21
	# 				x[m][j][k] = rand();
	      	   push 	r5,r14
	      	   ld   	r5,r12,-1
	      	   push 	r6,r14
	      	   mov  	r6,r0,5
	      	   mov  	r1,r5
	      	   mov  	r2,r6
	      	   jsr  	r13,r0,__mulu
	      	   mov  	r7,r1
	      	   push 	r7,r14
	      	   mov  	r7,r0,20
	      	   mov  	r1,r4
	      	   mov  	r2,r7
	      	   jsr  	r13,r0,__mulu
	      	   mov  	r6,r1
	      	   mov  	r7,r12,-63
	      	   mov  	r5,r6
	      	   add  	r5,r7
	      	   mov  	r6,r7
	      	   add  	r6,r5
	      	   pop  	r7,r14
	      	   mov  	r5,r3
	      	   add  	r5,r6
	      	   pop  	r6,r14
	      	   jsr  	r13,r0,_rand
	      	   sto  	r1,r5
	      	   pop  	r5,r14
	      	   inc  	r3,1
	      	   mov  	r15,r0,TestArrayAssign_20
TestArrayAssign_21:
	      	   ld   	r5,r12,-1
	      	   inc  	r5,1
	      	   sto  	r5,r12,-1
	      	   mov  	r15,r0,TestArrayAssign_16
TestArrayAssign_17:
	      	   inc  	r4,1
	      	   mov  	r15,r0,TestArrayAssign_12
TestArrayAssign_13:
	      	   pop  	r4,r14
	      	   pop  	r3,r14
	      	   mov  	r14,r12
	      	   pop  	r12,r14
	      	   pop  	r13,r14
	      	   mov  	r15,r13


#	rodata
#	extern	_rand
#	global	_TestArrayAssign
#	global	_TestArrayAssign2
#	global	_TestArrayAssign3
#	code
_TestArrayY:
	      	   push 	r13
	      	   push 	r12
	      	   mov  	r12,r14
	      	   dec  	r14,8
	# 	y = {1,2,3,4,5,6,7,8};
	      	   mov  	r5,r0
	      	   add  	r5,r12,-8
	      	   mov  	r6,r5
	      	   mov  	r7,r0,1
	      	   sto  	r7,r6,0
	      	   mov  	r7,r0,2
	      	   sto  	r7,r6,1
	      	   mov  	r7,r0,3
	      	   sto  	r7,r6,2
	      	   mov  	r7,r0,4
	      	   sto  	r7,r6,3
	      	   mov  	r7,r0,5
	      	   sto  	r7,r6,4
	      	   mov  	r7,r0,6
	      	   sto  	r7,r6,5
	      	   mov  	r7,r0,7
	      	   sto  	r7,r6,6
	      	   mov  	r7,r0,8
	      	   sto  	r7,r6,7
	      	   mov  	r14,r12
	      	   pop  	r13
	      	   pop  	r12
	      	   mov  	r15,r13
#	rodata
#	extern	_TestArrayY
#	code
_TestAsm:
	# int TestAsm(register int a, register int b)
	      	   push 	r13
	# 	asm __leafs {
	      	        	
			push	r8
			push	r9
			jsr		a_sub
			inc		r14,2
	      	   pop  	r13
	      	   mov  	r15,r13
	# int TestAsm(register int a, register int b)
_TestAsm2:
	# 	asm {
	      	        	
			add		r8,r0,1
#	rodata
#	extern	_TestAsm
#	extern	_TestAsm2
#	code
	# void TestCheck(int a, int b, int c)
_TestCheck:
	      	   push 	r12,r14
	      	   mov  	r12,r14
	# 	__check(a;b;c);
	      	   ld   	r1,r12,1
	      	   ld   	r5,r12,2
	      	   ld   	r6,r12,3
	      	   cmp  	r1,r5
	      	mi.inc  	r15,TestCheck_4-PC
	      	   cmp  	r1,r6
	      	mi.inc  	r15,TestCheck_5-PC
TestCheck_4:
	      	   putpsr	15
TestCheck_5:
	      	   mov  	r14,r12
	      	   pop  	r12,r14
	      	   mov  	r15,r13
	# void TestCheck(int a, int b, int c)
_TestCheck:
	      	   push 	r12,r14
	      	   mov  	r12,r14
	# 	__check(a;b;c);
	      	   ld   	r1,r12,1
	      	   ld   	r5,r12,2
	      	   ld   	r6,r12,3
	      	   ld   	r7,r12,4
	      	   ld   	r3,r12,5
	      	   ld   	r4,r12,6
	      	   cmp  	r1,r6
	      	   cmpc 	r5,r7
	      	mi.inc  	r15,TestCheck_10-PC
	      	   cmp  	r1,r3
	      	   cmpc 	r5,r4
	      	mi.inc  	r15,TestCheck_11-PC
TestCheck_10:
	      	   putpsr	15
TestCheck_11:
	      	   mov  	r14,r12
	      	   pop  	r12,r14
	      	   mov  	r15,r13
	# void TestCheck(int a, int b, int c)
_TestCheck:
	      	   push 	r12,r14
	      	   mov  	r12,r14
	# 	__check(a;0;1024);
	      	   ld   	r1,r12,1
	      	   ld   	r5,r12,2
	      	   mov  	r6,r0,0
	      	   mov  	r7,r0,1024
	      	   cmp  	r1,r6
	      	   cmpc 	r5,r0
	      	mi.inc  	r15,TestCheck_16-PC
	      	   cmp  	r1,r7
	      	   cmpc 	r5,r0
	      	mi.inc  	r15,TestCheck_17-PC
TestCheck_16:
	      	   putpsr	15
TestCheck_17:
	      	   mov  	r14,r12
	      	   pop  	r12,r14
	      	   mov  	r15,r13
#	rodata
#	extern	_TestCheck
#	extern	_TestCheck
#	extern	_TestCheck
#	code
_TestDivmod:
	# int TestDivmod(int a, int b)
	      	   push 	r13,r14
	      	   push 	r12,r14
	      	   mov  	r12,r14
	# 	return a / b;
	      	   ld   	r6,r12,2
	      	   ld   	r7,r12,3
	      	   mov  	r1,r6
	      	   mov  	r2,r7
	      	   jsr  	r13,r0,__div
	      	   mov  	r14,r12
	      	   pop  	r12,r14
	      	   pop  	r13,r14
	      	   mov  	r15,r13
_TestDivmod2:
	# int TestDivmod(int a, int b)
	      	   push 	r13,r14
	      	   push 	r12,r14
	      	   mov  	r12,r14
	# 	return a / 10;
	      	   ld   	r6,r12,2
	      	   mov  	r1,r6
	      	   mov  	r2,r0,10
	      	   jsr  	r13,r0,__div
	      	   mov  	r14,r12
	      	   pop  	r12,r14
	      	   pop  	r13,r14
	      	   mov  	r15,r13
_TestMod:
	# int TestDivmod(int a, int b)
	      	   push 	r13,r14
	      	   push 	r12,r14
	      	   mov  	r12,r14
	# 	return a % b;
	      	   ld   	r6,r12,2
	      	   ld   	r7,r12,3
	      	   mov  	r1,r6
	      	   mov  	r2,r7
	      	   jsr  	r13,r0,__mod
	      	   mov  	r14,r12
	      	   pop  	r12,r14
	      	   pop  	r13,r14
	      	   mov  	r15,r13
	# int TestDivmod(int a, int b)
_TestDivmod3:
	      	   push 	r12,r14
	      	   mov  	r12,r14
	# 	a /= b;
	      	   ld   	r1,r12,1
	      	   ld   	r5,r12,2
	      	   mov  	r2,r5
	      	   mov  	r13,r15,2
	      	   mov  	r15,r0,__div
	      	   sto  	r1,r12,1
	# 	return a;
	      	   ld   	r1,r12,1
	      	   mov  	r14,r12
	      	   pop  	r12,r14
	      	   mov  	r15,r13
_TestModu:
	# int TestDivmod(int a, int b)
	      	   push 	r13,r14
	# 	return a % b;
	      	   mov  	r1,r8
	      	   mov  	r2,r9
	      	   jsr  	r13,r0,__modu
	      	   pop  	r13,r14
	      	   mov  	r15,r13
#	rodata
#	extern	_TestMod
#	extern	_TestDivmod
#	extern	_TestDivmod2
#	extern	_TestModu
#	extern	_TestDivmod3
#	code
	# int TestDo(int c)
_TestDo:
	      	   push 	r12,r14
	      	   mov  	r12,r14
TestDo_4:
	# 		c--;
	      	   ld   	r1,r12,1
	      	   dec  	r1,1
	      	   sto  	r1,r12,1
	      	   ld   	r1,r12,1
	      	   cmp  	r1,r0
	      	 z.inc  	r15,TestDo_6-PC
	      	   cmp  	r1,r0
	      	pl.inc  	r15,TestDo_4-PC
TestDo_6:
	      	   mov  	r14,r12
	      	   pop  	r12,r14
	      	   mov  	r15,r13
	# int TestDo(int c)
_TestDo1:
	      	   push 	r12,r14
	      	   mov  	r12,r14
TestDo_11:
	# 		d++;
	      	   ld   	r1,r12,1
	      	   inc  	r1,1
	      	   sto  	r1,r12,1
	      	   ld   	r1,r12,1
	      	   cmp  	r1,r0,10
	      	nz.inc  	r15,TestDo_11-PC
	      	   mov  	r14,r12
	      	   pop  	r12,r14
	      	   mov  	r15,r13
	# int TestDo(int c)
_TestWhile:
	      	   push 	r12,r14
	      	   mov  	r12,r14
TestDo_17:
	      	   ld   	r1,r12,1
	      	   cmp  	r1,r0
	      	mi.inc  	r15,TestDo_18-PC
	# 		e--;
	      	   ld   	r1,r12,1
	      	   dec  	r1,1
	      	   sto  	r1,r12,1
	      	   inc  	r15,TestDo_17-PC
TestDo_18:
	      	   mov  	r14,r12
	      	   pop  	r12,r14
	      	   mov  	r15,r13
	# int TestDo(int c)
_TestWhile2:
	      	   push 	r12,r14
	      	   mov  	r12,r14
	# 	int x;
	      	   dec  	r14,1
	# 	x = 0;
	      	   sto  	r0,r12,-1
TestDo_23:
	# 		g++;
	      	   ld   	r1,r12,1
	      	   inc  	r1,1
	      	   sto  	r1,r12,1
	      	   ld   	r1,r12,1
	      	   ld   	r5,r12,-1
	      	   cmp  	r1,r5
	      	mi.inc  	r15,TestDo_23-PC
	      	   cmp  	r1,r5
	      	 z.inc  	r15,TestDo_23-PC
	      	   mov  	r14,r12
	      	   pop  	r12,r14
	      	   mov  	r15,r13
#	rodata
#	extern	_TestWhile2
#	extern	_TestDo
#	extern	_TestDo1
#	extern	_TestWhile
#	code
_TestFor:
	# int TestFor()
	      	   push 	r13,r14
	      	   push 	r12,r14
	      	   mov  	r12,r14
	      	   dec  	r14,3
	      	   push 	r3,r14
	      	   push 	r4,r14
	      	   ld   	r3,r12,-1
	# 	int x, y, z;
	      	   ld   	r4,r12,-2
	# 	for (x = 1; x < 100; x++) {
	      	   mov  	r3,r0,1
TestFor_4:
	      	   cmp  	r3,r0,100
	      	pl.inc  	r15,TestFor_5-PC
	# 		putch('a');
	      	   mov  	r5,r0,97
	      	   push 	r5,r14
	      	   jsr  	r13,r0,_putch
	      	   inc  	r14,1
	      	   inc  	r3,1
	      	   inc  	r15,TestFor_4-PC
TestFor_5:
	# 	y = 50;
	      	   mov  	r4,r0,50
TestFor_8:
	      	   cmp  	r4,r0
	      	mi.mov  	r15,r0,TestFor_9
	      	   cmp  	r4,r0
	      	 z.inc  	r15,TestFor_9-PC
	# 		putch('b');
	      	   mov  	r5,r0,98
	      	   push 	r5,r14
	      	   jsr  	r13,r0,_putch
	      	   inc  	r14,1
	# 		--y;
	      	   dec  	r4,1
TestFor_10:
	      	   mov  	r15,r0,TestFor_8
TestFor_9:
	# 	for (z = 1; z < 10; ) ;
	      	   mov  	r5,r0,1
	      	   sto  	r5,r12,-3
TestFor_11:
	      	   ld   	r5,r12,-3
	      	   cmp  	r5,r0,10
	      	pl.inc  	r15,TestFor_12-PC
	      	   inc  	r15,TestFor_11-PC
TestFor_12:
	# 	for (x = 1; x < 100; x++) {
	      	   mov  	r3,r0,1
TestFor_15:
	      	   cmp  	r3,r0,100
	      	pl.mov  	r15,r0,TestFor_16
	# 		for (y = 50; y > 0; --y) {
	      	   mov  	r4,r0,50
TestFor_19:
	      	   cmp  	r4,r0
	      	mi.mov  	r15,r0,TestFor_20
	      	   cmp  	r4,r0
	      	 z.mov  	r15,r0,TestFor_20
	# 			for (z = 1; z < 10; z++) {
	      	   mov  	r5,r0,1
	      	   sto  	r5,r12,-3
TestFor_22:
	      	   ld   	r5,r12,-3
	      	   cmp  	r5,r0,10
	      	pl.mov  	r15,r0,TestFor_23
	# 				putch(rand());
	      	   jsr  	r13,r0,_rand
	      	   push 	r1,r14
	      	   jsr  	r13,r0,_putch
	      	   inc  	r14,1
	      	   ld   	r5,r12,-3
	      	   inc  	r5,1
	      	   sto  	r5,r12,-3
	      	   mov  	r15,r0,TestFor_22
TestFor_23:
	      	   dec  	r4,1
	      	   mov  	r15,r0,TestFor_19
TestFor_20:
	      	   inc  	r3,1
	      	   mov  	r15,r0,TestFor_15
TestFor_16:
	      	   pop  	r4,r14
	      	   pop  	r3,r14
	      	   mov  	r14,r12
	      	   pop  	r12,r14
	      	   pop  	r13,r14
	      	   mov  	r15,r13


_TestFor2:
	# int TestFor()
	      	   push 	r13,r14
TestFor_30:
	# 		putch('h');
	      	   mov  	r5,r0,104
	      	   push 	r5,r14
	      	   jsr  	r13,r0,_putch
	      	   inc  	r14,1
	      	   inc  	r15,TestFor_30-PC
	      	   pop  	r13,r14
	      	   mov  	r15,r13


#	rodata
#	extern	_rand
#	global	_TestFor
#	global	_TestFor2
#	extern	_putch
#	code
	# int SomeFunc(int a, int b, register int c)
_SomeFunc:
	      	   push 	r12,r14
	      	   mov  	r12,r14
	# 	return a + b - c;
	      	   ld   	r6,r12,1
	      	   ld   	r7,r12,2
	      	   mov  	r5,r6
	      	   add  	r5,r7
	      	   mov  	r1,r5
	      	   sub  	r1,r8
	      	   mov  	r14,r12
	      	   pop  	r12,r14
	      	   mov  	r15,r13
_main:
	# int SomeFunc(int a, int b, register int c)
	      	   push 	r13,r14
	# 	SomeFunc(10,20,30);
	      	   push 	r8,r14
	      	   mov  	r5,r0,30
	      	   mov  	r8,r5
	      	   mov  	r6,r0,20
	      	   push 	r6,r14
	      	   mov  	r7,r0,10
	      	   push 	r7,r14
	      	   jsr  	r13,r0,_SomeFunc
	      	   inc  	r14,2
	      	   pop  	r8,r14
	      	   pop  	r13,r14
	      	   mov  	r15,r13


#	rodata
#	global	_main
#	extern	_SomeFunc
#	code
	# int TestIf(int a, int b)
_TestIf:
	      	   push 	r12,r14
	      	   mov  	r12,r14
	# 	if (a < b)
	      	   ld   	r1,r12,1
	      	   ld   	r5,r12,2
	      	   cmp  	r1,r5
	      	pl.inc  	r15,TestIf_4-PC
	# 		return a;
	      	   ld   	r1,r12,1
TestIf_7:
	      	   mov  	r14,r12
	      	   pop  	r12,r14
	      	   mov  	r15,r13
TestIf_4:
	# 	elsif (a==10)
	      	   ld   	r1,r12,1
	      	   cmp  	r1,r0,10
	# 		return 10;
	      	nz.inc  	r15,TestIf_8-PC
	      	   mov  	r1,r0,10
	      	   mov  	r15,r0,TestIf_7
	      	   inc  	r15,TestIf_9-PC
TestIf_8:
	# 		return b;
	      	   ld   	r1,r12,2
	      	   mov  	r15,r0,TestIf_7
TestIf_9:
	      	   mov  	r15,r0,TestIf_7
	# int TestIf(int a, int b)
_TestIf2:
	      	   push 	r12,r14
	      	   mov  	r12,r14
	# 	if (a and b)
	      	   ld   	r1,r12,1
	      	   add  	r1,r0
	      	 z.mov  	r15,r0,TestIf_13
	      	   ld   	r1,r12,2
	      	   add  	r1,r0
	      	 z.inc  	r15,TestIf_13-PC
	# 		return a;
	      	   ld   	r1,r12,1
TestIf_15:
	      	   mov  	r14,r12
	      	   pop  	r12,r14
	      	   mov  	r15,r13
TestIf_13:
	# 	elsif (a or b)
	      	   ld   	r1,r12,1
	      	   add  	r1,r0
	      	nz.inc  	r15,TestIf_18-PC
	      	   ld   	r1,r12,2
	      	   add  	r1,r0
	      	 z.inc  	r15,TestIf_16-PC
TestIf_18:
	      	   mov  	r1,r0,10
	      	   mov  	r15,r0,TestIf_15
	      	   inc  	r15,TestIf_17-PC
TestIf_16:
	# 		return b;
	      	   ld   	r1,r12,2
	      	   mov  	r15,r0,TestIf_15
TestIf_17:
	      	   mov  	r15,r0,TestIf_15
#	rodata
#	extern	_TestIf
#	extern	_TestIf2
#	code
_TestIncDec:
	# void TestIncDec()
	      	   push 	r13
	      	   push 	r12
	      	   mov  	r12,r14
	# 	int x[4][5];
	      	   sub  	r14,r0,20
	# 	(x[2])++ = {1,2,3,4,5};
	      	   mov  	r6,r0,10
	      	   mov  	r7,r12,-20
	      	   mov  	r5,r6
	      	   add  	r5,r7
	      	   mov  	r6,r5
	      	   mov  	r7,r0,1
	      	   sto  	r7,r6,0
	      	   mov  	r7,r0,2
	      	   sto  	r7,r6,1
	      	   mov  	r7,r0,3
	      	   sto  	r7,r6,2
	      	   mov  	r7,r0,4
	      	   sto  	r7,r6,3
	      	   mov  	r7,r0,5
	      	   sto  	r7,r6,4
TestIncDec_4:
	      	   mov  	r14,r12
	      	   pop  	r12
	      	   pop  	r13
	      	   mov  	r15,r13


#	rodata
#	global	_TestIncDec
#	code
_myint:
	# void interrupt myint()
	      	   push 	r1,r14
	      	   push 	r2,r14
	      	   push 	r3,r14
	      	   push 	r4,r14
	      	   push 	r5,r14
	      	   push 	r6,r14
	      	   push 	r7,r14
	      	   push 	r8,r14
	      	   push 	r9,r14
	      	   push 	r10,r14
	      	   push 	r11,r14
	      	   push 	r12,r14
	      	   push 	r13,r14
	      	   push 	r13,r14
	      	   push 	r12,r14
	      	   mov  	r12,r14
	# 	printf("Hello again.");
	      	   mov  	r5,r0,TestInt_1
	      	   push 	r5,r14
	      	   jsr  	r13,r0,_printf
	      	   inc  	r14,1
	      	   mov  	r14,r12
	      	   pop  	r12,r14
	      	   pop  	r13,r14
	      	   pop  	r13,r14
	      	   pop  	r12,r14
	      	   pop  	r11,r14
	      	   pop  	r10,r14
	      	   pop  	r9,r14
	      	   pop  	r8,r14
	      	   pop  	r7,r14
	      	   pop  	r6,r14
	      	   pop  	r5,r14
	      	   pop  	r4,r14
	      	   pop  	r3,r14
	      	   pop  	r2,r14
	      	   rti  


_BIOScall:
	# void interrupt myint()
	      	   push 	r2,r14
	      	   push 	r3,r14
	      	   push 	r4,r14
	      	   push 	r5,r14
	      	   push 	r6,r14
	      	   push 	r7,r14
	      	   push 	r8,r14
	      	   push 	r9,r14
	      	   push 	r10,r14
	      	   push 	r11,r14
	      	   push 	r12,r14
	      	   push 	r13,r14
	      	   push 	r12,r14
	# 	return -1;
	      	   mov  	r12,r14
	      	   mov  	r1,r0,65535
	      	   mov  	r14,r12
	      	   pop  	r12,r14
	      	   pop  	r13,r14
	      	   pop  	r12,r14
	      	   pop  	r11,r14
	      	   pop  	r10,r14
	      	   pop  	r9,r14
	      	   pop  	r8,r14
	      	   pop  	r7,r14
	      	   pop  	r6,r14
	      	   pop  	r5,r14
	      	   pop  	r4,r14
	      	   pop  	r3,r14
	      	   pop  	r2,r14
	      	   pop  	r1,r14
	      	   rti  


#	rodata
#	align	2
TestInt_1:	# Hello again.
	WORD	72,101,108,108,111,32,97,103
	WORD	97,105,110,46,0
#	global	_BIOScall
#	global	_myint
#	extern	_printf
#	code
#	data
#	code
	# long TestLong(int a, int b)
_TestLong:
	      	   push 	r12
	      	   mov  	r12,r14
	# 	long c, d, e;
	      	   dec  	r14,12
	# 	for (x = 0; x < 100000L; x++) {
	      	   sto  	r0,r12,-8
	      	   sto  	r0,r12,-7
TestLong_4:
	      	   ld   	r1,r12,-8
	      	   ld   	r5,r12,-7
	      	   cmp  	r1,r0,34464
	      	   cmpc 	r5,r0,1
	      	pl.mov  	r15,r0,TestLong_5
	# 		c = d + e + b - a;
	      	   push 	r1
	      	   push 	r5
	      	   ld   	r1,r12,-4
	      	   ld   	r5,r12,-3
	      	   push 	r6
	      	   push 	r7
	      	   ld   	r6,r12,-6
	      	   ld   	r7,r12,-5
	      	   mov  	r3,r1
	      	   mov  	r4,r5
	      	   add  	r3,r6
	      	   adc  	r4,r7
	      	   ld   	r1,r12,2
	      	   mov  	r5,r0
	      	   or   	r1,r1
	      	mi.mov  	r5,r0,-1
	      	   mov  	r6,r3
	      	   mov  	r7,r4
	      	   add  	r6,r1
	      	   adc  	r7,r5
	      	   ld   	r3,r12,1
	      	   mov  	r4,r0
	      	   or   	r3,r3
	      	mi.mov  	r4,r0,-1
	      	   mov  	r1,r6
	      	   mov  	r5,r7
	      	   sub  	r1,r3
	      	   sbc  	r5,r4
	      	   pop  	r7
	      	   pop  	r6
	      	   sto  	r1,r12,-2
	      	   sto  	r5,r12,-1
	      	   pop  	r5
	      	   pop  	r1
	# 		c = e * x;
	      	   ld   	r6,r12,-6
	      	   ld   	r7,r12,-5
	      	   ld   	r3,r12,-8
	      	   ld   	r4,r12,-7
	      	   mov  	r1,r6
	      	   mov  	r2,r7
	      	   push 	r3
	      	   push 	r4
	      	   jsr  	r13,r0,__mul32
	      	   pop  	r4
	      	   pop  	r3
	      	   mov  	r5,r2
	      	   sto  	r1,r12,-2
	      	   sto  	r5,r12,-1
	      	   ld   	r1,r12,-8
	      	   ld   	r5,r12,-7
	      	   inc  	r1,1
	      	   adc  	r5,r0
	      	   sto  	r1,r12,-8
	      	   sto  	r5,r12,-7
	      	   mov  	r15,r0,TestLong_4
TestLong_5:
	# 	x = c / d;
	      	   ld   	r6,r12,-2
	      	   ld   	r7,r12,-1
	      	   ld   	r3,r12,-4
	      	   ld   	r4,r12,-3
	      	   mov  	r1,r6
	      	   mov  	r2,r7
	      	   push 	r3
	      	   push 	r4
	      	   jsr  	r13,r0,__div32
	      	   pop  	r4
	      	   pop  	r3
	      	   mov  	r5,r2
	      	   sto  	r1,r12,-8
	      	   sto  	r5,r12,-7
	# 	d = (x >> 15) | (x << (31-15));
	      	   ld   	r6,r12,-8
	      	   ld   	r7,r12,-7
	      	   mov  	r3,r0,15
	      	   mov  	r4,r0
	      	   or   	r3,r3
	      	mi.mov  	r4,r0,-1
TestLong_8:
	      	   add  	r6,r0,0
	      	pl.add  	r0,r0,0
	      	mi.sub  	r0,r0,1
	      	   ror  	r7,r0,0
	      	   ror  	r6,r0,0
	      	   sub  	r3,r0,1
	      	nz.dec  	r15,TestLong_8-PC
	      	   ld   	r3,r12,-8
	      	   ld   	r4,r12,-7
	      	   push 	r1
	      	   push 	r5
	      	   mov  	r5,r0,31
	      	   sub  	r1,r5,15
	      	   mov  	r5,r0
	      	   or   	r1,r1
	      	mi.mov  	r5,r0,-1
TestLong_9:
	      	   add  	r3,r0,0
	      	   adc  	r4,r0,0
	      	   sub  	r1,r0,1
	      	nz.dec  	r15,TestLong_9-PC
	      	   mov  	r1,r6
	      	   mov  	r5,r7
	      	   or   	r1,r3
	      	   or   	r5,r4
	      	   sto  	r1,r12,-4
	      	   sto  	r5,r12,-3
	      	   pop  	r5
	      	   pop  	r1
	# 	r = d < x;
	      	   mov  	r1,r0,1
	      	   mov  	r5,r0
	      	   ld   	r6,r12,-4
	      	   ld   	r7,r12,-3
	      	   ld   	r3,r12,-8
	      	   ld   	r4,r12,-7
	      	   cmp  	r6,r3
	      	   cmpc 	r7,r4
	      	pl.mov  	r1,r0
	      	   sto  	r1,r12,-9
	# 	r2 = d > x;
	      	   mov  	r1,r0
	      	   mov  	r5,r0
	      	   ld   	r6,r12,-4
	      	   ld   	r7,r12,-3
	      	   ld   	r3,r12,-8
	      	   ld   	r4,r12,-7
	      	   cmp  	r6,r3
	      	   cmpc 	r7,r4
	      	pl.mov  	r1,r0,1
	      	   sto  	r1,r12,-12
	      	   sto  	r5,r12,-11
	# 	return c;
	      	   ld   	r1,r12,-2
	      	   ld   	r5,r12,-1
	      	   mov  	r2,r5
	      	   mov  	r14,r12
	      	   pop  	r12
	      	   mov  	r15,r13
#	rodata
#	extern	_TestLong
#	code
	# int TestLValue()
_TestLValue:
	      	   push 	r12,r14
	      	   mov  	r12,r14
	      	   dec  	r14,3
	      	   push 	r3,r14
	      	   mov  	r1,r12,-2
	# 	int x;
	      	   mov  	r3,r1
	# 	x = y + z;
	      	   ld   	r5,r3
	      	   ld   	r6,r12,-3
	      	   mov  	r1,r5
	      	   add  	r1,r6
	      	   sto  	r1,r12,-1
	# 	x = &y + 20;
	      	   mov  	r5,r0,20
	      	   mov  	r1,r3
	      	   add  	r1,r5
	      	   sto  	r1,r12,-1
	# 	x = y + &x;
	      	   ld   	r5,r3
	      	   mov  	r6,r12,-1
	      	   mov  	r1,r5
	      	   add  	r1,r6
	      	   sto  	r1,r12,-1
	      	   pop  	r3,r14
	      	   mov  	r14,r12
	      	   pop  	r12,r14
	      	   mov  	r15,r13


#	rodata
#	global	_TestLValue
#	code
	# int TestPreload(int a)
_TestPreload:
	      	   push 	r12,r14
	      	   mov  	r12,r14
	      	   dec  	r14,1
	# 	int x = a < 10;
	      	   mov  	r1,r0,1
	      	   ld   	r5,r12,1
	      	   cmp  	r5,r0,10
	      	pl.mov  	r1,r0
	      	   sto  	r1,r12,-1
	# 	return(x);
	      	   ld   	r1,r12,-1
	      	   mov  	r14,r12
	      	   pop  	r12,r14
	      	   mov  	r15,r13
#	rodata
#	extern	_TestPreload
#	code
	# int TestRotate(int a, int b)
_TestRotate:
	      	   push 	r12,r14
	      	   mov  	r12,r14
	# 	return ((a << b) | (a >> (16-b)));
	      	   ld   	r6,r12,1
	      	   ld   	r7,r12,2
	      	   mov  	r5,r6
TestRotate_4:
	      	   add  	r5,r5
	      	   sub  	r7,r0,1
	      	nz.inc  	r15,TestRotate_4-PC
	      	   ld   	r7,r12,1
	      	   push 	r1,r14
	      	   push 	r5,r14
	      	   mov  	r5,r0,16
	      	   push 	r6,r14
	      	   ld   	r6,r12,2
	      	   mov  	r1,r5
	      	   sub  	r1,r6
	      	   mov  	r6,r7
TestRotate_5:
	      	   asr  	r6,r6
	      	   sub  	r1,r0,1
	      	nz.inc  	r15,TestRotate_5-PC
	      	   mov  	r1,r5
	      	   or   	r1,r6
	      	   pop  	r6,r14
	      	   pop  	r5,r14
	      	   pop  	r1,r14
	      	   mov  	r14,r12
	      	   pop  	r12,r14
	      	   mov  	r15,r13
	# int TestRotate(int a, int b)
_TestRotate2:
	# 	return ((a << b) | (a >> (16-b)));
	      	   mov  	r5,r8
TestRotate_10:
	      	   add  	r5,r5
	      	   sub  	r9,r0,1
	      	nz.inc  	r15,TestRotate_10-PC
	      	   push 	r1,r14
	      	   mov  	r1,r0,16
	      	   mov  	r7,r1
	      	   sub  	r7,r9
	      	   mov  	r6,r8
TestRotate_11:
	      	   asr  	r6,r6
	      	   sub  	r7,r0,1
	      	nz.inc  	r15,TestRotate_11-PC
	      	   mov  	r1,r5
	      	   or   	r1,r6
	      	   pop  	r1,r14
	      	   mov  	r15,r13
	# int TestRotate(int a, int b)
_TestRotate3:
	      	   push 	r12,r14
	      	   mov  	r12,r14
	# 	return ((a << b) | (a >> (32-b)));
	      	   ld   	r7,r12,1
	      	   ld   	r3,r12,2
	      	   push 	r1,r14
	      	   ld   	r4,r12,3
	      	   ld   	r1,r12,4
	      	   mov  	r6,r7
	      	   mov  
TestRotate_16:
	      	   add  	r6,r6
	      	   adc  
	      	   sub  	r4,r0,1
	      	nz.inc  	r15,TestRotate_16-PC
	      	   ld   	r3,r12,1
	      	   ld   	r4,r12,2
	      	   push 	r5,r14
	      	   mov  	r5,r0,32
	      	   push 	r6,r14
	      	   push 	r7,r14
	      	   ld   	r6,r12,3
	      	   ld   	r7,r12,4
	      	   mov  	r1,r5
	      	   sub  	r1,r6
	      	   mov  	r7,r3
	      	   mov  
TestRotate_17:
	      	   asr  
	      	   ror  	r7,r7
	      	   sub  	r1,r0,1
	      	nz.inc  	r15,TestRotate_17-PC
	      	   mov  	r1,r6
	      	   mov  	r5
	      	   or   	r1,r7
	      	   or   	r5
	      	   pop  	r7,r14
	      	   pop  	r6,r14
	      	   mov  	r2,r5
	      	   pop  	r5,r14
	      	   pop  	r1,r14
	      	   mov  	r14,r12
	      	   pop  	r12,r14
	      	   mov  	r15,r13
	# int TestRotate(int a, int b)
_TestRotate4:
	      	   push 	r12,r14
	      	   mov  	r12,r14
	# 	return ((a << b) | (a >> (32-b)));
	      	   ld   	r7,r12,1
	      	   ld   	r3,r12,2
	      	   push 	r1,r14
	      	   ld   	r4,r12,3
	      	   ld   	r1,r12,4
	      	   add  	r4,r4,0
	      	mi.sub  	r4,r4,0
	      	   mov  	r6,r7
	      	   mov  
TestRotate_22:
	      	   add  	r6,r6
	      	   adc  
	      	   sub  	r4,r0,1
	      	nz.inc  	r15,TestRotate_22-PC
	      	   ld   	r3,r12,1
	      	   ld   	r4,r12,2
	      	   push 	r5,r14
	      	   mov  	r5,r0,32
	      	   push 	r6,r14
	      	   push 	r7,r14
	      	   ld   	r6,r12,3
	      	   ld   	r7,r12,4
	      	   mov  	r1,r5
	      	   sub  	r1,r6
	      	   add  	r1,r1,0
	      	mi.sub  	r1,r1,0
	      	   mov  	r7,r3
	      	   mov  
TestRotate_23:
	      	   add  	r0,r0
	      	   ror  
	      	   ror  	r3,r3
	      	   sub  	r1,r0,1
	      	nz.inc  	r15,TestRotate_23-PC
	      	   mov  	r1,r6
	      	   mov  	r5
	      	   or   	r1,r7
	      	   or   	r5
	      	   pop  	r7,r14
	      	   pop  	r6,r14
	      	   mov  	r2,r5
	      	   pop  	r5,r14
	      	   pop  	r1,r14
	      	   mov  	r14,r12
	      	   pop  	r12,r14
	      	   mov  	r15,r13
#	rodata
#	extern	_TestRotate
#	extern	_TestRotate2
#	extern	_TestRotate3
#	extern	_TestRotate4
#	code
	# int TestShiftLeft(register int a, register int b)
_TestShiftLeft:
	# 	return a << b;
	      	   mov  	r1,r8
TestShift_4:
	      	   add  	r1,r1
	      	   sub  	r9,r0,1
	      	nz.inc  	r15,TestShift_4-PC
	      	   mov  	r15,r13
	# int TestShiftLeft(register int a, register int b)
_TestShiftRight:
	      	   push 	r12,r14
	      	   mov  	r12,r14
	# 	return a >> b;
	      	   ld   	r5,r12,1
	      	   ld   	r6,r12,2
	      	   mov  	r1,r5
TestShift_9:
	      	   asr  	r1,r1
	      	   sub  	r6,r0,1
	      	nz.inc  	r15,TestShift_9-PC
	      	   mov  	r14,r12
	      	   pop  	r12,r14
	      	   mov  	r15,r13
	# int TestShiftLeft(register int a, register int b)
_TestShiftLeftI1:
	      	   push 	r12,r14
	      	   mov  	r12,r14
	# 	return a << 1;
	      	   ld   	r5,r12,1
	      	   mov  	r1,r5
	      	   add  	r1,r1
	      	   mov  	r14,r12
	      	   pop  	r12,r14
	      	   mov  	r15,r13
	# int TestShiftLeft(register int a, register int b)
_TestShiftLeftI5:
	      	   push 	r12,r14
	      	   mov  	r12,r14
	# 	return a << 1;
	      	   ld   	r5,r12,1
	      	   mov  	r1,r5
	      	   add  	r1,r1
	      	   mov  	r14,r12
	      	   pop  	r12,r14
	      	   mov  	r15,r13
	# int TestShiftLeft(register int a, register int b)
_TestShiftRight:
	      	   push 	r12,r14
	      	   mov  	r12,r14
	# 	return a >> b;
	      	   ld   	r5,r12,1
	      	   ld   	r6,r12,2
	      	   mov  	r1,r5
TestShift_22:
	      	   asr  	r1,r1
	      	   sub  	r6,r0,1
	      	nz.inc  	r15,TestShift_22-PC
	      	   mov  	r14,r12
	      	   pop  	r12,r14
	      	   mov  	r15,r13
#	rodata
#	extern	_TestShiftLeftI1
#	extern	_TestShiftLeftI5
#	extern	_TestShiftLeft
#	extern	_TestShiftRight
#	extern	_TestShiftRight
#	code
_TestStruct:
	# typedef struct _tagTestStruct
	      	   push 	r13,r14
	      	   push 	r12,r14
	      	   mov  	r12,r14
	# 	TestStruct ts;
	      	   dec  	r14,3
	# 	ts.a = 1;
	      	   mov  	r5,r0,1
	      	   sto  	r5,r12,-3
	# 	ts.b = 2;
	      	   mov  	r6,r12,-3
	      	   mov  	r5,r6
	      	   mov  	r6,r0,2
	      	   sto  	r6,r5,1
	# 	ts.c = 3;
	      	   mov  	r6,r12,-3
	      	   mov  	r5,r6
	      	   mov  	r6,r0,3
	      	   ld   	r7,r5,2
	      	   and  	r6,r0,16383
	      	   and  	r7,r0,-16384
	      	   or   	r7,r6,0
	      	   sto  	r7,r5,2
	# 	ts.d = 1;
	      	   mov  	r6,r12,-3
	      	   mov  	r5,r6
	      	   mov  	r6,r0,1
	      	   ld   	r7,r5,2
	      	   and  	r6,r0,3
	      	   ror  	r7,r0,0
	      	   ror  	r7,r0,0
	      	   ror  	r7,r0,0
	      	   ror  	r7,r0,0
	      	   ror  	r7,r0,0
	      	   ror  	r7,r0,0
	      	   ror  	r7,r0,0
	      	   ror  	r7,r0,0
	      	   ror  	r7,r0,0
	      	   ror  	r7,r0,0
	      	   ror  	r7,r0,0
	      	   ror  	r7,r0,0
	      	   ror  	r7,r0,0
	      	   ror  	r7,r0,0
	      	   and  	r7,r0,-4
	      	   or   	r7,r6,0
	      	   adc  	r7,r0,14
	      	   adc  	r7,r0,14
	      	   adc  	r7,r0,14
	      	   adc  	r7,r0,14
	      	   adc  	r7,r0,14
	      	   adc  	r7,r0,14
	      	   adc  	r7,r0,14
	      	   adc  	r7,r0,14
	      	   adc  	r7,r0,14
	      	   adc  	r7,r0,14
	      	   adc  	r7,r0,14
	      	   adc  	r7,r0,14
	      	   adc  	r7,r0,14
	      	   adc  	r7,r0,14
	      	   sto  	r7,r5,2
	# 	return (ts.c+ts.d);
	      	   mov  	r3,r12,-3
	      	   mov  	r7,r3
	      	   ld   	r7,r7,2
	      	   mov  	r6,r7,0
	      	   and  	r6,r0,16383
	      	   mov  	r7,r0,-8192
	      	   add  	r6,r0,r7
	      	   xor  	r6,r0,r7
	      	   mov  	r4,r12,-3
	      	   mov  	r3,r4
	      	   ld   	r3,r3,2
	      	   mov  	r7,r3,0
	      	   ror  	r7,r0,0
	      	   ror  	r7,r0,0
	      	   ror  	r7,r0,0
	      	   ror  	r7,r0,0
	      	   ror  	r7,r0,0
	      	   ror  	r7,r0,0
	      	   ror  	r7,r0,0
	      	   ror  	r7,r0,0
	      	   ror  	r7,r0,0
	      	   ror  	r7,r0,0
	      	   ror  	r7,r0,0
	      	   ror  	r7,r0,0
	      	   ror  	r7,r0,0
	      	   ror  	r7,r0,0
	      	   and  	r7,r0,3
	      	   mov  	r3,r0,-2
	      	   add  	r7,r0,r3
	      	   xor  	r7,r0,r3
	      	   mov  	r5,r6
	      	   add  	r1,r7
	      	   mov  	r14,r12
	      	   pop  	r12,r14
	      	   pop  	r13,r14
	      	   mov  	r15,r13
_TestStruct2:
	# typedef struct _tagTestStruct
	      	   push 	r13,r14
	      	   push 	r12,r14
	      	   mov  	r12,r14
	# 	TestStruct b;
	      	   dec  	r14,3
	# 	b.a = a;
	      	   sto  	r8,r12,-3
	# 	return (b);
	      	   mov  	r5,r12,-3
	      	   ld   	r7,r12,3
	      	   ld   	r6,r5
	      	   sto  	r6,r7
	      	   ld   	r6,r5,1
	      	   sto  	r6,r7,1
	      	   ld   	r6,r5,2
	      	   sto  	r6,r7,2
	      	   mov  	r14,r12
	      	   pop  	r12,r14
	      	   pop  	r13,r14
	      	   mov  	r15,r13
#	rodata
#	extern	_TestStruct2
#	code
_main:
	      	   #    	int main()
	      	   push 	r13
	      	   #    		printf("Hello World!");
	      	   push 	r8
	      	   mov  	r5,r0,TestTry_1
	      	   mov  	r8,r5
	      	   jsr  	r13,r0,_printf
	      	   pop  	r8
	      	   pop  	r13
	      	   mov  	r15,r13




#	rodata
	align	2
TestTry_1:	# Hello World!
	word	72,101,108,108,111,32,87,111
	word	114,108,100,33,0
#	global	_main
#	extern	_printf
