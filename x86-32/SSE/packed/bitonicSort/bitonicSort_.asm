; x86-32 assembly

.model flat,c 

.code

; COMPARE_AND_SWAP_WITHIN_SINGLE_XMM does the compare and swap operation within single xmm val. After this operation, output xmm register will contain
; elemnts sorted either increasing or decrasing. The input xmm has to contain bitonic sequence.
; Macro takes four parameters:
; MASK - mask for final shuffle
; XMM_IN_OUT_REGISTER - xmm register where input value is passed. Result will be also passed via this register.
; XMM_TEMP_REGISTER1, XMM_TEMP_REGISTER2 - temp xmm registers needed for internal use.
COMPARE_AND_SWAP_WITHIN_SINGLE_XMM macro MASK, XMM_IN_OUT_REGISTER, XMM_TEMP_REGISTER1, XMM_TEMP_REGISTER2

	pshufd XMM_TEMP_REGISTER1, XMM_IN_OUT_REGISTER, 01001110b		; shuffle for performing cas with stride 2.
	movdqa XMM_TEMP_REGISTER2, XMM_TEMP_REGISTER1

	pminsd XMM_TEMP_REGISTER1, XMM_IN_OUT_REGISTER
	pmaxsd XMM_TEMP_REGISTER2, XMM_IN_OUT_REGISTER

	movlhps XMM_TEMP_REGISTER2, XMM_TEMP_REGISTER1	

	; --- At this moment xmm2 compared and swaped elements with stride 2 --

	pshufd XMM_IN_OUT_REGISTER, XMM_TEMP_REGISTER2, 10110001b		; shuffle for performing cas with stride 1
	movdqa XMM_TEMP_REGISTER1, XMM_IN_OUT_REGISTER

	pminsd XMM_IN_OUT_REGISTER, XMM_TEMP_REGISTER2
	pmaxsd XMM_TEMP_REGISTER1, XMM_TEMP_REGISTER2

	shufps XMM_IN_OUT_REGISTER, XMM_TEMP_REGISTER1, 10001000b		; [0:63] conatins min values, [64,127] contains max values
	pshufd XMM_IN_OUT_REGISTER, XMM_IN_OUT_REGISTER, MASK			; final shuffle is done according to mask, which will be different if we want to sort increasing or decreasing

endm

;--------------------------------------------------------------------------------------------------------------

; Helper macro which does bitonic sort and output is sorted increasing.
COMPARE_AND_SWAP_WITHIN_SINGLE_XMM_INC macro XMM_IN_OUT_REGISTER, XMM_TEMP_REGISTER1, XMM_TEMP_REGISTER2
	COMPARE_AND_SWAP_WITHIN_SINGLE_XMM 10001101b, XMM_IN_OUT_REGISTER, XMM_TEMP_REGISTER1, XMM_TEMP_REGISTER2
endm

;--------------------------------------------------------------------------------------------------------------

; Helper macro which does bitonic sort and output is sorted decreasing.
COMPARE_AND_SWAP_WITHIN_SINGLE_XMM_DEC macro XMM_IN_OUT_REGISTER, XMM_TEMP_REGISTER1, XMM_TEMP_REGISTER2
	COMPARE_AND_SWAP_WITHIN_SINGLE_XMM 01110010b, XMM_IN_OUT_REGISTER, XMM_TEMP_REGISTER1, XMM_TEMP_REGISTER2
endm

;--------------------------------------------------------------------------------------------------------------

; 'Private' macro needed for SORT_BITONIC
STORE_XMM_VALS macro register1, register2
	movdqa [ecx], register1
	movdqa [eax], register2
endm

;--------------------------------------------------------------------------------------------------------------

; 'Private' macro needed for SORT_BITONIC
STORE_XMM_VALS_INC macro 
	STORE_XMM_VALS xmm1, xmm2
endm

;--------------------------------------------------------------------------------------------------------------

; 'Private' macro needed for SORT_BITONIC
STORE_XMM_VALS_DEC macro 
	STORE_XMM_VALS xmm2, xmm1
endm

;--------------------------------------------------------------------------------------------------------------

; This macro performs bitonic sorting either increasing or decreasing.
; Assumes that given sequence is bitonic: first half is sorted increasing, second half is sorted decreasing.
; size has to be power of 2, array ptr has to be aligned to 16 byte boundary. Sorting is done inplace.
SORT_BITONIC macro TYPE
	push ebp
	mov ebp, esp
	push ebx
	push esi
	push edi

	mov ebx, [ebp+12]				; ebx = size of the data.
	mov esi, 1						; esi = max loop counter for sub array loop.

STRIDE_SIZE_LOOP:

	shr ebx, 1						; ebx will contain current stride for compare and swap. Stride will be decreased by factor of 2 with every iteration.
	mov ecx, [ebp+8]				; ecx = array ptr, needs to be reloaded for every stride size to process whole array with given stride.
	mov edi, esi					; esi = current loop counter of how many subarrays loop we should do.  

SUB_ARRAY_LOOP:

	mov edx, ebx					; edx = current loop counter for cas operation of current subarray.
	lea eax, [ecx + 4*edx]			; eax = array ptr + size/2*4 = start address of the decreasing sequence for current subarray.
	shr edx, 2						; divide loop counter by 4 since we process 4 elements at iteration.

PROCESSING_LOOP:

	; This loop does compare and swap for given stride.
	movdqa xmm0, xmmword ptr [ecx]				
	movdqa xmm1, xmmword ptr [eax]
	movdqa xmm2, xmm1

	pminsd xmm1, xmm0				; min values goes to xmm1.
	pmaxsd xmm2, xmm0				; max valies goes to xmm2.

	; Store results of comapare and swap.
	STORE_XMM_VALS_&TYPE&

	; Update ptrs and counter.
	add ecx, 16
	add eax, 16
	dec edx
	jnz PROCESSING_LOOP

	mov ecx, eax					; eax at this moment contains pointer to next subarray.
	dec edi
	jnz SUB_ARRAY_LOOP

	shl esi, 1						; update max loop counter for subarray loop - with every iteration we will have 2 times more subarrays to process
									; but each subarray will be 2 times smaller.
	cmp ebx, 4						; continue until stride is 4, since we have special loop for stride size of 2 and 1.
	jne STRIDE_SIZE_LOOP

	; At this moment we have to do compare and swap for step size 2 and 1 - so it has to be done within xmm register itself.

	mov ebx, [ebp+12]				; ebx = size		; reload size.
	mov ecx, [ebp+8]				; ecx = array ptr	; reload array ptr.
	shr ebx, 3						; ebx = size / 8	; ebx = number of needed iterations( we will process 2 xmm val per iteration ).

FINAL_LOOP:

	; We will process two xmm val per loop.
	movdqa xmm0, xmmword ptr [ecx]				
	movdqa xmm3, xmmword ptr [ecx+16]

	COMPARE_AND_SWAP_WITHIN_SINGLE_XMM_&TYPE& xmm0, xmm1, xmm2
	COMPARE_AND_SWAP_WITHIN_SINGLE_XMM_&TYPE& xmm3, xmm4, xmm5

	; Store final sorted values.
	movdqa [ecx],xmm0
	movdqa [ecx+16],xmm3
	
	add ecx, 32
	dec ebx
	jnz FINAL_LOOP

	pop edi
	pop esi
	pop ebx
	pop ebp
	ret
endm

;--------------------------------------------------------------------------------------------------------------

; extern "C" void SortBitonicSeqIncreasing_SSE_( int32_t* array, uint32_t size );
;
; Assumes that given sequence is bitonic: first half is sorted increasing, second half is sorted decreasing.
; size has to be power of 2, array ptr has to be aligned to 16 byte boundary.

SortBitonicSeqIncreasing_SSE_ proc
	SORT_BITONIC INC
SortBitonicSeqIncreasing_SSE_ endp

;--------------------------------------------------------------------------------------------------------------

; extern "C" void SortBitonicSeqDecreasing_SSE_( int32_t* array, uint32_t size );
;
; Assumes that given sequence is bitonic: first half is sorted increasing, second half is sorted decreasing.
; size has to be power of 2, array ptr has to be aligned to 16 byte boundary.

SortBitonicSeqDecreasing_SSE_ proc
	SORT_BITONIC DEC
SortBitonicSeqDecreasing_SSE_ endp

;--------------------------------------------------------------------------------------------------------------

; Makro makes inital bitonic sequence out of arbitrary xmm register. After the operation, first two elements will be sorted increasing,
; last two elements will be sorted decrasing.
; XMM_IN_OUT_VAL - xmm register that holds input and later holds result.
; XMM_TEMP1, XMM_TEMP2 - xmm temp registers need to calculate the result.
MAKE_BITONIC_XMM macro XMM_IN_OUT_VAL, XMM_TEMP1, XMM_TEMP2
	pshufd XMM_TEMP1, XMM_IN_OUT_VAL, 10110001b			; XMM_TEMP1 contains copied numbers 3 and 1
	movdqa XMM_TEMP2, XMM_IN_OUT_VAL
	pminsd XMM_IN_OUT_VAL, XMM_TEMP1					; XMM_IN_OUT_VAL contains min values at indexes 3 and 1
	pmaxsd XMM_TEMP2, XMM_TEMP1							; XMM_TEMP2 contains max values at indexes 3 and 1

	shufps XMM_IN_OUT_VAL, XMM_TEMP2, 10001000b			; [0:63] conatins min values, [64,127] contains max values
	shufps XMM_IN_OUT_VAL, XMM_IN_OUT_VAL, 01111000b	; XMM_IN_OUT_VAL contains bitonic sequence
endm

;--------------------------------------------------------------------------------------------------------------

; extern "C" void MakeInitialBitonicSequence_SSE_( int32_t* array, uint32_t size );
;
; This function perfoms initial bitonic sequence out of arbitrary numbers in place. 
; The result will be repeating bitonic sequence of size 8 ( 4 elmements increasing followed by 4 elements decreasing ).
; array ptr has to be alinged to 16-byte boundary, size has to be power of 2 and >= 8.
MakeInitialBitonicSequence_SSE_ proc
	push ebp
	mov ebp, esp

	mov ecx, [ebp+8]							; ecx = numbers ptr
	mov edx, [ebp+12]							; edx = size
	shr edx, 3									; edx = size/8, number of needed loops( taking 2 xmm words during the loop ).

MAIN_LOOP:
	movdqa xmm0, xmmword ptr [ecx]				; load packed into xmm0
	movdqa xmm3, xmmword ptr [ecx+16]			; load packed into xmm3

	MAKE_BITONIC_XMM xmm0, xmm1, xmm2
	MAKE_BITONIC_XMM xmm3, xmm4, xmm5

	COMPARE_AND_SWAP_WITHIN_SINGLE_XMM_INC xmm0, xmm1, xmm2
	COMPARE_AND_SWAP_WITHIN_SINGLE_XMM_DEC xmm3, xmm4, xmm5

	movdqa [ecx],xmm0							; store result.
	movdqa [ecx+16],xmm3						; store result.

	add ecx, 32

	dec edx
	jnz MAIN_LOOP

	pop ebp
	ret

MakeInitialBitonicSequence_SSE_ endp
end