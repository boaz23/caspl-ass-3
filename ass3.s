NULL EQU 0

TRUE EQU 1
FALSE EQU 0

NEW_LINE_TERMINATOR EQU 10
NULL_TERMINATOR EQU 0

STK_UNIT EQU 4

%define align_on(n, base) (((n)-1)-(((n)-1)%(base)))+(base)
%define align_on_16(n) align_on(n, 16)

; SIGNATURE: func_entry(n = 0)
;    n - locals size (in bytes). default is 0
; DESCRIPTION: Prepares the stack frame before executing the function

; esp -= n
%macro func_entry 0-1 0
    push ebp
    mov ebp, esp
    %if align_on_16(%1)
    sub esp, align_on_16(%1)
    %endif
    pushfd
    pushad
%endmacro

; SIGNATURE: func_exit(p_ret_val = eax)
;   p_ret_val - A place to put function return value. default is eax
; DESCRIPTION: cleans stack frame before exiting the function (after function execution)
%macro func_exit 0-1 eax
    popad
    popfd
    %ifidn %1, eax
    %else
    mov eax, %1
    %endif
    mov esp, ebp
    pop ebp
    ret
%endmacro

; SIGNATURE: func_call(p_ret_val, func, ... args)
;   p_ret_val   - A place to put function return value
;   func        - the function to call
;   args        - list of arguments to pass to the function
; DESCRIPTION: calls the function <func> with args <args> and puts the return value in <p_ret_val>
; EXAMPLE:
;   func_call [r], fgets, ebx, MAX_LINE_LENGTH, [stdin]
;   the above is semantically equivalent to:
;       [r] = fgets(ebx, MAX_LINE_LENGTH, [stdin])
%macro func_call 2-*
    %push
    %define $args_size (%0-2)*STK_UNIT
    %define $args_size_aligned align_on_16($args_size)
    %define $align_push_size ($args_size_aligned - $args_size)
    
    %if $align_push_size
    sub esp, $align_push_size
    %endif
    %rep %0-2
        %rotate -1
        push dword %1
    %endrep
    %rotate -1
    call %1
    %rotate -1
    %ifidn %1, eax
    %else
    mov %1, eax
    %endif
    %if $args_size_aligned
    add esp, $args_size_aligned
    %endif
    %pop
%endmacro

%macro void_call 1-*
    func_call eax, %{1:-1}
%endmacro

; SIGNATURE: printf_inline(format_str, ... args)
; DESCRIPTION: calls printf with format_str followed by a null terminator with the specified args
; EXAMPLE:
;   printf_inline "%d", [r]
;   the above is semantically equivalent to:
;       printf("%d", [r])
%macro printf_inline 1-*
    section	.rodata
        %%format: db %1, NULL_TERMINATOR
    section	.text
        %if %0-1
            void_call printf, %%format, %{2:-1}
        %else
            void_call printf, %%format
        %endif
%endmacro

; SIGNATURE: printf_line(format_str, ... args)
; DESCRIPTION: calls printf with format_str followed by new line and null terminator with the specified args
; EXAMPLE:
;   printf_line "%d", [r]
;   the above is semantically equivalent to:
;       printf("%d\n", [r])
%macro printf_line 1-*
    %if %0-1
        printf_inline {%1, NEW_LINE_TERMINATOR}, %{2:-1}
    %else
        printf_inline {%1, NEW_LINE_TERMINATOR}
    %endif
%endmacro

%macro fprintf_inline 2-*
    section	.rodata
        %%format: db %2, NULL_TERMINATOR
    section	.text
        %if %0-2
            void_call fprintf, %1, %%format, %{3:-1}
        %else
            void_call fprintf, %1, %%format
        %endif
%endmacro

%macro fprintf_line 2-*
    %if %0-2
        fprintf_inline %1, {%2, NEW_LINE_TERMINATOR}, %{3:-1}
    %else
        fprintf_inline %1, {%2, NEW_LINE_TERMINATOR}
    %endif
%endmacro

; SIGNATURE: mem_mov(m1, m2, r)
; DESCRIPTION: m1 = r = m2
; EXAMPLE: mem_mov ebx, [ebp-4], [ebp+8]
;   This will copy the value at the memory address ebp+8 to ebp-4
;   while using ebx as an intermediate place to store the result of [ebp+8]
; NOTES:
;   * This can be used to transfer from memory to memory
;     while specifying the intermediate register used
;     (but can also be used with any arbitrary combination of registers and memory)
;   * If used for transfer for memory to memory,
;     the register implicitly determines the operand's sizes
;   * Operand sizes can also be specified explicitly
%macro mem_mov 3
    mov %3, %2
    mov %1, %3
%endmacro

%macro mem_mov 2
    mem_mov %1, %2, eax
%endmacro

; deref(p_res, p_src, reg, fld)
%macro deref 4
    mov %3, %2
    mem_mov %3, %1, [%4(%3)]
%endmacro

; deref(p_res, p_src, fld)
%macro deref 3
    deref %1, %2, eax, %3
%endmacro

; SIGNATURE: mem_swap(r1, m1, r2, m2)
; DESCRIPTION:
;   Swaps the values in m1 and m2 using r1 and r2
;   as intermediate places to store m1 and m2 respectively
; EXAMPLE: mem_mov ebx, [ebp-4], [ebp+8]
;   This will copy the value at the memory address ebp+8 to ebp-4
;   while using ebx as an intermediate place to store the result of [ebp+8]
; NOTES:
;   * This can be used to swap the values in two memory locations
;     while specifying the intermediate registers used
;     (but can also be used with any arbitrary combination of registers and memory)
;   * If used for swapping the values in two memory locations,
;     the registers implicitly determines the operand's sizes
;   * Operand sizes can also be specified explicitly
%macro mem_swap 4
    mov %1, %2
    mov %3, %4
    mov %2, %3
    mov %4, %1
%endmacro

%macro dbg_printf_line 1-*
    ; if (DebugMode) printf(args);
    cmp dword [DebugMode], FALSE
    je %%else
    ; print info
    fprintf_line [stderr], %{1:-1}
    %%else:
%endmacro

%macro print_double 1
    void_call printf, FloatPrintFormat, [%1], [%1+4]
%endmacro
%macro dbg_print_double_st 0
    cmp dword [DebugMode], FALSE
    je %%else

    sub esp, 8
    fst qword [esp]
    push FloatPrintFormat_NewLine
    call printf
    add esp, 12

    %%else:
%endmacro

BOARD_SIZE  EQU 100

UI16_MAX_VALUE EQU 0FFFFh

section .rodata
    ; constants
    BoardSize: dd BOARD_SIZE
    UI16MaxValue: dd UI16_MAX_VALUE
    FloatPrintFormat: db "%f", NULL_TERMINATOR
    FloatPrintFormat_NewLine: db "%f", NEW_LINE_TERMINATOR, NULL_TERMINATOR


section .data
    global DebugMode
    global N
    global R
    global K
    global d
    global seed

    global LSFR
    global TargetPosition
    global IsTargetAlive

    ; command line arguments
    DebugMode: dd FALSE
    N: dd 0
    R: dd 0
    K: dd 0
    d: dq 0
    seed: dw 0

    ; program state globals
    ; NOTE: float point better be in double precision (64-bit, double)
    ;       because printf cannot deal with single precision (32-bit, float)
    LSFR: dd 0 ; NOTE: we should use only 2 bytes, but it's easier to deal
               ;       with 4 bytes in most instructions and calculations
    RandomNumber: dq 0
    TargetPosition: dq 0
    IsTargetAlive: dd FALSE

section .text
align 16
global main

extern printf
extern fprintf
extern sscanf

extern stdin
extern stdout
extern stderr

extern malloc
extern calloc
extern free

global never_lucky

shift_lsfr:
    func_entry

    mov eax, 0
    bt word [LSFR], 16 - 16
    adc al, 0
    bt word [LSFR], 16 - 14
    adc al, 0
    bt word [LSFR], 16 - 13
    adc al, 0
    bt word [LSFR], 16 - 11
    adc al, 0
    bt ax, 0
    rcr word [LSFR], 1
    
    func_exit

; generates a new 'random' number of size 2 bytes
rng:
    func_entry

    mov ecx, 16
    .shift_lsfr:
    void_call shift_lsfr
    loop .shift_lsfr, ecx

    func_exit

; calculates the absolute value of x
abs_int: ; abs(int x)
    %push
    %define $x ebp+8
    %define $abs_val ebp-4
    func_entry 4

    ; if (x = 0) goto non_negative
    mem_mov [$abs_val], [$x], eax
    cmp dword [$abs_val], 0
    jge .non_negative

    .negative:
    ; x = -x
    neg dword [$abs_val]

    .non_negative:

    .exit:
    func_exit [$abs_val]
    %pop


; calculates the distance between 2 points in 1 dimentional space
; return | x1 - x2 |
distance_1d_int: ; distance_1d(int x1, int x2)
    %push
    %define $x1 ebp+8
    %define $x2 ebp+12
    %define $distance ebp-4
    func_entry 4

    ; eax = x1 - x2
    mov eax, dword [$x1]
    mov ebx, dword [$x2]
    sub eax, ebx
    func_call [$distance], abs_int, eax

    func_exit [$distance]
    %pop

; generates a new 'random' 'real' (floating point) number in the range [start, end]
never_lucky: ; never_lucky(int start, int end)
    %push
    %define $start ebp+8
    %define $end ebp+12
    %define $range_len ebp-4
    func_entry 4

    ; range_len = | start - end |
    func_call [$range_len], distance_1d_int, [$start], [$end]
    void_call rng
    
    finit ; init x87 registers

    fild dword [LSFR]
    fild dword [UI16MaxValue]
    fdivp ; st0 = LSFR / UI16MaxValue

    fild dword [$range_len]
    fmulp ; st0 = st0 * range_len

    fild dword [$start]
    faddp ; st0 += start

    ; RandomNumber = st0
    fstp qword [RandomNumber]

    func_exit
    %pop

main:
    func_entry

    mov dword [LSFR], 00000F5A5h
    mov dword [DebugMode], TRUE
    void_call never_lucky, -10, 10

    func_exit