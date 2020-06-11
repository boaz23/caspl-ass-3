section .rodata
f_schd: db "Scheduler", 10, 0
FMT2:	db	"Func 2, co-id %d co %lx, call %lx, pass %ld", 10, 0

section .text
    extern CORS
    extern CURR
    extern CURR_ID

    extern resume
    extern end_co
    extern printf

    global scheduler_co_func
    
scheduler_co_func:
    mov eax, [ebp+8]
    mov [ebp+4], eax

    push dword f_schd
    call printf
    add esp, 4

	push	dword 1
	push	dword [CORS]
	push	dword [CURR]
    push    dword [ebp+4]
	push	dword FMT2
	call	printf
	add	ESP, 20

	mov	EBX, 0
	call dword resume

	push	dword	2
	push	dword [CORS+4]
	push	dword [CURR]
    push    dword [ebp+4]
	push	dword FMT2
	call	printf
	add	ESP, 20

	mov	EBX, 1
	call	dword resume

	push	dword	3
	push	dword [CORS]
	push	dword [CURR]
    push    dword [ebp+4]
	push	dword FMT2
	call	printf
	add	ESP, 20

	mov	EBX, 0
	call	dword resume

	push	dword	4
	push	dword [CORS+4]
	push	dword [CURR]
    push    dword [ebp+4]
	push	dword FMT2
	call	printf
	add	ESP, 20
    
	mov	EBX, 1
	call	dword resume

	jmp end_co