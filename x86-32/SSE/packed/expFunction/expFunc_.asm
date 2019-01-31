; x86-32 assembly, SSE2

.model flat,c 

.const
align 16
FLOAT_SUM_INIT real4 0.0,0.0,0.0,1.0
FLOAT_RECIPROCALS_1 real4 1.0,0.5,0.16666666667,0.04166666667
FLOAT_RECIPROCALS_2 real4 0.00833333333,0.00138888889,0.0001984127,0.00002480159
FLOAT_RECIPROCALS_3 real4 0.00000275573,2.75573192e-7,2.50521084e-8,2.0876757e-9
FLOAT_RECIPROCALS_4 real4 1.6059044e-10,1.1470746e-11,7.6471637e-13,4.77947726e-14

.code

; Macro perform horizontal add. Note that SSE2 does not have any direct instruction do it.
HORIZONTAL_ADD macro XMM_IN_OUT_REGISTER, XMM_TEMP_REGISTER
    movaps XMM_TEMP_REGISTER, XMM_IN_OUT_REGISTER
    shufps XMM_TEMP_REGISTER, XMM_IN_OUT_REGISTER, 01001110b
    addps XMM_TEMP_REGISTER, XMM_IN_OUT_REGISTER
    movaps XMM_IN_OUT_REGISTER, XMM_TEMP_REGISTER
    shufps XMM_IN_OUT_REGISTER, XMM_TEMP_REGISTER, 01011111b
    addps XMM_IN_OUT_REGISTER, XMM_TEMP_REGISTER
endm

; extern "C" float ExpFunc_SSE( float x );
;
; Approximates exp function with Maclaurin series up to the 16th derivative.
ExpFunc_SSE proc
    push ebp
    mov ebp, esp
    sub esp, 4                      ; preallocate the stack. This is only needed for transfer from xmm 
                                    ; registers to x87 stack, as there is no direct way of doing the transfer.

    movss xmm0, real4 ptr[ebp+8]	; xmm0 = x
    movaps xmm1, xmm0               ; xmm1 = x
    unpcklps xmm1, xmm0             ; xmm1 = [?,?,x,x]
    mulss xmm0, xmm1                ; xmm0 = x^2
    mulss xmm0, xmm1                ; xmm0 = x^3
    movaps xmm2, xmm1
    unpcklps xmm2, xmm0             ; xmm2 = [?,?,x^3,x]
    mulps xmm1, xmm2                ; xmm1 = [?,?,x^4,x^2]
    unpcklps xmm2, xmm1             ; xmm2 = [x^4,x^3,x^2,x]

    movaps xmm0, xmm2
    shufps xmm0, xmm0, 11111111b    ; xmm0 = [x^4,x^4,x^4,x^4]

    ; Start calculating series:
    ; [TODO]: Long dependency chain?

    movaps xmm4, xmmword ptr[FLOAT_SUM_INIT]        ; xmm4 = curr sum
   
    movaps xmm5, xmmword ptr[FLOAT_RECIPROCALS_1]   ; xmm5 contains reciprocals for first four elements of the series.
    mulps xmm5, xmm2                                ; calculate first four elements of the series.
    addps xmm4, xmm5                                ; update sum

    movaps xmm5, xmmword ptr[FLOAT_RECIPROCALS_2]
    mulps xmm2, xmm0                                ; xmm2 = [x^8,x^7,x^6,x^5]
    mulps xmm5, xmm2                                
    addps xmm4, xmm5                                ; update sum
    
    movaps xmm5, xmmword ptr[FLOAT_RECIPROCALS_3]
    mulps xmm2, xmm0                                ; xmm2 = [x^12,x^11,x^10,x^9]
    mulps xmm5, xmm2                                
    addps xmm4, xmm5                                ; update sum
    
    movaps xmm5, xmmword ptr[FLOAT_RECIPROCALS_4]
    mulps xmm2, xmm0                                ; xmm2 = [x^16,x^15,x^14,x^13]
    mulps xmm5, xmm2                                
    addps xmm4, xmm5                                ; update sum

    ; Perform horizontal add to calculate final sum of the series:
    HORIZONTAL_ADD xmm4, xmm6

    movss real4 ptr[esp], xmm4
    fld real4 ptr [esp]             ; setup return value: by convention floating point numbers on x86-32 are retruned via x87 top stack register

END_PROLOG:
    add esp, 4
    pop ebp
    ret

ExpFunc_SSE endp

end