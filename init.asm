;;; ======================================================================
;;; init.asm
;;; Need: ability to find a ROM
;;; schedule all found ROMs 
;;; Create processes

.Code
;;; First, we take the Base and Limit of this process from the information
;;; specified by the kernel (stored in %G0 and %G1)
	COPY self_base %G0
	COPY self_limit %G1
	COPY %SP self_limit
	COPY %FP %SP

find_beginning:	
;;; Find all ROMs and CREATE each as a process
;;; Will be done by calling procedure_find_device SYSCALL

	COPY %G0 3
	COPY %G1 2
	COPY %G2 +next_ROM

	SYSC
	
	BEQ +end_init %G0 0
	
	COPY %G1 %G0
	COPY %G0 1
	COPY %G2 next_ROM
	SYSC
	
	ADDUS next_ROM next_ROM 1
	BNEQ +find_beginning %SP 0

end_init:	HALT
	
.Numeric
self_base:	0
self_limit:	0
next_ROM:	 4
