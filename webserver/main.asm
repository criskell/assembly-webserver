global _start

%define SYS_write 1
%define SYS_exit 60
%define EXIT_SUCCESSFUL_STATUS 0
%define STDOUT 1
%define NEWLINE 0xA
%define NUL 0

section .data
    greeting: db "Hi, ", NUL
    newline: db NEWLINE, NUL

section .text
_start:
    push rbp
    mov rbp, rsp

    push greeting
    call .print
    pop rbp

    ; ARG1 = rsp + 16
    push qword [rsp + 16]
    call .print
    pop rbp

    push newline
    call .print

    pop rbp
    ret

.exit:
    mov rax, SYS_exit
    mov rdi, EXIT_SUCCESSFUL_STATUS
    syscall

.print:
    push rbp
    mov rbp, rsp

    mov rsi, [rbp + 16] ; Last value
    mov r9, rsi
    mov rdx, 0
.calculate_size:
    inc rdx
    inc r9
    cmp byte [r9], NUL
    jz .done
    jmp .calculate_size
.done:
    mov rdi, STDOUT
    mov rax, SYS_write
    syscall
    
    pop rbp
    ret