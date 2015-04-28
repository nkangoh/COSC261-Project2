.Code
;;; Step 48 takes IP to the end of the BIOS
;;; 	set kernel_base and kernel_limit
	COPY *+kernel_limit %G0
	
;;; Sets up values in trap table (step 13 takes to end)
	COPY *+INVALID_ADDRESS +handler_invalid_address
	COPY *+INVALID_REGISTER +handler_invalid_register
	COPY *+BUS_ERROR +handler_bus_error
	COPY *+CLOCK_ALARM +handler_clock_alarm
	COPY *+DIVIDE_BY_ZERO +handler_divide_by_zero
	COPY *+OVERFLOW +handler_overflow
	COPY *+INVALID_INSTRUCTION +handler_invalid_instruction
	COPY *+PERMISSION_VIOLATION +handler_permission_violation
	COPY *+INVALID_SHIFT_AMOUNT +handler_invalid_shift_amount
	COPY *+SYSTEM_CALL +handler_system_call
	COPY *+INVALID_DEVICE_VALUE +handler_invalid_device_value
	COPY *+DEVICE_FAILURE +handler_device_failure
;;; Sets trap table base
	SETTBR +TT_base
	SETIBR +IB_IP




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
;;; ================================================================================================================================
;;; Procedure: print
;;; Callee preserved registers:
;;;   [%FP - 4]: G0
;;;   [%FP - 8]: G3
;;;   [%FP - 12]: G4
;;; Parameters:
;;;   [%FP + 0]: A pointer to the beginning of a null-terminated string.
;;; Caller preserved registers:
;;;   [%FP + 4]: FP
;;; Return address:
;;;   [%FP + 8]
;;; Return value:
;;;   <none>
;;; Locals:
;;;   %G0: Pointer to the current position in the string.


	
_procedure_print:

	;; Prologue: Push preserved registers.
	SUBUS		%SP		%SP		4
	COPY		*%SP		%G0
	SUBUS		%SP		%SP		4
	COPY		*%SP		%G3
	SUBUS		%SP		%SP		4
	COPY		*%SP		%G4

	;; If not yet initialized, set the console base/limit statics.
	BNEQ		+print_init_loop	*+_static_console_base		0
	SUBUS		%SP		%SP		12		; Push pfp / ra / rv
	COPY		*%SP		%FP				; pFP = %FP
	SUBUS		%SP		%SP		4 		; Push arg[1]
	COPY		*%SP		1				; Find the 1st device of the given type.
	SUBUS		%SP		%SP		4		; Push arg[0]
	COPY		*%SP		*+_static_console_device_code	; Find a console device.
	COPY		%FP		%SP				; Update %FP
	ADDUS		%G5		%SP		12		; %G5 = &ra
	CALL		+_procedure_find_device		*%G5
	ADDUS		%SP		%SP		8 		; Pop arg[0,1]
	COPY		%FP		*%SP 				; %FP = pfp
	ADDUS		%SP		%SP		8		; Pop pfp / ra
	COPY		%G4		*%SP				; %G4 = &dt[console]
	ADDUS		%SP		%SP		4		; Pop rv

	;; Panic if the console was not found.
	BNEQ		+print_found_console	%G4		0
	COPY		%G5		*+_static_kernel_error_console_not_found
	HALT
	
print_found_console:	
	ADDUS		%G3		%G4		*+_static_dt_base_offset  ; %G3 = &console[base]
	COPY		*+_static_console_base		*%G3			  ; Store static console[base]
	ADDUS		%G3		%G4		*+_static_dt_limit_offset ; %G3 = &console[limit]
	COPY		*+_static_console_limit		*%G3			  ; Store static console[limit]
	
print_init_loop:	

	;; Loop through the characters of the given string until the null character is found.
	COPY		%G0		*%FP 				; %G0 = str_ptr
print_loop_top:
	COPYB		%G4		*%G0 				; %G4 = current_char

	;; The loop should end if this is a null character
	BEQ		+print_loop_end	%G4		0

	;; Scroll without copying the character if this is a newline.
	COPY		%G3		*+_static_newline_char		; %G3 = <newline>
	BEQ		+print_scroll_call	%G4	%G3

	;; Assume that the cursor is in a valid location.  Copy the current character into it.
	;; The cursor position c maps to buffer location: console[limit] - width + c
	SUBUS		%G3		*+_static_console_limit	*+_static_console_width	   ; %G3 = console[limit] - width
	ADDUS		%G3		%G3		*+_static_cursor_column		   ; %G3 = console[limit] - width + c
	COPYB		*%G3		%G4						   ; &(height - 1, c) = current_char
	
	;; Advance the cursor, scrolling if necessary.
	ADD		*+_static_cursor_column	*+_static_cursor_column		1	; c = c + 1
	BLT		+print_scroll_end	*+_static_cursor_column	*+_static_console_width	; Skip scrolling if c < width
	;; Fall through...
	
print_scroll_call:	
	SUBUS		%SP		%SP		8				; Push pfp / ra
	COPY		*%SP		%FP						; pfp = %FP
	COPY		%FP		%SP						; %FP = %SP
	ADDUS		%G5		%FP		4				; %G5 = &ra
	CALL		+_procedure_scroll_console	*%G5
	COPY		%FP		*%SP 						; %FP = pfp
	ADDUS		%SP		%SP		8				; Pop pfp / ra

print_scroll_end:
	;; Place the cursor character in its new position.
	SUBUS		%G3		*+_static_console_limit		*+_static_console_width ; %G3 = console[limit] - width
	ADDUS		%G3		%G3		*+_static_cursor_column	        ; %G3 = console[limit] - width + c	
	COPY		%G4		*+_static_cursor_char				        ; %G4 = <cursor>
	COPYB		*%G3		%G4					        ; console@cursor = <cursor>
	
	;; Iterate by advancing to the next character in the string.
	ADDUS		%G0		%G0		1
	JUMP		+print_loop_top

print_loop_end:
	;; Epilogue: Pop and restore preserved registers, then return.
	COPY		%G4		*%SP
	ADDUS		%SP		%SP		4
	COPY		%G3		*%SP
	ADDUS		%SP		%SP		4
	COPY		%G0		*%SP
	ADDUS		%SP		%SP		4
	ADDUS		%G5		%FP		8 		; %G5 = &ra
	JUMP		*%G5

;;; ================================================================================================================================
;;; Procedure: scroll_console
;;; Description: Scroll the console and reset the cursor at the 0th column.
;;; Callee reserved registers:
;;;   [%FP - 4]:  G0
;;;   [%FP - 8]:  G1
;;;   [%FP - 12]: G4
;;; Parameters:
;;;   <none>
;;; Caller preserved registers:
;;;   [%FP + 0]:  FP
;;; Return address:
;;;   [%FP + 4]
;;; Return value:
;;;   <none>
;;; Locals:
;;;   %G0:  The current destination address.
;;;   %G1:  The current source address.


;;; ================================================================================================================================

_procedure_scroll_console:

	;; Prologue: Push preserved registers.
	SUBUS		%SP		%SP		4
	COPY		*%SP		%G0
	SUBUS		%SP		%SP		4
	COPY		*%SP		%G1
	SUBUS		%SP		%SP		4
	COPY		*%SP		%G4

	;; Initialize locals.
	COPY		%G0		*+_static_console_base			   ; %G0 = console[base]
	ADDUS		%G1		%G0		*+_static_console_width	   ; %G1 = console[base] + width

	;; Clear the cursor.
	SUBUS		%G4		*+_static_console_limit		*+_static_console_width ; %G4 = console[limit] - width
	ADDUS		%G4		%G4		*+_static_cursor_column			; %G4 = console[limit] - width + c
	COPYB		*%G4		*+_static_space_char					; Clear cursor.
;; Copy from the source to the destination.  ;;   %G3 = DMA portal
	;;   %G4 = DMA transfer length
	ADDUS		%G3		8		*+_static_device_table_base ; %G3 = &controller[limit]
	SUBUS		%G3		*%G3		12                          ; %G3 = controller[limit] - 3*|word| = &DMA_portal
	SUBUS		%G4		*+_static_console_limit	%G0 		    ; %G4 = console[base] - console[limit] = |console|
	SUBUS		%G4		%G4		*+_static_console_width     ; %G4 = |console| - width

	;; Copy the source, destination, and length into the portal.  The last step triggers the DMA copy.
	COPY		*%G3		%G1 					; DMA[source] = console[base] + width
	ADDUS		%G3		%G3		4 			; %G3 = &DMA[destination]
	COPY		*%G3		%G0 					; DMA[destination] = console[base]
	ADDUS		%G3		%G3		4 			; %G3 = &DMA[length]
	COPY		*%G3		%G4 					; DMA[length] = |console| - width; DMA trigger

	;; Perform a DMA transfer to blank the last line with spaces.
	SUBUS		%G3		%G3		8 			; %G3 = &DMA_portal
	COPY		*%G3		+_string_blank_line			; DMA[source] = &blank_line
	ADDUS		%G3		%G3		4 			; %G3 = &DMA[destination]
	SUBUS		*%G3		*+_static_console_limit	*+_static_console_width	; DMA[destination] = console[limit] - width
	ADDUS		%G3		%G3		4 			; %G3 = &DMA[length]
	COPY		*%G3		*+_static_console_width			; DMA[length] = width; DMA trigger
	
	;; Reset the cursor position.
	COPY		*+_static_cursor_column		0			                ; c = 0
	SUBUS		%G4		*+_static_console_limit		*+_static_console_width ; %G4 = console[limit] - width
	COPYB		*%G4		*+_static_cursor_char				   	; Set cursor.
	
	;; Epilogue: Pop and restore preserved registers, then return.
	COPY		%G4		*%SP
	ADDUS		%SP		%SP		4
	COPY		%G1		*%SP
	ADDUS		%SP		%SP		4
	COPY		%G0		*%SP
	ADDUS		%SP		%SP		4
	ADDUS		%G5		%FP		4 		; %G5 = &ra
	JUMP		*%G5
;;; ================================================================================================================================

;;; Find next ROM device
;;; Registers: G0 = address of next device in BC
;;; 	       G1 = device value, G2 = boolean 2 found at bus_index
;;; 	       G3 = two_count

	COPY		%G0		*+bus_index
	COPY		%G3		0
;;; Step 16 from top
findstart:
	COPY		%G1		*%G0
	SUB				%G2		%G1		2
	ADD				%G0		%G0		0x0000000c
	BNEQ		+findstart		%G2		0
	ADD				%G3		1		%G3
	BNEQ				+findstart		%G3		2
	SUB				%G0		%G0		0x00000008
;;; Step 37 (+21) from top
;;; G0 should now point to the kernel in Bus Controller
	COPY		%G5		*%G0
	ADD				%G0		%G0		0x00000004
	COPY		%G4		*%G0
;;; G5 = kernel base address (0x207000), G4 = kernel end address  (0x2073a4)
	COPY		*+kernel_limit		%G4
	COPY		%G0		*+bus_index
	COPY		%G3		0
findstart_process:
	COPY		%G1		*%G0
	SUB				%G2		%G1		2
	ADD				%G0		%G0		0x0000000c
	BNEQ		+findstart_process		%G2		0
	ADD				%G3		1		%G3
	BNEQ				+findstart_process		%G3		3
	SUB				%G0		%G0		0x00000008
;;; G0 should now point to the process in Bus Controller
	COPY		%G5		*%G0
	ADD				%G0		%G0		0x00000004
	COPY		%G4		*%G0
;;; G5 = process base address, G4 = process end address
	SUB				%G4		%G4		%G5
;;; G4 = length of process
	COPY		%G0		*+bus_index
	ADD				%G0		%G0		0x00000008
	COPY		%G1		*%G0
;;; G1 = Address pointing to the address of the end of the BC
	SUB				%G1		%G1		0x0000000c
;;; G1 = Address pointing to the first triplet of the last set in the BC
	ADD		%G2		0x00001000		+kernel_limit
;;; G2 = Destination base
	COPY		*%G1		%G5
	ADD				%G1		%G1		0x00000004
	COPY		*%G1		%G2
	ADD				%G1		%G1		0x00000004
	COPY		*%G1		%G4
	
	COPY		%G0		2
	JUMPMD		%G2		%G0
;;; Step 90 from top

;;; Handler functions 	
handler:
	HALT


;; Which ones do you have to save the values?
;; Base register 0; limit register 1

handler_invalid_address:
	;; Print handler error
	;; Set the string to be copied
	COPY *%FP +_invalid_address_message
	CALL +_procedure_print *%FP
	handler_invalid_address_:
		JUMP +_SYSC_EXIT
	;; handler stuff	


handler_invalid_register:
	COPY *%FP +_invalid_register_message
	CALL +_procedure_print *+handler_invalid_address_
	handler_invalid_register_:
		JUMP +_SYSC_EXIT
	;; handler stuff

handler_bus_error:
	COPY *%FP +_handler_bus_error:
	CALL +_procedure_print *+handler_invalid_address_
	handler_bus_error_:
		JUMP +_SYSC_EXIT
	;; handler stuff


handler_clock_alarm:
	;;Parameters:
	;;[%G0] -- Device number

	COPY *%FP _clock_alarm_message
	CALL +_procedure_print *+handler_invalid_address_

	;; preserve registers

IP_T1: 	ADDUS +_TEMP_IP +IP_T1 16 ;; jump to ADDUS
	BEQ +handler_preserve_registers_P1 %G0	1
	BEQ +handler_preserve_registers_P2 %G0	2
	BEQ +handler_preserve_registers_P3 %G0	3
		
	;; restore registers of the one we're going to
IP_T2:	ADDUS +_TEMP_IP +IP_T2 16 ;; jump to ADDUS
	BEQ +handler_restore_registers_P2 %G0	1
	BEQ +handler_restore_registers_P3 %G0	2
	BEQ +handler_restore_registers_P1 %G0	3

	;; jump of the ip of the next process
IP_T3:  ADDUS +_TEMP_IP +IP_T3 16 ;; jump to ADDUS
	BEQ +P2_IP %G0	1
	BEQ +P3_IP %G0	2
	BEQ +P1_IP %G0	3


	handler_clock_alarm_:
		JUMP +_SYSC_EXIT
	;; handler stuff


handler_divide_by_zero:
	COPY *%FP _divide_by_zero_message
	CALL +_procedure_print *+handler_divide_by_zero_
	handler_divide_by_zero_:
		JUMP +_SYSC_EXIT
	;; handler stuff


handler_overflow:
	COPY *%FP _overflow_message
	CALL +_procedure_print *+handler_overflow_
	handler_overflow_:
		JUMP +_SYSC_EXIT
	;; handler stuff


handler_invalid_instruction:
	COPY *%FP _invalid_instruction_message
	CALL +_procedure_print *+handler_invalid_instruction_
	handler_invalid_instruction_:
		JUMP +_SYSC_EXIT
	;; handler stuff


handler_permission_violation:
	COPY *%FP _permission_violation_message
	CALL +_procedure_print *+handler_permission_violation_
	handler_permission_violation_:
		JUMP +_SYSC_EXIT
	;; handler stuff


handler_invalid_shift_amount:
	COPY *%FP _invalid_shift_amount_message
	CALL +_procedure_print *+handler_invalid_shift_amount_
	handler_invalid_shift_amount_:
		JUMP +_SYSC_EXIT
	;; handler stuff


handler_system_call:
	COPY *%FP _system_call_message
	
	BEQ +_SYSC_EXIT %G0 0
	BEQ +_SYSC_CREATE %G0 1
	BEQ +_SYSC_GET_ROM_COUNT %G0 2
	BEQ +_SYSC_FIND_DEVICE %G0 3
	
	handler_system_call_:
		;; Take parameters
		;; Jump to the appropriate system call handler
		_SYSC_EXIT:
			
			;; decrement the rom amount, delete the
			;; base and limit of the given rom and
			;; free up the space

			;; Parmeters:
			;; [%G0] -- Process ID

			SUB +ROM_amount +ROM_amount 1
			BEQ +exit_P1 	%G0	1
			BEQ +exit_P2 	%G0	2
			BEQ +exit_P3 	%G0	3

			;; figure out how to set them to 0 (null them out)	
			exit_P1:
			        COPY	+P1_Base 	0	
			        COPY 	+P1_Limit 	0	
				SETBS 	+P1_Base
				SETLM 	+P1_Limit

				COPY +P1_register_G0	0
				COPY +P1_register_G1	0
				COPY +P1_register_G2	0
				COPY +P1_register_G3	0
				COPY +P1_register_G4	0
				COPY +P1_register_G5	0
				COPY +P1_register_SP	0
				COPY +P1_register_FP	0

				JUMP 	+P2_IP

			exit_P2:
			        COPY 	+P2_Base 	0	
			        COPY 	+P2_Limit 	0	
				SETBS 	+P2_Base
				SETLM 	+P2_Limit

				COPY +P2_register_G0	0
				COPY +P2_register_G1	0
				COPY +P2_register_G2	0
				COPY +P2_register_G3	0
				COPY +P2_register_G4	0
				COPY +P2_register_G5	0
				COPY +P2_register_SP	0
				COPY +P2_register_FP	0


				JUMP 	+P1_IP

			exit_P3:
			        COPY 	+P3_Base 	0	
			        COPY 	+P3_Limit 	0	
				SETBS 	+P3_Base
				SETLM 	+P3_Limit
	
				COPY +P3_register_G0	0
				COPY +P3_register_G1	0
				COPY +P3_register_G2	0
				COPY +P3_register_G3	0
				COPY +P3_register_G4	0
				COPY +P3_register_G5	0
				COPY +P3_register_SP	0
				COPY +P3_register_FP	0

	
				JUMP 	+P1_IP

		
		_SYSC_CREATE:
			;;Parameter [%G1] = pointer to device table entry
			;;Parameter [%G2] = current process number

		 IP_T4: ADDUS +_TEMP_IP +IP_T4 16 ;; jump to ADDUS
			BEQ handler_preserve_registers_P1 %G2 1
			BEQ handler_preserve_registers_P2 %G2 2
			BEQ handler_preserve_registers_P3 %G2 3
	
			ADDUS +ROM_amount +ROM_amount 1
			ADDUS %G1 %G1 4
			ADDUS %G2 %G1 4
			COPY %G1 *%G1
			COPY %G2 *%G2
			SUBUS %G2 %G2 %G1
			;;[%G1] = address of device base
			;;[%G2] = length of device
			

			;; get base and limit and do DMA, base of where to add it.
			;; %G1 -- Base
			;; %G2 -- Limit
			;; %G3 -- Base of where to add it (may be unncessary)

			
			BEQ +create_P1 +ROM_amount 1
			BEQ +create_P2 +ROM_amount 2
			BEQ +create_P3 +ROM_amount 3

			;; set the base and limit with 1KB padding, and 500b space b/w processes
			create_P1:
				COPY +P1_Base 0x10000
				COPY +P1_Limit 0x15000
				SETBS +P1_Base
				SETLM +P1_Limit
				JUMPMD *P1_Base 0x6

			create_P2:
				COPY +P2_Base 0x20000
				COPY +P2_Limit 0x25000
				SETBS +P2_Base
				SETLM +P2_Limit
				JUMPMD *P2_Base 0x6

			create_P3:
				COPY +P3_Base 0x30000
				COPY +P3_Limit 0x35000
				SETBS +P3_Base
				SETLM +P3_Limit
				JUMPMD *P3_Base 0x6
		

		_SYSC_GET_ROM_COUNT:
			;; copy into a register (G0) the current rom amount
			COPY %G0 +ROM_amount
			JUMP %IBR

		_SYSC_FIND_DEVICE:
			;; caller prologue
			;; preserve frame pointer 
			SUBUS %SP %SP 12
			COPY *%SP %FP
			;; put in arguments
			SUBUS %FP %SP 4
			COPY *%FP %G2
			SUBUS %FP %FP 4
			COPY *%FP %G1
			;; stack pointer is at top of stack
			SUBUS %SP %SP 8
			;; add 12 to %FP
			ADDUS %G5 %FP 12
			;; call find device procedure 
			CALL +_procedure_find_device *%G5
			;; caller epilogue
			ADDUS %G5 %FP 8
			COPY %FP *%G5
			ADDUS %G5 %G5 8
			COPY %SP *%G5
			COPY %G0 *%SP		
			JUMP %IBR

	;; handler stuff


handler_invalid_device_value:
	CALL +_procedure_print *+handler_invalid_address_
	handler_invalid_device_value_:
		JUMP +_SYSC_EXIT
	;; handler stuff


handler_device_failure: 
	CALL +_procedure_print *+handler_invalid_address_
	handler_device_failure_:
		JUMP +_SYSC_EXIT
	;; handler stuff

handler_kernel_not_found:
	;; Panic if the kernel has an error, but being here means there was 
	;; an error in the kernel, so print the message
	COPY 	*%SP 	+_kernel_error_message ;; set the kernel printing message
	CALL +_procedure_print  *+handler_kernel_failure_ ;; Should print and jump back to the failure, which halts
	handler_kernel_failure_:
		HALT

handler_process_table_empty:
	;; Just refer to init and see how many processes are running
	CALL +_SYSC_GET_ROM_COUNT *+handler_process_table_empty_
	COPY 	*%FP 	+_process_table_empty_message

	handler_process_table_empty_:
		COPY *%FP +_static_error_free_shutdown_message
		CALL +_procedure_print *+handler_process_table_empty_shutdown:

	handler_process_table_empty_shutdown:
		JUMP +_SYSC_EXIT


;; preserve
handler_preserve_registers_P1:
	
	COPY +P1_register_G0 %G0
	COPY +P1_register_G1 %G1
	COPY +P1_register_G2 %G2
	COPY +P1_register_G3 %G3
	COPY +P1_register_G4 %G4
	COPY +P1_register_G5 %G5
	COPY +P1_register_SP %SP
	COPY +P1_register_FP %FP
	JUMP +_TEMP_IP


handler_preserve_registers_P2:
	
	COPY +P2_register_G0 %G0
	COPY +P2_register_G1 %G1
	COPY +P2_register_G2 %G2
	COPY +P2_register_G3 %G3
	COPY +P2_register_G4 %G4
	COPY +P2_register_G5 %G5
	COPY +P2_register_SP %SP
	COPY +P2_register_FP %FP
	JUMP +_TEMP_ID


handler_preserve_registers_P3:
	
	COPY +P3_register_G0 %G0
	COPY +P3_register_G1 %G1
	COPY +P3_register_G2 %G2
	COPY +P3_register_G3 %G3
	COPY +P3_register_G4 %G4
	COPY +P3_register_G5 %G5
	COPY +P3_register_SP %SP
	COPY +P3_register_FP %FP
	JUMP +_TEMP_ID

;; restore
handler_restore_registers_P1:

	COPY %G0 +_P1_register_G0
	COPY %G1 +_P1_register_G1
	COPY %G2 +_P1_register_G2
	COPY %G3 +_P1_register_G3
	COPY %G4 +_P1_register_G4
	COPY %G5 +_P1_register_G5
	COPY %SP +_P1_register_SP
	COPY %FP +_P1_register_FP

handler_restore_registers_P2:

	COPY %G0 +_P2_register_G0
	COPY %G1 +_P2_register_G1
	COPY %G2 +_P2_register_G2
	COPY %G3 +_P2_register_G3
	COPY %G4 +_P2_register_G4
	COPY %G5 +_P2_register_G5
	COPY %SP +_P2_register_SP
	COPY %FP +_P2_register_FP


handler_restore_registers_P3:

	COPY %G0 +_P3_register_G0
	COPY %G1 +_P3_register_G1
	COPY %G2 +_P3_register_G2
	COPY %G3 +_P3_register_G3
	COPY %G4 +_P3_register_G4
	COPY %G5 +_P3_register_G5
	COPY %SP +_P3_register_SP
	COPY %FP +_P3_register_FP


handler_jump_back: 
	JUMP *%IBR

.Numeric
_static_kernel_base:	0
_static_kernel_limit:	0
process_base:	
IB_IP:	0
IB_MISC:	0
bus_index:	 0x00001000

;; Kernel Error Codes
_static_kernel_error_RAM_not_found:	0xffff0001
_static_kernel_error_main_returned:	0xffff0002
_static_kernel_error_small_RAM:		0xffff0003	
_static_kernel_error_console_not_found:	0xffff0004

;; Error messages

;; Console management
_static_console_width:		80
_static_console_height:		24
_static_space_char:		0x20202020 
_static_cursor_char:		0x5f
_static_newline_char:		0x0a


;; Registers to preserve
_register_G0:	0
_register_G1:	0
_register_G2:	0
_register_G3:	0
_register_G4:	0
_register_G5:	0
_register_SP:	0
_register_FP:	0

_TEMP_IP:	0


;; Trap Table --
TT_base:
	INVALID_ADDRESS:	0
	INVALID_REGISTER:	0
	BUS_ERROR: 	0
	CLOCK_ALARM:	0
	DIVIDE_BY_ZERO:	0
	OVERFLOW:	0
	INVALID_INSTRUCTION:	0
	PERMISSION_VIOLATION:	0
	INVALID_SHIFT_AMOUNT:	0
	SYSTEM_CALL:	0
	INVALID_DEVICE_VALUE:	0
	DEVICE_FAILURE:	0


;; Process Table
ROM_amount:		0
PT_base:		0
	P1:	
		P1_Base: 	0
		P1_Limit: 	0
		P1_IP:		0
		P1_registers:
			P1_register_G0:	0
			P1_register_G1:	0
			P1_register_G2:	0
			P1_register_G3:	0
			P1_register_G4:	0
			P1_register_G5:	0
			P1_register_SP:	0
			P1_register_FP:	0

			
	P2:	
		P2_Base:	0
		P2_Limit:	0
		P2_IP:
		P2_registers:
			P2_register_G0:	0
			P2_register_G1:	0
			P2_register_G2:	0
			P2_register_G3:	0
			P2_register_G4:	0
			P2_register_G5:	0
			P2_register_SP:	0
			P2_register_FP:	0

	P3:
		P3_Base:	0
		P3_Limit:	0
		P3_IP:		0
		P3_registers:
			P3_register_G0:	0
			P3_register_G1:	0
			P3_register_G2:	0
			P3_register_G3:	0
			P3_register_G4:	0
			P3_register_G5:	0
			P3_register_SP:	0
			P3_register_FP:	0

	
.Text
_string_done_msg: "done. \n"
_string_abort_msg: "failed! Halting now.\n"
_string_blank_link : "	
	
;; Static error messages
_invalid_address_message: 	"ERROR: invalid address"
_invalid_register_message:	"ERROR: invalid register"
_invalid_address_message: 	"ERROR: invalid address"
_clock_alarm_message:		"ERROR: clock alarm"
_divide_by_zero_message:	"ERORR: divide by zero"
_overflow_message: 		"ERORR: overflow"
_invalid_instruction_message:	"ERROR: invalid instruction"
_permission_violation_message:	"ERROR: permission violation"
_invalid_shift_amount_message:	"ERROR: invalid shift amount"
_system_call_message:		"System call detected"
_invalid_device_value_message: 	"ERROR: invalid device value"
_device_failure_message: 	"ERROR: device failure"
_process_table_empty_message: 	"ERROR: process table"
_kernel_error_message: 		"ERROR_FOUND_IN_KERNEL__ABORT"

