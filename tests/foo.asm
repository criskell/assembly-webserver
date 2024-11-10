; nasm -w+all -w+error -w-reloc-abs-dword -f elf64 tests/foo.asm -o out/foo.o && gcc out/foo.o -g -o out/foo -no-pie && ./out/foo criskell

global main

%define SYS_write 1
%define SYS_exit 60
%define STDOUT 1

section .data
greet: db "Hi, ", 0
newline: db 0xA, 0

section .text
main:
    push rbp ; definimos rbp como âncora para a nova base da nossa pilha
    mov rbp, rsp ; criamos um novo stack frame

    push greet             ; adiciona "Hi, " na stack para print
    call .print     
    pop rax

    push qword [rsi + 8]
    call .print
    pop rax

    push newline           ; adiciona newline na stack para print
    call .print
    pop rax

    pop rbp
    xor eax, eax
    ret
.print:                    ; rotina de print no STDOUT
    push rbp
    mov rbp, rsp
    push rsi
    
    mov rsi, [rbp + 16]     
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

    pop rsi
    pop rbp
    ret