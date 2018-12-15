; x86-32 assembly

.model flat,c

.const
real4_half_const real4 0.5
real4_zero_const real4 0.0

.code

; extern "C" float NumericalIntegration_( const T1DFunctionPtr ptr, float a, float b, uint32_t steps );
;
; Performs simple numerical integration based on trapezoids, but uses Kahan summation algorithm to improve numerical stability.
; [NOTE]: SSE does not contain conversion function from unsigned int to float, only has conversion from signed int to float,
; so the code will fail if number of steps > MAX_INT. 
; Fixing it would make the code much less readable, so I will leave it as it is.
NumericalIntegration_ASM_ proc
	push ebp						; prolog
	mov ebp, esp					; prolog
	push ebx						; ebx is callee-saved register

	sub esp, 24						; preallocate stack

	; Precalculate stepSize:
	mov ebx, [ebp+8]				; ebx = T1DFunctionPtr
	movss xmm0, real4 ptr[ebp+12]	; xmm0 = a
	movss xmm1, real4 ptr[ebp+16]	; xmm1 = b
	subss xmm1, xmm0				; xmm1 = b - a => diff
	cvtsi2ss xmm2, dword ptr[ebp+20]; xmm2 = (float)steps 
	divss xmm1, xmm2				; xmm1 = diff/steps => stepSize

	movss real4 ptr[esp+8], xmm1	; store stepSize on the stack, cuz xmm registers are not perserved on function calls.
	mulss xmm1, [real4_half_const]	; xmm1 = stepSize/2
	movss real4 ptr[esp+12], xmm1	; store stepSize/2

	; Reset current integral value and error
	mov ecx, [real4_zero_const]
	mov real4 ptr[esp+16], ecx		; value of integral = 0
	mov real4 ptr[esp+20], ecx		; error = 0

	; Call function on argument a
	movss real4 ptr[esp], xmm0		; push variable 'a' on the top of stack
	call ebx						; call T1DFunctionPtr
	fstp real4 ptr[esp+4]			; store output from T1DFunctionPtr on the stack => height1, note that according to x86-32 convention, retun value
									; from T1DFunctionPtr will be holded by x87 stack 0 entry.

	; Prepare for main loop
	mov edi, 0						; edi = loop counter( number of wanted steps ) => i, edi is callee-saved register.

MAIN_LOOP:
	inc edi							; increment loop counter => i

	cvtsi2ss xmm0, edi				; xmm0 = (float)i
	movss xmm1, real4 ptr[esp+8]	; xmm0 = stepSize
	mulss xmm1, xmm0				; xmm1 = (float)i*stepSize;
	addss xmm1, real4 ptr[ebp+12]	; xmm1 += a

	movss real4 ptr[esp], xmm1		; save xmm1 on the stack
	call ebx						; call T1DFunctionPtr

	movss xmm0, real4 ptr[esp+4]	; xmm0 = height1
	fstp real4 ptr[esp+4]			; save output from T1DFunctionPtr on the stack => height2, at the same time height1 = height2

	; Compute the area of trapezoid:
	addss xmm0, real4 ptr[esp+4]	; xmm0 += height2 
	mulss xmm0, real4 ptr[esp+12]	; xmm0 *= stepSize, xmm0 = areaOfTrapezoid

	; Accumulate the area into the integral( use Kahan summation alg ):
	addss xmm0, real4 ptr[esp+20]	; xmm0 = areaOfTrapezoidWithError
	movss xmm1, real4 ptr[esp+16]	; xmm1 = integral
	movss xmm2, xmm0			
	addss xmm2, xmm1				; xmm2 = newIntegral = integral + areaOfTrapezoidWithError
	movss real4 ptr[esp+16], xmm2	; save newIntegral, integral = newIntegral
	subss xmm2, xmm1				; xmm2 = newIntegral - integral
	subss xmm0, xmm2				; xmm0 = error = ( areaOfTrapezoidWithError - ( newIntegral - integral ) )
	movss real4 ptr[esp+20], xmm0	; save error

	; Check loop
	mov ecx, dword ptr[ebp+20]		; load steps
	cmp ecx, edi					; check if we need to loop again
	jne MAIN_LOOP

	fld real4 ptr [esp+16]			; setup return value: by convention floating point numbers on x86-32 are retruned via x87 top stack register

	add esp, 24						; deallocate stack

	pop ebx							; epilog
	pop ebp							
	ret

NumericalIntegration_ASM_ endp
end