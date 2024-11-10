global _start

%define SYS_write 1
%define SYS_exit 60
%define STDOUT 1

section .data
greet: db "Hi, ", 0
newline: db 0xA, 0

section .text
_start:
    push greet             ; adiciona "Hi, " na stack para print
    call .print     
    pop rbp         

    push qword [rsp + 16]  ; adiciona ARG1 na stack para print
    call .print
    pop rbp

    push newline           ; adiciona newline na stack para print
    call .print
    pop rbp
.exit:                     ; label de término do programa
    mov rdi, 0
    mov rax, SYS_exit
    syscall
.print:                    ; rotina de print no STDOUT
    mov rsi, [rsp + 8]     
    mov r9, rsi
    mov rdx, 0
.calculate_size:           ; loop para calcular tamanho da string
    inc rdx
    inc r9
    cmp byte [r9], 0x00
    jz .done
    jmp .calculate_size
.done:                     ; label para finalizar a rotina print e retornar
    mov rdi, STDOUT
    mov rax, SYS_write
    syscall
    ret