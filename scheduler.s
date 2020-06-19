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

UI16_MAX_VALUE EQU 0FFFFh
BOARD_WIDTH  EQU 100
BOARD_HEIGHT EQU 100
DRONE_MAX_SPEED EQU 100
MAX_ANGLE EQU 360

section .text
    extern DebugMode
    extern N
    extern R
    extern K

    extern CORS
    extern CURR
    extern CURR_ID
    extern CoId_Printer
    extern CoId_Target

    extern CurrentDroneId
    extern DronesArr

    extern resume
    extern end_co
    extern printf

    global scheduler_co_func

%macro inc_round_modulo 2
    ; increment value in %2 modulo:
    ; (if ++value == %2) value = 0
    inc %1
    mov eax, %2
    cmp %1, eax
    je %%no_value_reset
    %%no_value_reset:
    nop
    %%value_reset:
    mov %1, 0
%endmacro
    
scheduler_co_func:
    %push
    %define %$i ebp-4
    %define %$round ebp-8
    %define %$rounds_since_last_elim_round ebp-12
    %define %$steps_since_last_printer ebp-16

    %define %$drone_id ebp-20
    %define %$next_drone_id ebp-24
    ; stores the amount of drones seen in a round thus far in the round
    %define %$drones_i_round ebp-28

    mov dword [%$i], 0
    mov dword [%$round], 0
    mov dword [%$rounds_since_last_elim_round], 0
    mov dword [%$steps_since_last_printer], 0

    mov dword [%$drone_id], -1
    mov dword [%$drones_i_round], 0
    func_call [%$next_drone_id], find_next_active_drone_id, [%$drone_id]

    .scheduler_loop:
        ; check whether we should print the board
        cmp dword [%$steps_since_last_printer], 0
        jne .no_print_board
        .print_board:
        co_resume dword [CoId_Printer]
        jmp .check_for_elim_round
        .no_print_board:
        nop

        ; check whether we need to eliminate a drone
        .check_for_elim_round:
        ; check if we're at the very first step of the sceduler loop
        cmp dword [%$i], 0
        je .no_drone_elim
        ; check if we are at the start of a round
        cmp dword [%$drone_id], -1
        jge .no_drone_elim
        ; check if we are at an elimination round
        cmp dword [%$rounds_since_last_elim_round], 0
        jne .no_drone_elim
        .eliminate_drone:
        func_call eax, find_drone_id_with_lowest_score
        mov ebx, dword [DronesArr]
        mov eax, dword [ebx+4*eax]
        mov dword [drone_is_active(eax)], FALSE
        jmp .move_to_next_drone
        .no_drone_elim:
        nop

        ; check if we have a next drone to run in this round
        .move_to_next_drone:
        mem_mov dword [%$drone_id], dword [%$next_drone_id]
        cmp dword [%$drone_id], 0
        jl .next_round

        mem_mov dword [CurrentDroneId], dword [%$drone_id]
        .next_drone_found:
            ; find the next drone to run in this round
            ; if the next drone id is < 0 (-1), therefore there are no drone left to run this round
            inc dword [%$drones_i_round]
            func_call [%$next_drone_id], find_next_active_drone_id, [%$drone_id]
            cmp dword [%$next_drone_id], 0
            jge .call_next_drone

            .check_left_drones_count:
            ; if only one is left, we got a winner
            cmp dword [%$drones_i_round], 1
            je .winner

        .next_round:
            ; init vars for the next round
            inc dword [%$round]
            inc dword [%$rounds_since_last_elim_round]
            inc_round_modulo dword [%$rounds_since_last_elim_round], dword [R]
        .next_round_init:
            mov dword [%$drone_id], -1
            mov dword [%$drones_i_round], 0
            func_call [%$next_drone_id], find_next_active_drone_id, [%$drone_id]
            jmp .scheduler_loop

        .call_next_drone:
        co_resume dword []

        inc_round_modulo dword [%$steps_since_last_printer], dword [K]

        ; next step
        .loop_increment:
        inc dword [%$i]
        jmp .scheduler_loop
    .scheduler_loop_end:

    .winner:
        mov eax, [CurrentDroneId]
        inc eax
        printf_line "The Winner is drone: ", eax
    
    .end_scheduler:
    jmp end_co
    %pop

; (start not included)
find_next_active_drone_id: ; find_next_active_drone(int start)
    func_entry 4
    %define %$start ebp+8
    %define %$i ebp-4

    mem_mov dword [%$i], dword [%$start]
    inc dword [%$i]
    .drone_arr_loop:
    mov eax, dword [N]
    cmp dword [%$i], eax
    jge .not_found

    mov eax, dword [DronesArr]
    mov ebx, dword [%$i]
    mov eax, dword [eax+4*ebx]
    cmp dword [drone_is_active(eax)], FALSE
    je .drone_arr_loop_continue
    jmp .found

    .drone_arr_loop_continue:
    jmp .drone_arr_loop_end
    .drone_arr_loop_end:

    .not_found:
        mov dword [%$i], -1
        jmp .exit
    .found:

    .exit:
    func_exit [%$i]

find_drone_id_with_lowest_score: ; find_drone_with_lowest_score(): int