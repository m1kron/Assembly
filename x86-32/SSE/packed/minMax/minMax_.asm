; x86-32 assembly

.model flat,c 

.const
INT32_MIN dword 080000000h
INT32_MAX dword 07fffffffh
PTR_ALIGNMENT dword 00000000Fh
SIZE_ALIGNMENT dword 000000007h

align 16
INT32_MIN_PACKED dword 080000000h,080000000h,080000000h,080000000h
INT32_MAX_PACKED dword 07fffffffh,07fffffffh,07fffffffh,07fffffffh

.code

; extern "C" MinMaxInfo FindMinMax_SSE( int32_t* array, uint32_t arraySize );
;
; Finds min and max in the array using assembly. Array has to be aligned to 16 byte, size must be multiple of 4.
; [NOTE]: Return value will be returned via EAX:EDX registers, as x86-32 convention requires.
FindMinMax_SSE proc
    push ebp
    mov ebp, esp

    mov ecx, [ebp+8]                ; ecx = array ptr
    test ecx, PTR_ALIGNMENT         ; check alignment of array ptr
    jnz BAD_INPUT

    mov edx, [ebp+12]               ; edx = arraySize
    test edx, SIZE_ALIGNMENT        ; check is size is multiple of 8
    jnz BAD_INPUT

    shr edx,3                       ; edx = arraySize/8, counts number of packed iterations

    movdqa xmm0, xmmword ptr [INT32_MAX_PACKED]	; xmm0 = running min values 1.
    movdqa xmm1, xmmword ptr [INT32_MIN_PACKED]	; xmm1 = running max values 1.

    movdqa xmm4, xmmword ptr [INT32_MAX_PACKED]	; xmm4 = running min values 2.
    movdqa xmm5, xmmword ptr [INT32_MIN_PACKED]	; xmm5 = running max values 2.

MAIN_LOOP:
    movdqa xmm2, xmmword ptr[ecx]   ; xmm2 = ontains next packed values
    movdqa xmm6, xmmword ptr[ecx+16]; xmm6 = ontains next packed values

    movdqa xmm3, xmm2
    movdqa xmm7, xmm6

    pminsd xmm0, xmm2               ; select min values 1
    pmaxsd xmm1, xmm3               ; select max values 1

    pminsd xmm4, xmm6               ; select min values 2
    pmaxsd xmm5, xmm7               ; select max values 2

    add ecx, 32                     ; update array ptr
    dec edx                         ; continue loop if there is more data to process.
    jnz MAIN_LOOP

    ; MAIN_LOOP IS DONE, now calculate final min and max:

    ; Merge two running mins and maxes:
    pminsd xmm0, xmm4
    pmaxsd xmm1, xmm5

    ; Calc final min: 

    movdqa xmm2, xmm0
    pshufd xmm2, xmm2, 00001110b    ; xmm2[0:63]=xmm[64:127]
    pminsd xmm0, xmm2               ; xmm0[0:63] constains two most min values

    movdqa xmm2, xmm0
    pshufd xmm2, xmm2, 00000001b    ; xmm2[0:31] = xmm2[32:63]
    pminsd xmm0, xmm2               ; xmm0[0:31] contains min value

    movd eax, xmm0                  ; save min value in final destination

    ; Calc final max:
    movdqa xmm3, xmm1
    pshufd xmm3, xmm3, 00001110b    ; xmm3[0:63]=xmm3[64:127]
    pmaxsd xmm1, xmm3               ; xmm1[0:63] constains two most max values

    movdqa xmm3, xmm1
    pshufd xmm3, xmm3, 00000001b    ; xmm3[0:31] = xmm3[32:63]
    pmaxsd xmm1, xmm3               ; xmm1[0:31] contains max value

    movd edx, xmm1                  ; save max value in final destination
    jmp  END_PROLOG

BAD_INPUT:
    ; Set default values:
    mov eax, INT32_MAX
    mov edx, INT32_MIN

END_PROLOG:
    pop ebp
    ret

FindMinMax_SSE endp

end