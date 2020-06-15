section .rodata
f_schd: db "Scheduler", 10, 0
FMT2:	db	"Func 2, co-id %d co %lx, call %lx, pass %ld", 10, 0

section .text
    extern CORS
    extern CURR
    extern CURR_ID
	extern CoId_Printer
	extern CoId_Target

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

	mov eax, [CORS]
	add eax, [CoId_Printer]
	push	dword 1
	push	dword eax
	push	dword [CURR]
    push    dword [ebp+4]
	push	dword FMT2
	call	printf
	add	ESP, 20

	mov	EBX, [CoId_Printer]
	call dword resume

	mov eax, [CORS]
	add eax, [CoId_Target]
	push	dword	2
	push	dword eax
	push	dword [CURR]
    push    dword [ebp+4]
	push	dword FMT2
	call	printf
	add	ESP, 20

	mov	EBX, [CoId_Target]
	call	dword resume

	mov eax, [CORS]
	add eax, [CoId_Printer]
	push	dword	3
	push	dword eax
	push	dword [CURR]
    push    dword [ebp+4]
	push	dword FMT2
	call	printf
	add	ESP, 20

	mov	EBX, [CoId_Printer]
	call	dword resume

	mov eax, [CORS]
	add eax, [CoId_Target]
	push	dword	4
	push	dword eax
	push	dword [CURR]
    push    dword [ebp+4]
	push	dword FMT2
	call	printf
	add	ESP, 20
    
	mov	EBX, [CoId_Target]
	call	dword resume

	jmp end_co