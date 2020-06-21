section .rodata
f_target: db "Target %d", 10, 0

section .text
extern printf
extern resume
extern CoId_Scheduler

extern TargetPosition

extern BoardHeight
extern BoardWidth

extern gen_rand_num_in_range

global target_co_func
global mayDestroy

target_co_func:
    push 1
    push dword f_target
    call printf
    add esp, 4

    mov ebx, [CoId_Scheduler]
    call resume

    push 2
    push dword f_target
    call printf
    add esp, 4

    mov ebx, [CoId_Scheduler]
    call resume

mayDestroy:

createTarget:
    push ebp
    mov ebp, esp
    pushf
    pusha

    ;generate x position
    push 0
    push BoardWidth
    call gen_rand_num_in_range
    fld qword [RandomNumber]
    fstp qword [TargetPosition]
    add esp, 8

    ;generate y position
    push 0
    push BoardHeight
    call gen_rand_num_in_range
    fld qword [RandomNumber]
    fstp qword [TargetPosition+8]
    add esp, 8

    popa
    popf
    pop ebp
    ret