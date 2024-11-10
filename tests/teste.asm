global _start

section .text
_start:
    mov rax, 1 ; syscall
    mov rdi, 1 ; arg 0
    mov rsi, [rsp + 8] ; arg 1
    mov rdx, 1 ; arg 2
.iteration:
    syscall
    inc rsi
    cmp byte [rsi], 0
    jz .done
    jmp .iteration
.done:
    mov rax, 60 ; SYS_exit
    xor rdi, rdi
    syscall