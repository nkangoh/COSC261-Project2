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
	
	FIND_DEVICE %G0 2 next_ROM
	ADDUS next_ROM next_ROM 1

	BREQ +end_init %G0 0
;;; %SP = Return Value = pointer to entry in device table
	ADDUS %G0 %G0 4 	;pointer to device table entry of device base
	ADDUS %G1 %G0 4 	;pointer to device table entry of device limit
	COPY %G0 *%G0
	COPY %G1 *%G1

	ADDUS +next_ROM +next_ROM 1

	CREATE %G0 %G1 		;%G0 = base, %G1 = limit, exact syntax needed

	BNEQ +find_beginning %SP 0

end_init:	HALT
	
.Numerics
self_base:	0
self_limit:	0
next_ROM:	 4