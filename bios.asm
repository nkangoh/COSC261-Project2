;;; BIOS

	.Code
;;; Registers: G0 = bus_index (address of next device in BC)
;;; 	       G1 = device value, G2 = boolean 2 found at bus_index
;;; 	       G3 = two_count
	COPY %G0 *+bus_index
	COPY %G3 *+two_count
findstart:
	COPY %G1 *%G0
	SUB  %G2 %G1 2
	ADD  %G0 %G0 0x0000000c
	BNEQ +findstart %G2 0
	ADD  %G3 1 %G3
	BEQ  +findstart %G3 1
	SUB  %G0 %G0 0x00000008
;;; G0 should now point to kernel base in BC
	COPY %G5 *%G0
	ADD  %G0 %G0 0x00000004
	COPY %G4 *%G0
;;; G5 = kernel base address, G4 = kernel end address
	COPY %G0 *+bus_index
;;; G0 = bus_index, G1 = device value
MMfindstart:	
	COPY %G1 *%G0
	SUB  %G2 %G1 3
	ADD  %G0 %G0 0x0000000c
	BNEQ  +MMfindstart %G2 0
	SUB  %G0 %G0 0x00000008
;;; G0 should now point to MM base in BC
	COPY %G3 *%G0
;;; G3 = MM base address
	SUB  %G4 %G4 %G5
;;; G4 = length of kernel

	COPY %G0 *+bus_index
	ADD  %G0 %G0 0x00000008
	COPY %G1 *%G0
;;; G1 = Address pointing to the address of the end of the BC
	SUB  %G1 %G1 0x0000000c
;;; G1 = Address pointing to the first triplet of the last set in the BC
	COPY *%G1 %G5
	ADD  %G1 %G1 0x00000004
	COPY *%G1 %G3
	ADD  %G1 %G1 0x00000004
	COPY *%G1 %G4

	ADD %G0 %G4 %G3
	ADD %G0 %G0 0x1000
	
	JUMP %G3


	HALT
	
		
	
	
	.Numeric
kernel_index:	0x00000000
kernel_end:	0x00000000
MM_start:	0x00000000
MM_index:	0x00000000
two_count:	0
bus_index:	0x00001000