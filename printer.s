section .rodata
f_printer: db "Printer %d", 10, 0

section .text
extern printf
extern resume
extern CoId_Scheduler

global printer_co_func

printer_co_func:
    push 1
    push dword f_printer
    call printf
    add esp, 4

    mov ebx, [CoId_Scheduler]
    call resume

    push 2
    push dword f_printer
    call printf
    add esp, 4

    mov ebx, [CoId_Scheduler]
    call resume