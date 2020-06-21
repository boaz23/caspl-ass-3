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


%define drone_x(d) d+0
%define drone_y(d) d+8
%define drone_speed(d) d+16
%define drone_angle(d) d+24
%define drone_score(d) d+32
%define drone_is_active(d) d+36

section .data
one_eighty:	dd 	180.0

section .text
global drone_co_func

extern DronesArr
extern DroneMaxSpeed
extern MaxAngle

extern BoardHeight
extern BoardWidth

extern gen_rand_num_in_range
extern RandomNumber

extern resume
extern CoId_Scheduler
extern CoId_Target
extern CurrentDroneId

extern mayDestroy

extern DebugMode
extern CURR_ID

extern printf
extern fprintf
extern sscanf

extern stdin
extern stdout
extern stderr

extern malloc
extern calloc
extern free

extern FloatPrintFormat
extern FloatPrintFormat_NewLine

HEADING_ANGLE_UPPER EQU 60
HEADING_ANGLE_LOWER EQU -60

SPEEND_CHANGE_UPPER EQU 10
SPEEND_CHANGE_LOWER EQU -10

DRONE_SPEED_DELTA EQU 10
DRONE_ANGLE_DELTA EQU 60

sizeof_drone EQU 40

; drone macros

%macro drone_add 2 ;ptr_to_data, upper_limit

    ;set the current speed s = s + accelatertion
    fld	qword [%1]
    faddp 
    fstp qword [%1]
    ;check bounds
%%check_greater_than_top:
    fild dword [%2]
    fld	qword [%1]
    ; if(DroneMaxSpeed < drone_speed)
    fcomip st1
    fstp st0
    jc %%cont_smaller_than_top
    ;set drone speed to 100
    fild dword [%2]
    fstp qword [%1]
    jmp %%in_bounds
%%cont_smaller_than_top:
    fld	qword [%1]
    fldz
    ; if(drone_speed < 0)
    fcomip st1
    fstp st0
    jc %%in_bounds
    fldz
    fstp qword [%1]
%%in_bounds:

%endmacro

; ptr_to_to_axis, board_axis_size
%macro compute_new_location_one_axis 2
    ; compute the new location of drone_y
    fild dword [%2]       ;st1
    fld qword [%1]       ;st0
    fprem                 ;st0 = st0 % st1
    fldz
    ; if( st0 % st1 < 0)
    fcomip st1
    jc %%val_begger_then_0
    fild dword [%2]
    faddp
%%val_begger_then_0:
    fstp qword [%1]
    fstp st0
%endmacro

update_drone_game_data:

    %define $drone_ptr_update ebp+8
    
    push ebp
    mov ebp, esp
    pushfd
    pushad

       dbg_print_line "Drone data when resume"
       dbg_print_line "Drone id: %d", [CURR_ID]
       dbg_print_line "-----"
       mov eax, dword [$drone_ptr_update]
       dbg_print_double "x: ", drone_x(eax)
       mov eax, dword [$drone_ptr_update]
       dbg_print_double "y: ", drone_y(eax)
       mov eax, dword [$drone_ptr_update]
       dbg_print_double "speed: ", drone_speed(eax)
       mov eax, dword [$drone_ptr_update]
       dbg_print_double "angle: ", drone_angle(eax)
       mov eax, dword [$drone_ptr_update]
       dbg_print_line "score: %d", [drone_score(eax)]
       mov eax, dword [$drone_ptr_update]
       dbg_print_line "is_active: %d", [drone_is_active(eax)]
       dbg_print_line "-----"
    

    ;generate angle
    push HEADING_ANGLE_LOWER
    push HEADING_ANGLE_UPPER
    call gen_rand_num_in_range
    fld qword [RandomNumber]
    add esp, 8

    ;generate accelration
    push SPEEND_CHANGE_LOWER
    push SPEEND_CHANGE_UPPER
    call gen_rand_num_in_range
    fld qword [RandomNumber]
    add esp, 8
.set_direction:
    
    mov eax, dword [$drone_ptr_update]
    fld	qword [drone_angle(eax)]
	fldpi                  ; Convert heading into radians
	fmulp                  ; multiply by pi
	fld	dword [one_eighty]
	fdivp	                ; and divide by 180.0

    mov ebx, dword [$drone_ptr_update]	
    fsincos                 ; Compute vectors in y and x 
    fld	qword [drone_speed(ebx)]
	fmulp                   ; Multiply by distance to get dy
    fld	qword [drone_y(ebx)]
	faddp
	fstp qword [drone_y(ebx)]
	fld	qword [drone_speed(ebx)]
	fmulp                  ; Multiply by distance to get dx
	fld	qword [drone_x(ebx)]
	faddp   	
    fstp qword [drone_x(ebx)]

    ; compute the new location of drone_y
    compute_new_location_one_axis drone_y(ebx), BoardHeight

    ; compute the new location of drone_x
    compute_new_location_one_axis drone_x(ebx), BoardWidth

    drone_add drone_speed(ebx), DroneMaxSpeed
    drone_add drone_angle(ebx), MaxAngle

       dbg_print_line "Drone data end of update"
       dbg_print_line "Drone id: %d", [CURR_ID]
       dbg_print_line "-----"
       mov eax, dword [$drone_ptr_update]
       dbg_print_double "x: ", drone_x(eax)
       mov eax, dword [$drone_ptr_update]
       dbg_print_double "y: ", drone_y(eax)
       mov eax, dword [$drone_ptr_update]
       dbg_print_double "speed: ", drone_speed(eax)
       mov eax, dword [$drone_ptr_update]
       dbg_print_double "angle: ", drone_angle(eax)
       mov eax, dword [$drone_ptr_update]
       dbg_print_line "score: %d", [drone_score(eax)]
       mov eax, dword [$drone_ptr_update]
       dbg_print_line "is_active: %d", [drone_is_active(eax)]
       dbg_print_line "-----"

    popad
    popfd
    pop ebp
    ret

drone_co_func:
    func_entry 4
    %define $drone_ptr ebp-4

    ;get the pointer to the drone struct
    mov eax, [CurrentDroneId]
    mov ebx, dword [DronesArr]
    mov ebx, [ebx + 4*eax]
    mov dword [$drone_ptr], ebx
    dbg_print_line "%x", dword ebx

    ;push dword [$drone_ptr]
    ;call update_drone_game_data
    ;add esp, 4

.drone_loop_start:
    nop
    .drone_loop.update_drone_data:
        push dword [$drone_ptr]
        call update_drone_game_data
        add esp, 4

    .check_destroy_target:
        func_call eax, mayDestroy
        cmp eax, FALSE
        je .no_destroy
        .destroy_target:
            ;TODO destory the targer
            mov ebx, [CoId_Target]
            call resume
        .no_destroy:
            nop

    .resume_scheduler:
    mov ebx, [CoId_Scheduler]
    call resume

    jmp .drone_loop_start
.drone_loop_end:

    func_exit
