.Code

	COPY	%G0	0x0
	BEQ +start %G0 0
	

foo:	COPY %G1 0xdeadbeef
	JUMP *%G5


start:	COPY %G5 +start
	ADDUS %G5 %G5 12
	CALL +foo *%G5
	COPY %G2 0xdeadcafe

	
	HALT