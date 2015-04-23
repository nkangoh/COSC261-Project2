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

	;; Copy from the source to the destination.
	;;   %G3 = DMA portal
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
	CALL +handler_preserve_registers +handler_invalid_address_
	handler_invalid_address_:
	;; handler stuff	

handler_ invalid_register:
	CALL +handler_preserv_registers +handler_invalid_register_
	handler_invalid_register_:
		HALT
	;; handler stuff

handler_bus_error:
	CALL +handler_preserv_registers +handler_invalid_register_
	handler_bus_error_:
		HALT
	;; handler stuff


handler_clock_alarm:
	CALL +handler_preserv_registers +handler_invalid_register_
	handler_clock_alarm_:
		HALT
	;; handler stuff


handler_divide_by_zero:
	CALL +handler_preserv_registers +handler_invalid_register_
	handler_divide_by_zero_:
		HALT
	;; handler stuff


handler_overflow:
	CALL +handler_preserv_registers +handler_invalid_register_
	handler_overflow_:
		HALT
	;; handler stuff


handler_invalid_instruction:
	CALL +handler_preserv_registers +handler_invalid_register_
	handler_invalid_instruction_:
		HALT
	;; handler stuff


handler_permission_violation:
	CALL +handler_preserv_registers +handler_invalid_register_
	handler_permission_violation_:
		HALT
	;; handler stuff


handler_invalid_shift_amount:
	CALL +handler_preserv_registers +handler_invalid_register_
	handler_invalid_shift_amount_:
		HALT
	;; handler stuff


handler_system_call:
	CALL +handler_preserv_registers +handler_invalid_register_
	handler_system_call_:
		HALT
	;; handler stuff


handler_invalid_device_value:
	CALL +handler_preserv_registers +handler_invalid_register_
	handler_invalid_device_value_:
		HALT
	;; handler stuff


handler_device_failure: 
	CALL +handler_preserv_registers +handler_invalid_register_
	handler_device_failure_:
		HALT
	;; handler stuff

handler_kernel_not_found:
	;; Panic if the kernel has an error, but being here means there was 
	;; an error in the kernel, so print the message
	COPY %FP +_static_kernel_error_message ;; set the kernel printing message
	CALL +procedure_print  +handler_kernel_failure_ ;; Should print and jump back to the failure, which halts
	handler_kernel_failure_:
		HALT

handler_process_table_empty:
	;; Just refer to init and see how many processes are running
	BEQ +_handler_process_table_empty_ _pt_amt_process 0
	handler_process_table_empty_:
		COPY %FP +_static_error_free_shutdown_message
		Call +procedure_print +handler_process_table_empty_shutdown:
	handler_process_table_empty_shutdown:
		HALT


kernel_error_message:
	;; print that an error has occured

handler_preserve_registers:

	COPY *+_register_G0 %G0
	COPY *+_register_G1 %G1
	COPY *+_register_G2 %G2
	COPY *+_register_G3 %G3
	COPY *+_register_G4 %G4
	COPY *+_register_G5 %G5
	COPY *+_register_SP %SP
	COPY *+_register_FP %FP

handler_restore_registers:

	COPY %G0 *+_registers_G0
	COPY %G1 *+_registers_G1
	COPY %G2 *+_registers_G2
	COPY %G3 *+_registers_G3
	COPY %G4 *+_registers_G4
	COPY %G5 *+_registers_G5
	COPY %SP *+_registers_SP
	COPY %FP *+_registers_FP

handler_jump_back: 
	JUMP *IBR

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
_static_kernel_error_message: ERROR_FOUND_IN_KERNEL__ABORT

;; Console management
_static_console_width:		80
_static_console_height:		24
_static_space_char:		0x20202020 ; Four copies for faster scrolling.  If used with COPYB, only the low byte is used.
_static_cursor_char:		0x5f
_static_newline_char:		0x0a


;; Registers to preserve
_register_G0
_register_G1
_register_G2
_register_G3
_register_G4
_register_G5
_register_SP
_register_FP

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
;; --
	
.Text
_string_done_msg: "done. \n"
_string_abort_msg: "failed! Halting now.\n"
_string_blank_link : "	
	
