section .rodata
f_target: db "Target %d", 10, 0

section .text
extern printf
extern resume

global target_co_func
global mayDestroy

target_co_func:
    push 1
    push dword f_target
    call printf
    add esp, 4

    mov ebx, 2
    call resume

    push 2
    push dword f_target
    call printf
    add esp, 4

    mov ebx, 2
    call resume

mayDestroy:

createTarget: