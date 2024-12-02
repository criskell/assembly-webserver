global _start

%define SYS_brk 12
%define SYS_exit 60

%define EXIT_SUCCESS 0

%define CAPACITY 3

section .bss
queue: resd 1

section .data
queuePtr: dd 0
queueSize: db CAPACITY * 4

section .text
_start:
	mov rdi, 0
	mov rax, SYS_brk
	syscall
	mov [queue], rax

	mov rdi, rax
	add rdi, CAPACITY * 4
	mov rax, SYS_brk
	syscall

	mov rbx, [queue]

	mov r8, 1
	call enqueue

	mov r8, 2
	call enqueue

	mov r8, 3
	call enqueue

	mov r8, 4
	call enqueue

	mov r8, 5
	call enqueue

	mov r8, 6
	call enqueue

	mov r8, 7
	call enqueue

    call dequeue

    mov r8, 8
    call enqueue

.exit:
    mov rax, SYS_exit
    mov rdi, EXIT_SUCCESS
    syscall

enqueue:
    mov r9, [queueSize]
    cmp dword [queuePtr], r9d
    je .resize_queue

    mov esi, [queuePtr]
    mov dword [rbx + rsi], r8d
    add dword [queuePtr], 4

.done_enqueue:
    ret

.resize_queue:
    mov rdi, 0
    mov rax, SYS_brk
    syscall

    mov rdi, rax
    add rdi, CAPACITY * 4
    mov rax, SYS_brk
    syscall

    mov r10, queueSize
    add dword [r10], CAPACITY * 4
    jmp enqueue

dequeue:
    xor rax, rax
    xor rsi, rsi

    mov eax, [queue]

    push qword [queuePtr]

.loop_dequeue:
    cmp esi, [queuePtr]
    je .done_dequeue ; empty queue

    cmp dword [queuePtr], 0
    je .done_dequeue

    xor r10, r10
    mov r11, [queue]
    mov r10d, [r11 + rsi + 4]
    mov [r11 + rsi], r10

    add rsi, 4
    sub dword [queuePtr], 4
    jmp .loop_dequeue

.done_dequeue:
    pop qword [queuePtr]
    sub dword [queuePtr], 4
    ret