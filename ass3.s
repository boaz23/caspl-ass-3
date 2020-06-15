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

%macro dbg_print_line 1-*
    ; if (DebugMode) printf(args);
    cmp dword [DebugMode], FALSE
    je %%not_debug_mode
    ; print info
    fprintf_line [stderr], %{1:-1}
    %%not_debug_mode:
%endmacro

%macro print_double 1
    void_call printf, FloatPrintFormat, [%1], [%1+4]
%endmacro
%macro dbg_print_double 2
    cmp dword [DebugMode], FALSE
    je %%not_debug_mode
    fprintf_line [stderr], {%1, "%.2f"}, [%2], [%2+4]
    %%not_debug_mode:
%endmacro
%macro dbg_print_double_st 0
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

UI16_MAX_VALUE EQU 0FFFFh

BOARD_SIZE EQU 100

;struct drone {
;    double x;
;    double y;
;    double speed;
;    double angle;
;    int score;
;    bool is_active;
;}
%define drone_x(d) d+0
%define drone_y(d) d+8
%define drone_speed(d) d+16
%define drone_angle(d) d+24
%define drone_score(d) d+32
%define drone_is_active(d) d+36
sizeof_drone EQU 40

section .rodata
    align 16

    ; constants
    BoardSize: dd BOARD_SIZE
    UI16MaxValue: dd UI16_MAX_VALUE
    FloatPrintFormat: db "%.2f", NULL_TERMINATOR
    FloatPrintFormat_NewLine: db "%.2f", NEW_LINE_TERMINATOR, NULL_TERMINATOR

section .bss
    align 16
    STKSZ equ 16*1024

    ; co-routines: stack allocation
    STK_SCHEDULER: resb STKSZ
    STK_PRINTER:   resb STKSZ
    STK_TARGET:    resb STKSZ

section .data
    align 16

    ; command line arguments
    global DebugMode
    global N
    global R
    global K
    global d
    global seed

    DebugMode: dd FALSE
    N: dd 0
    R: dd 0
    K: dd 0
    d: dq 0
    seed: dw 0

    ; program state globals
    global LSFR
    global TargetPosition

    ; NOTE: float point better be in double precision (64-bit, double)
    ;       because printf cannot deal with single precision (32-bit, float)
    LSFR: dd 0 ; NOTE: we should use only 2 bytes, but it's easier to deal
               ;       with 4 bytes in most instructions and calculations
    RandomNumber: dq 0
    ; NOTE: the position of the target sits in this file because
    ; the assignment page says to use globals and that all globals should
    ; sit in this file
    TargetPosition: dq 0, 0 ; (double x, double y)

    ; co-routines: global state and temporary variables
    global CORS
    global CURR
    global CURR_ID
    
    CORS:    dd NULL
    CURR:    dd NULL
    CURR_ID: dd -1
    SPT:     dd NULL
    BPT:     dd NULL
    SPMAIN:  dd NULL ; main's stack pointer

    COR_SIZE equ 16

    CODEP  equ 0
    FLAGSP equ 4
    SPP    equ 8
    BPP    equ 12
    ;struct COR {
    ;    void (*func)(); // func pointer
    ;    int flags;
    ;    void *spp; // stack pointer
    ;    void *bpp; // base pointer
    ;}

    ; co-routines: static co-routines initialization
    CO_ARGS_COUNT equ 1
    %define co_routine_bp_offset(sp) sp+STKSZ-((CO_ARGS_COUNT + 2) * STK_UNIT)
    %define define_co_routine(func, sp) dd func, 0, co_routine_bp_offset(sp), co_routine_bp_offset(sp)
    
    CO_SCHEDULER: define_co_routine(scheduler_co_func, STK_SCHEDULER)
    CO_PRINTER:   define_co_routine(printer_co_func,   STK_PRINTER)
    CO_TARGET:    define_co_routine(target_co_func,    STK_TARGET)

    global CO_ID_SCHEDULER
    global CO_ID_PRINTER
    global CO_ID_TARGET

    CO_ID_SCHEDULER: dd -1
    CO_ID_PRINTER:   dd -1
    CO_ID_TARGET:    dd -1

    %undef define_co_routine
    %undef co_routine_bp_offset

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

global resume
global end_co
global never_lucky
extern scheduler_co_func
extern printer_co_func
extern target_co_func

;-----------------------------------------
;-------------- CO-ROUTINES --------------
;-----------------------------------------

init_co: ; init_co(int co_routine_id)
    func_entry
    mov EBX, [EBP+8]
    mov ECX, EBX
    mov EBX, [CORS]
    mov EBX, [EBX+ECX*4]
    bts dword [EBX+FLAGSP], 0  ; test if already initialized
    jc  .init_done

    .init:
    mov EAX, [EBX+CODEP] ; Get initial PC
    ; save stack and base pointers
    mov [SPT], ESP
    mov [BPT], EBP

    mov ESP, [EBX+SPP]   ; Get initial SP
    mov EBP, [EBX+BPP]   ; Also use as EBP
    mov [EBP+8], ECX
    push EAX ; Push initial "return" address
    pushf    ; and flags
    pusha    ; and all other regs
    mov [EBX+SPP], ESP ; Save new SP in structure

    ; restore stack and base pointers
    mov EBP, [BPT]
    mov ESP, [SPT]

    .init_done:
    func_exit

; EBX is pointer to co-init structure of co-routine to be resumed
; CURR holds a pointer to co-init structure of the curent co-routine
resume: ; resume(int ebx = resume_co_routine_id)
    .save_state_of_calling_routine:
    pushfd
    pushad
    mov EDX, [CURR]
    ; save stack and base pointer in co-routine structure
    mov [EDX+SPP], ESP
    mov [EDX+BPP], EBP
do_resume:
    .restore_state_of_resumed_routine:
    mov ECX, EBX
    mov EBX, [CORS]
    mov EBX, [EBX+ECX*4]

    mov ESP, [EBX+SPP]  ; Load SP for resumed co-routine
    mov EBP, [EBX+BPP]   ; Also use as EBP
    mov [CURR], EBX
    mov [CURR_ID], ECX
    popad ; Restore resumed co-routine state
    popfd

    .resume:
    ret                     ; "return" to resumed co-routine!

; C-callable start of the first co-routine
start_co: ; start_co(int co_routine_id)
    func_entry

    ; Save stack and base pointers of main code
    mov [SPMAIN], ESP

    mov EBX, [EBP+8] ; Get number of co-routine
    jmp do_resume

; End co-routine mechanism, back to C main
end_co:
    ; Restore state of main code (including EBP)
    mov ESP, [SPMAIN]
    func_exit

;---------------------------------
;-------------- RNG --------------
;---------------------------------
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

; generates a new 'random' 'real' (floating point) number in the range [start, end]
gen_rand_num_in_range: ; never_lucky(int start, int end)
    func_entry 4
    %define %$start ebp+8
    %define %$end ebp+12
    %define %$range_len ebp-4

    ; range_len = | start - end |
    func_call [%$range_len], distance_1d_int, [%$start], [%$end]
    void_call rng

    fild dword [LSFR]
    fild dword [UI16MaxValue]
    fdivp ; st0 = LSFR / UI16MaxValue

    fild dword [%$range_len]
    fmulp ; st0 = st0 * range_len

    fild dword [%$start]
    faddp ; st0 += start

    ; RandomNumber = st0
    fstp qword [RandomNumber]
    dbg_print_double "Generated Random Number: ", RandomNumber

    func_exit

; calculates the absolute value of x
abs_int: ; abs(int x)
    func_entry 4
    %define %$x ebp+8
    %define %$abs_val ebp-4

    ; if (x = 0) goto non_negative
    mem_mov [%$abs_val], [%$x], eax
    cmp dword [%$abs_val], 0
    jge .non_negative

    .negative:
    ; x = -x
    neg dword [%$abs_val]

    .non_negative:

    .exit:
    func_exit [%$abs_val]


; calculates the distance between 2 points in 1 dimentional space
; return | x1 - x2 |
distance_1d_int: ; distance_1d(int x1, int x2)
    func_entry 4
    %define %$x1 ebp+8
    %define %$x2 ebp+12
    %define %$distance ebp-4

    ; eax = x1 - x2
    mov eax, dword [%$x1]
    mov ebx, dword [%$x2]
    sub eax, ebx
    func_call [%$distance], abs_int, eax

    func_exit [%$distance]

;---------------------------------
;-------------- Main -------------
;---------------------------------
main:
    func_entry 4
    %define %$argc ebp+8
    %define %$argv ebp+12
    %define %$exit_code ebp-4

    finit
    mov dword [%$exit_code], 0

    func_call eax, parse_command_line_args, [%$argc], [%$argv]
    ; check if args are valid
    cmp eax, FALSE
    jne .arg_valid
    mov dword [%$exit_code], 1
    jmp .exit
    .arg_valid:
    ; LSFR = seed
    movzx eax, word [seed]
    mov dword [LSFR], eax

    func_call [CORS], malloc, COR_SIZE*3
    mov eax, dword [CORS]
    mov dword [eax+0], CO_PRINTER
    mov dword [eax+4], CO_TARGET
    mov dword [eax+8], CO_SCHEDULER

    void_call init_co, 0
    void_call init_co, 1
    void_call init_co, 2
    
    void_call start_co, 2

    printf_line "Conrol returned to main"
    void_call free, [CORS]

    .exit:
    func_exit [%$exit_code]

; cmp_char(str, i, c, else)
; if (str[i] != c) goto else;
%macro cmp_char 4
    mov eax, %1
    mov al, byte [eax+%2]
    cmp al, %3
    jne %4
%endmacro

%push
%define %$argc ebp+8
%define %$argv ebp+12

%macro parse_command_line_arg 5
    section .rodata
        %%format: db %2, NULL_TERMINATOR
    section .text
        mov eax, dword [%$$argv]
        mov eax, dword [eax+4*%1]
        func_call eax, sscanf, eax, %%format, %3
        cmp eax, 1
        je %%arg_valid
        %%arg_invalid:
        printf_line {"Invalid command line arg: ", %5}
        jmp %4
        %%arg_valid:
        nop
%endmacro

parse_command_line_args: ; parse_command_line_args(int argc, char *argv[]): bool
    func_entry 4
    %define %$are_args_valid ebp-4

    mov dword [%$are_args_valid], FALSE
    cmp dword [%$$argc], 6
    jge .enough_args
    printf_line "Expected at least 5 args, got %d", [%$$argc]
    jmp .exit

    .enough_args:
    .parse_N:
    parse_command_line_arg 1, "%d", N, .exit, "N"
    .parse_R:
    parse_command_line_arg 2, "%d", R, .exit, "R"
    .parse_K:
    parse_command_line_arg 3, "%d", K, .exit, "K"
    .parse_d:
    parse_command_line_arg 4, "%f", d, .exit, "d"
    fld dword [d]
    fstp qword [d]
    .parse_seed:
    parse_command_line_arg 5, "%hd", seed, .exit, "seed"
    
    .parse_debug_mode_arg:
    cmp dword [%$$argc], 7
    jl .parse_successful
    mov eax, [%$$argv]
    mov eax, dword [eax+4*6]
    func_call eax, is_debug_mode_arg, eax
    cmp eax, FALSE
    je .invalid_debug_arg
    jmp .debug_mode_on
    
    .invalid_debug_arg:
    printf_line "Expected debug mode arg as arg number 6"
    .debug_mode_on:
    mov dword [DebugMode], TRUE
    .debug_arg_prints:
    dbg_print_line "N = %d", [N]
    dbg_print_line "R = %d", [R]
    dbg_print_line "K = %d", [K]
    dbg_print_double "d = ", d
    dbg_print_line "seed = %hd, %04X", [seed], [seed]

    .parse_successful:
    ; are_args_valid = true;
    mov dword [%$are_args_valid], TRUE

    .exit:
    func_exit [%$are_args_valid]

is_debug_mode_arg: ; is_arg_debug(char *arg): boolean
    func_entry 4
    %define $arg ebp+8
    %define $is_dbg ebp-4

    ; is_dbg = false;
    mov dword [$is_dbg], FALSE
    cmp_char dword [$arg], 0, '-', .exit                ; if (arg[0] != '-')  goto exit;
    cmp_char dword [$arg], 1, 'D', .exit                ; if (arg[1] != 'd')  goto exit;
    cmp_char dword [$arg], 2, NULL_TERMINATOR, .exit    ; if (arg[2] != '\0') goto exit;
    ; is_dbg = true;
    mov dword [$is_dbg], TRUE

    .exit:
    func_exit [$is_dbg]
%undef parse_command_line_arg
%pop