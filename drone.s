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

extern gen_rand_num_in_range
extern RandomNumber


HEADING_ANGLE_UPPER EQU 60
HEADING_ANGLE_LOWER EQU -60

SPEEND_CHANGE_UPPER EQU 10
SPEEND_CHANGE_LOWER EQU -10

DRONE_SPEED_DELTA EQU 10
DRONE_ANGLE_DELTA EQU 60

sizeof_drone EQU 40

drone_co_func:
    func_entry 4
    %define drone_ptr ebp-4

    ;get the pointer to the drone struct
    mov eax, dword [ebp+8]
    mov ebx, dword [DronesArr]
    mov ecx, sizeof_drone
    mul ecx
    add ebx, eax
    mov dword [drone_ptr], ebx


    ;generate angle
    push HEADING_ANGLE_LOWER
    push HEADING_ANGLE_UPPER
    call gen_rand_num_in_range
    fld qword [RandomNumber]
    sub esp, 8
    ;generate accelration
    push SPEEND_CHANGE_LOWER
    push SPEEND_CHANGE_UPPER
    call gen_rand_num_in_range
    fld qword [RandomNumber]
    sub esp, 8
set_direction:

    fld	qword [drone_angle(drone_ptr)]
	fldpi                  ; Convert heading into radians
	fmulp                  ; multiply by pi
	fld	dword [one_eighty]
	fdivp	                ; and divide by 180.0

    fsincos                 ; Compute vectors in y and x 	
    fld	qword [drone_speed(drone_ptr)]
	fmulp                   ; Multiply by distance to get dy 	
    fld	qword [drone_y(drone_ptr)]
	faddp
	fstp qword [drone_y(drone_ptr)]
	fld	qword [drone_speed(drone_ptr)]
	fmulp;                  ; Multiply by distance to get dx
	fld	qword [drone_x(drone_ptr)]
	faddp			    	
    fstp qword [drone_x(drone_ptr)]

    ;set the current speed s = s + accelatertion
    fld	qword [drone_speed(drone_ptr)]
    faddp 
    fstp qword [drone_speed(drone_ptr)]
    ;check bounds
    fld dword [DroneMaxSpeed]
    fld	qword [drone_speed(drone_ptr)]
    fcomi st1
    ;TODO check this two pops
    fdecstp
    fdecstp
    jl .cont_in_100
    ;set drone speed to 100
    fld dword [DroneMaxSpeed]
    fstp qword [drone_speed(drone_ptr)]
.cont_in_100:
    fld dword [DroneMaxSpeed]
    fld	qword [drone_speed(drone_ptr)]
    fcomi st1
    fdecstp
    fdecstp
    jg .cont_set_angle
    fldz
    fstp qword [drone_speed(drone_ptr)]
.cont_set_angle:
    func_exit