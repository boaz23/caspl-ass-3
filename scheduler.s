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
    nop
    %%dbg_print:
    ; if (DebugMode) printf(args);
    cmp dword [DebugMode], FALSE
    je %%not_debug_mode
    ; print info
    fprintf_line [stderr], %{1:-1}
    %%not_debug_mode:
    nop
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
    extern fprintf
    extern stderr

    global scheduler_co_func

%macro inc_round_modulo 2
    nop
    %%inc_round_modulo:
    ; increment value in %2 modulo:
    ; (if ++value == %2) value = 0
    inc %1
    mov eax, %2
    cmp %1, eax
    jne %%no_value_reset
    %%value_reset:
    mov %1, 0
    %%no_value_reset:
    nop
%endmacro
    
scheduler_co_func:
    %push
    %define %$i ebp-4
    %define %$round ebp-8
    %define %$rounds_since_last_elim_round ebp-12
    %define %$steps_since_last_printer ebp-16
    %define %$drone_id ebp-20
    %define %$winner_id ebp-24
    %define %$tmp_drone_id ebp-28
    %define %$tmp_buf ebp-32
    push ebp
    mov ebp, esp
    sub esp, 32

    .scheduler_start:
    dbg_print_line "SCHEDULER"

    .init_scheduler_vars:
    mov dword [%$i], 0
    mov dword [%$round], 0
    mov dword [%$rounds_since_last_elim_round], 0
    mov dword [%$steps_since_last_printer], 0
    mov dword [%$drone_id], 0

    .scheduler_loop:
        dbg_print_line "----------"
        dbg_print_line "scheduler"
        dbg_print_line "i: %d", [%$i]
        dbg_print_line "drone id: %d", [%$drone_id]
        dbg_print_line "steps since last printer: %d", [%$steps_since_last_printer]
        dbg_print_line "round: %d", [%$round]
        dbg_print_line "rounds since last elim round: %d", [%$rounds_since_last_elim_round]

        ; print
        ; check whether we should print the board
        ; if (steps_since_last_printer == 0) print board
        .check_board_print:
        cmp dword [%$steps_since_last_printer], 0
        jne .no_print_board
        .print_board:
        dbg_print_line "Calling printer"
        .print_board.resume:
        co_resume dword [CoId_Printer]
        .no_print_board:
        nop

        ; eliminate drone
        ; check whether we need to eliminate a drone
        .check_for_elim_round:

        ; check if we're at the very first step of the sceduler loop
        ; if (i == 0) skip elimination
        cmp dword [%$i], 0
        je .no_drone_elim

        ; check if we are at the start of a round
        ; if (drone_id > 0) skip elimination
        cmp dword [%$drone_id], 0
        jg .no_drone_elim

        ; check if we are at an elimination round
        ; if (rounds_since_last_elim_round != 0) skip elimination
        cmp dword [%$rounds_since_last_elim_round], 0
        jne .no_drone_elim

        .eliminate_drone:
        ; DronesArr[find_drone_id_with_lowest_score()]->is_active = false
        func_call [%$tmp_drone_id], find_drone_id_with_lowest_score
        dbg_print_line "Eliminating drone: %d", [%$tmp_drone_id]
        .eliminate_drone.set_is_active:
        mov eax, [%$tmp_drone_id]
        mov ebx, dword [DronesArr]
        mov eax, dword [ebx+4*eax]
        mov dword [drone_is_active(eax)], FALSE
        .no_drone_elim:
        nop

        .check_if_game_ended:
        ; eax = find_last_active_drone_id()
        ; if (eax >= 0) winner is eax
        ; else { continue game }
        func_call eax, find_last_active_drone_id
        cmp eax, 0
        jl .continue_game
        mov dword [%$winner_id], eax
        jmp .winner
        .continue_game:
        nop

        .check_if_drone_is_active:
        ; if (!DronesArr[drone_id]->is_active) continue;
        mov eax, [%$drone_id]
        mov ebx, dword [DronesArr]
        mov eax, dword [ebx+4*eax]
        cmp dword [drone_is_active(eax)], FALSE
        je .loop_increment

        .call_next_drone:
        dbg_print_line "Calling drone %d", [%$drone_id]
        .call_next_drone.resume:
        mem_mov dword [CurrentDroneId], dword [%$drone_id]
        co_resume dword [CurrentDroneId]

        ; next step
        .loop_increment:
        inc dword [%$drone_id]

        .loop_increment.check_if_round_ended:
        ; if (drone_id == N) round ended
        mov eax, dword [N]
        cmp dword [%$drone_id], eax
        jl .loop_increment.round_continue

        .loop_increment.next_round:
        ; init vars for the next round
        inc dword [%$round]
        inc_round_modulo dword [%$rounds_since_last_elim_round], dword [R]
        .loop_increment.check_if_round_ended.reset_drone_id:
        mov dword [%$drone_id], 0

        dbg_print_line "Next game round: %d", [%$round]
        dbg_print_line "rounds since last elim round: %d", [%$rounds_since_last_elim_round]
        .loop_increment.round_continue:
        nop
        
        .loop_increment.printer:
        inc_round_modulo dword [%$steps_since_last_printer], dword [K]
        .loop_increment.i:
        inc dword [%$i]
        jmp .scheduler_loop
    .scheduler_loop_end:

    .winner:
        mov eax, [%$winner_id]
        inc eax
        printf_line "The Winner is drone: %d", eax
    
    .end_scheduler:
    jmp end_co
    %pop

find_drone_id_with_lowest_score: ; find_drone_with_lowest_score(): int
    func_entry 12
    %define %$drone_id_with_min_score ebp-4
    %define %$min_score ebp-8
    %define %$i ebp-12

    ; i = 0
    mov dword [%$i], 0
    mov dword [%$drone_id_with_min_score], -1

    .find_first_active_drone_loop:
    ; if (i == N) break;
    mov eax, dword [N]
    cmp dword [%$i], eax
    je .find_first_active_drone_loop_end

    ; eax = DronesArr[i] (drone)
    ; if (!drone->is_active) continue;
    mov eax, dword [DronesArr]
    mov ebx, dword [%$i]
    mov eax, dword [eax+4*ebx]
    cmp dword [drone_is_active(eax)], FALSE
    je .find_first_active_drone_loop_continue

    ; drone_id_with_min_score = i
    mem_mov dword [%$drone_id_with_min_score], dword [%$i], ebx
    ; min_score = drone->score
    mem_mov dword [%$min_score], [drone_score(eax)], ebx
    ; break
    jmp .find_first_active_drone_loop_end

    .find_first_active_drone_loop_continue:
    inc dword [%$i]
    jmp .find_first_active_drone_loop
    .find_first_active_drone_loop_end:
    nop

    .drone_arr_loop:
    ; if (i == N) break;
    mov eax, dword [N]
    cmp dword [%$i], eax
    je .drone_arr_loop_end

    ; if (!DronesArr[i]->is_active) continue;
    mov eax, dword [DronesArr]
    mov ebx, dword [%$i]
    mov eax, dword [eax+4*ebx]
    cmp dword [drone_is_active(eax)], FALSE
    je .drone_arr_loop_continue
    
    .check_min_score:
    ; if (min_score < DronesArr[i]->score) set new min vars
    mov ebx, dword [drone_score(eax)]
    cmp dword [%$min_score], ebx
    jge .drone_arr_loop_continue

    .new_min:
    ; min_score = DronesArr[i]->score
    mov dword [%$min_score], ebx
    ; drone_id_with_min_score = i
    mem_mov dword [%$drone_id_with_min_score], dword [%$i], ebx

    .drone_arr_loop_continue:
    inc dword [%$i]
    jmp .drone_arr_loop
    .drone_arr_loop_end:

    .exit:
    func_exit [%$drone_id_with_min_score]

; if only 1 drone is left active, returns it's id. otherwise returns a negative number.
find_last_active_drone_id: ; find_last_active_drone_id(): int
    func_entry 12
    %define %$last_drone_id ebp-4
    %define %$i ebp-12

    ; i = 0
    mov dword [%$i], 0
    ; found_active = -1
    mov dword [%$last_drone_id], -1

    .drone_arr_loop:
    ; if (i == N) break;
    mov eax, dword [N]
    cmp dword [%$i], eax
    je .drone_arr_loop_end

    ; if (!DronesArr[i]->is_active) continue;
    mov eax, dword [DronesArr]
    mov ebx, dword [%$i]
    mov eax, dword [eax+4*ebx]
    cmp dword [drone_is_active(eax)], FALSE
    je .drone_arr_loop_continue

    ; if (last_drone_id < 0)
    cmp dword [%$last_drone_id], 0
    jl .first_active_drone

    .second_active_drone:
        ; last_drone_id = -1
        mov dword [%$last_drone_id], -1
        ; break;
        jmp .drone_arr_loop_end

    .first_active_drone:
        ; last_drone_id = i
        mem_mov dword [%$last_drone_id], dword [%$i]

    .drone_arr_loop_continue:
    inc dword [%$i]
    jmp .drone_arr_loop
    .drone_arr_loop_end:

    .exit:
    func_exit [%$last_drone_id]