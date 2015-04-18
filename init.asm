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
;;; Will be done by calling procedure_find_device
	
;;; Caller Prologue
	SUBUS %SP %SP 12
	;; [%SP + 0]:  Preserved Frame Pointer
	;; [%SP + 4]:  Return Address [%FP]
	;; [%SP + 8]:  Return Value [%FP + 4]
	COPY *%SP %FP
	ADDUS %FP %SP 4
	SUBUS %SP %SP 4

	;; First parameter = next_ROM
	;; Second parameter = 2
	COPY *%SP next_ROM
	SUBUS %SP %SP 4
	COPY *%SP 2

	CALL +procedure_find_device *%FP

;;; Caller Epilogue
	SUBUS %G5 %FP 4
	COPY %FP *%G5
	ADDUS %G5 %G5 8
	COPY %SP %G5

	BREQ +end_init %SP 0
;;; %SP = Return Value = pointer to entry in device table
	ADDUS %G0 %SP 4 	;pointer to device table entry of device base
	ADDUS %G1 %G0 4 	;pointer to device table entry of device limit
	COPY %G0 *%G0
	COPY %G1 *%G1

	CREATE %G0 %G1 		;%G0 = base, %G1 = limit, exact syntax needed

	BNEQ +find_beginning %SP 0

end_init:	HALT
	
	
	
;;; ================================================================================================================================	
;;; Procedure: find_device
;;; Callee preserved registers:
;;;   [%FP - 4]:  G0
;;;   [%FP - 8]:  G1
;;;   [%FP - 12]: G2
;;;   [%FP - 16]: G4
;;; Parameters:
;;;   [%FP + 0]: The device type to find.
;;;   [%FP + 4]: The instance of the given device type to find (e.g., the 3rd ROM).
;;; Caller preserved registers:
;;;   [%FP + 8]:  FP
;;; Return address:
;;;   [%FP + 12]
;;; Return value:
;;;   [%FP + 16]: If found, a pointer to the correct device table entry; otherwise, null.
;;; Locals:
;;;   %G0: The device type to find (taken from parameter for convenience).
;;;   %G1: The instance of the given device type to find. (from parameter).
;;;   %G2: The current pointer into the device table.

_procedure_find_device:

	;; Prologue: Preserve the registers used on the stack.
	SUBUS		%SP		%SP		4
	COPY		*%SP		%G0
	SUBUS		%SP		%SP		4
	COPY		*%SP		%G1
	SUBUS		%SP		%SP		4
	COPY		*%SP		%G2
	SUBUS		%SP		%SP		4
	COPY		*%SP		%G4
	
	;; Initialize the locals.
	COPY		%G0		*%FP
	ADDUS		%G1		%FP		4
	COPY		%G1		*%G1
	COPY		%G2		*+_static_device_table_base
	
find_device_loop_top:

	;; End the search with failure if we've reached the end of the table without finding the device.
	BEQ		+find_device_loop_failure	*%G2		*+_static_none_device_code

	;; If this entry matches the device type we seek, then decrement the instance count.  If the instance count hits zero, then
	;; the search ends successfully.
	BNEQ		+find_device_continue_loop	*%G2		%G0
	SUB		%G1				%G1		1
	BEQ		+find_device_loop_success	%G1		0
	
find_device_continue_loop:	

	;; Advance to the next entry.
	ADDUS		%G2			%G2		*+_static_dt_entry_size
	JUMP		+find_device_loop_top

find_device_loop_failure:

	;; Set the return value to a null pointer.
	ADDUS		%G4			%FP		16 	; %G4 = &rv
	COPY		*%G4			0			; rv = null
	JUMP		+find_device_return

find_device_loop_success:

	;; Set the return pointer into the device table that currently points to the given iteration of the given type.
	ADDUS		%G4			%FP		16 	; %G4 = &rv
	COPY		*%G4			%G2			; rv = &dt[<device>]
	;; Fall through...
	
find_device_return:

	;; Epilogue: Restore preserved registers, then return.
	COPY		%G4		*%SP
	ADDUS		%SP		%SP		4
	COPY		%G2		*%SP
	ADDUS		%SP		%SP		4
	COPY		%G1		*%SP
	ADDUS		%SP		%SP		4
	COPY		%G0		*%SP
	ADDUS		%SP		%SP		4
	ADDUS		%G5		%FP		12 	; %G5 = &ra
	JUMP		*%G5
;;; ================================================================================================================================


.Numerics
self_base:	0
self_limit:	0
next_ROM:	 4