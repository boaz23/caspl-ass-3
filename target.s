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
    %push func_entry
    %define %$_stack_reserve_size align_on_16(%1)

    push ebp
    mov ebp, esp
    %if %$_stack_reserve_size
    sub esp, %$_stack_reserve_size
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
    %if %$_stack_reserve_size
    mov esp, ebp
    %endif
    pop ebp
    ret
    %pop
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
    %define %$args_size (%0-2)*STK_UNIT
    %define %$args_size_aligned align_on_16(%$args_size)
    %define %$push_size_aligned_complement (%$args_size_aligned - %$args_size)
    
    %if %$push_size_aligned_complement
    sub esp, %$push_size_aligned_complement
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
    %if %$args_size_aligned
    add esp, %$args_size_aligned
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
    section .rodata
        %%format: db %1, NULL_TERMINATOR
    section .text
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
    section .rodata
        %%format: db %2, NULL_TERMINATOR
    section .text
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

%macro dbg_print_line 1-*
    %%dbg_print:
    ; if (DebugMode) printf(args);
    cmp dword [DebugMode], FALSE
    je %%not_debug_mode
    ; print info
    fprintf_line [stderr], %{1:-1}
    %%not_debug_mode:
%endmacro

%macro mem_double_mov 2-3 eax
    mem_mov [%1], [%2], %3
    mem_mov [%1+4], [%2+4], %3
%endmacro

%macro print_double 1
    void_call printf, FloatPrintFormat, [%1], [%1+4]
%endmacro
%macro dbg_print_double 2
    %%dbg_print_double:
    cmp dword [DebugMode], FALSE
    je %%not_debug_mode
    fprintf_line [stderr], {%1, "%.2f"}, [%2], [%2+4]
    %%not_debug_mode:
%endmacro
%macro dbg_print_double_st 0
    %%dbg_print_double_st:
    cmp dword [DebugMode], FALSE
    je %%not_debug_mode

    sub esp, 8
    fst qword [esp]
    push FloatPrintFormat_NewLine
    call printf
    add esp, 12

    %%not_debug_mode:
%endmacro

%macro co_resume 1
    push ebx
    mov ebx, %1
    call resume
    pop ebx
%endmacro

section .rodata
f_target: db "Target %d", 10, 0

section .text
extern printf
extern fprintf
extern stderr
extern FloatPrintFormat
extern FloatPrintFormat_NewLine
extern DebugMode

extern resume
extern CoId_Scheduler
extern CurrentDroneId

extern TargetPosition

extern BoardHeight
extern BoardWidth
extern d
extern Position
extern RandomNumber

extern gen_rand_num_in_range

global target_co_func
global mayDestroy

target_co_func:

    .loop:
        void_call createTarget
        dbg_print_line "Targer resuming drone %d", [CurrentDroneId]
        co_resume dword [CurrentDroneId]

        jmp .loop
    .loop_end:

mayDestroy:
    func_entry 4
    ; return sqrt((x - tx)^2 + (y - ty)^2) <= d
    %define %$may_destory ebp-4

    fld qword [TargetPosition]
    fld qword [Position]
    fsubp ; dx = Position.x - TargetPosition.x
    fld st0
    fmulp ; st0 = st0^2

    dbg_print_line ""
    fld qword [TargetPosition+8]
    fld qword [Position+8]
    fsubp ; dy = Position.y - TargetPosition.y
    fld st0
    fmulp ; st0 = st0^2

    faddp ; st0 = dx^2 + dy^2
    fsqrt ; st0 = sqrt(st0)

    ; d >= sqrt((x - tx)^2 + (y - ty)^2)
    ; !(d < sqrt((x - tx)^2 + (y - ty)^2))
    ; !(st0 < st1)

    ; st1 = sqrt((x - tx)^2 + (y - ty)^2)
    ; st0 = d
    ; if (d <= sqrt((x - tx)^2 + (y - ty)^2))
    fld qword [d]
    fcomip
    jnc .may_destory
    .may_not_destory:
        mov dword [%$may_destory], FALSE
        jmp .exit
    .may_destory:
        mov dword [%$may_destory], TRUE
        jmp .exit

    .exit:
    fstp st0
    dbg_print_line "may destroy: %d", [%$may_destory]
    func_exit [%$may_destory]

createTarget:
    push ebp
    mov ebp, esp
    pushf
    pusha

    ;generate x position
    push dword [BoardWidth]
    push 0
    call gen_rand_num_in_range
    add esp, 8
    mem_double_mov TargetPosition, RandomNumber

    ;generate y position
    push dword [BoardHeight]
    push 0
    call gen_rand_num_in_range
    add esp, 8
    mem_double_mov TargetPosition+8, RandomNumber

    popa
    popf
    pop ebp
    ret