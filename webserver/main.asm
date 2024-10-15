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

.exit:
    mov rax, SYS_exit
    mov rdi, EXIT_SUCCESSFUL_STATUS
    syscall

.print:
    mov rsi, [rsp + 8] ; Last value
    mov rdx, 0
    mov r9, rsi
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
    ret