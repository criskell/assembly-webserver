global _start

%define SYS_socket 41
%define SYS_listen 50
%define SYS_accept4 288
%define SYS_bind 49

%define SYS_write 1
%define SYS_close 3
%define SYS_exit 60

%define SYS_nanosleep 35
%define SYS_fork 57
%define SYS_clone 56
%define SYS_brk 12
%define SYS_futex 202
%define SYS_mmap 9

%define FUTEX_WAIT 0
%define FUTEX_WAKE 1
%define FUTEX_PRIVATE_FLAG 128

%define PROT_WRITE 0x2
%define PROT_READ 0x1
%define MAP_GROWSDOWN 0x100
%define MAP_ANONYMOUS 0x0020
%define MAP_PRIVATE 0x0002
%define CHILD_STACK_SIZE (4096 * 1024)
%define CLONE_VM 0x00000100
%define CLONE_FS 0x00000200
%define CLONE_FILES 0x00000400
%define CLONE_PARENT 0x00008000
%define CLONE_THREAD 0x00010000
%define CLONE_IO 0x80000000
%define CLONE_SIGHAND 0x00000800

%define AF_INET 2
%define SOCK_STREAM 1
%define SOCK_PROTOCOL 0

%define EXIT_SUCCESSFUL_STATUS 0
%define STDOUT 1

%define NUL 0
%define CR 0xD
%define LF 0xA

%define BACKLOG 10000000
%define CAPACITY 5

; This section stores uninitialized data.
; It does not take up space in the program size.
; Use cases
;  - Global or static variables.
;  - Large buffers or arrays.
; It is different from the .data section as it is initialized with some explicit value.
; Zero-filled.
section .bss
socket_file_descriptor: resb 8
queue: resd 1

section .data
queuePtr: dd 0
queueCapacity: db CAPACITY * 4

socket_address:
    ; Define Word, 2 bytes - Address family.
    family: dw AF_INET

    ; Define Word, 2 bytes - Address port (IPV4).
    ; The interpretation of this number will be done in big endian order, that is, the byte that was the least significant is last.
    port: dw 0xB80B ; 3000
    
    ; Define Double word, 4 bytes - IP address.
    ip_address: dd 0

    ; Define Quad word, 8 bytes - Struct padding.
    sin_zero: dq 0

http_response:
    headline: db "HTTP/1.1 200 OK", CR, LF
    content_type: db "Content-Type: text/html", CR, LF
    content_length: db "Content-Length: 22", CR, LF
    clrf: db CR, LF
    body: db "<h1>Hello, World!</h1>"

sleep_timespec:
    tv_sec: dq 1
    tv_nsec: dq 0

; $ -> current address, that is, the memory location where the code is currently located.
; calculate the difference
; results in the size of the sequence of bytes between these two points.
; equ -> used to create symbolic values. for example:
;   max_value equ 255 ; whenever we use this name, the assembler replaces it with the name 255
http_response_length: equ $ - http_response

; The difference between equ and define is that define is defined before assembling the code (pre-processing step) and equ is defined during assembling the code.
; %define does not have access to dynamic address calculation.

align 4
condvar: dd 0

section .text

_start:

.initialize_queue:
	mov rdi, 0
	mov rax, SYS_brk
	syscall
	mov [queue], rax

	mov rdi, rax
	add rdi, CAPACITY * 4
	mov rax, SYS_brk
	syscall

.initialize_thread_pool:
    mov r8, 0
.thread_pool:
    call make_thread
    inc r8
    cmp r8, 5
    je .socket
    jmp .thread_pool

; Creates a socket, an operating system abstraction for inter-process communication.
; int socket(int domain, int type, int protocol)
.socket:
    ; Syscall number.
    mov rax, SYS_socket
    ; Domain of communication.
    ; Defines how the operating system will represent addresses.
    ; AF_INET -> IPV4.
    ; AF_INET6 -> IPV6.
    mov rdi, AF_INET
    ; Type of communication.
    ; SOCK_STREAM: Sequential, duplex, connection based, reliable.
    ; Determines how it sends and receives data.
    mov rsi, SOCK_STREAM
    ; The protocol.
    ; 0 for using the default protocol for combination of domain and type.
    ; AF_INET and SOCK_STREAM have TCP as default protocol.
    mov rdx, SOCK_PROTOCOL
    syscall
    mov [socket_file_descriptor], rax

; int bind(int socketfd, const struct sockaddr* addr, socklen_t addrlen)
.bind:
    mov rax, SYS_bind
    mov rdi, [socket_file_descriptor]
    mov rsi, socket_address
    mov rdx, 16 ; Address length. 16 bytes.
    syscall

; int listen(int sockfd, int backlog)
.listen:
    mov rax, SYS_listen
    mov rdi, [socket_file_descriptor]
    ; Maximum number of connections that can be queued before being passed to accept.
    mov rsi, BACKLOG
    syscall

; int accept(int sockfd, struct* addr, int addrlen, int flags)
.accept:
    mov rax, SYS_accept4
    mov rdi, [socket_file_descriptor]
    mov rsi, 0
    mov rdx, 0
    mov r10, 0
    syscall

    mov r8, rax
    call enqueue

    jmp .accept

emit_signal:
    mov rax, SYS_futex
    
    mov rdi, condvar
    mov rsi, FUTEX_WAKE | FUTEX_PRIVATE_FLAG

    xor rdx, rdx
    xor r10, r10
    xor r8, r8
    xor r9, r9

    syscall
    ret

make_thread:
    mov rax, SYS_mmap
    mov rdi, 0x0
    mov rsi, CHILD_STACK_SIZE
    mov rdx, PROT_WRITE | PROT_READ
    mov r10, MAP_ANONYMOUS | MAP_PRIVATE | MAP_GROWSDOWN
    syscall

    mov rdi, CLONE_VM|CLONE_FS|CLONE_FILES|CLONE_SIGHAND|CLONE_PARENT|CLONE_THREAD|CLONE_IO
    lea rsi, [rax + CHILD_STACK_SIZE - 8]
    mov qword [rsi], handle
    mov rax, SYS_clone
    syscall
    ret

handle:
.next_socket_descriptor:
    cmp dword [queuePtr], 0
    je .wait ; empty queue

    call dequeue
    mov r10, rax
    call action
    jmp handle

.wait:
    call wait_condvar
    jmp handle

action:
.sleep:
    lea rdi, [sleep_timespec]
    mov rax, SYS_nanosleep
    syscall

; int write(int fd, buffer* bf, int bfLen)
.write:
    mov rax, SYS_write
    mov rdi, r10 ; client socket file descriptor
    mov rsi, http_response
    mov rdx, http_response_length
    syscall

; int close(int fd)
.close:
    mov rdi, r10
    mov rax, SYS_close
    syscall

.return:
    jmp handle

wait_condvar:
    mov rax, SYS_futex

    mov rdi, condvar
    mov rsi, FUTEX_WAIT | FUTEX_PRIVATE_FLAG
    
    xor rdx, rdx
    xor r10, r10
    xor r8, r8
    xor r9, r9

    syscall
    test rax, rax
    jz .done_condvar

.done_condvar:
    ret

enqueue:
    mov r9, [queueCapacity]
    cmp dword [queuePtr], r9d
    je .resize_queue

    mov esi, [queuePtr]
    mov rbx, [queue]
    mov dword [rbx + rsi], r8d
    add dword [queuePtr], 4

.done_enqueue:
    call emit_signal
    ret

.resize_queue:
    mov rdi, 0
    mov rax, SYS_brk
    syscall

    mov rdi, rax
    add rdi, CAPACITY * 4
    mov rax, SYS_brk
    syscall

    mov r10, queueCapacity
    add dword [r10], CAPACITY * 4
    jmp enqueue

dequeue:
    xor rax, rax
    xor rsi, rsi

    mov rax, [queue]
    mov rax, [rax]

    mov r12d, dword [queuePtr]
    sub r12d, 4

.loop_dequeue:
    cmp dword [queuePtr], 0
    je .done_dequeue

    xor r10, r10
    mov r11, [queue]
    mov r10d, [r11 + rsi + 4]
    mov dword [r11 + rsi], r10d

    add rsi, 4
    sub dword [queuePtr], 4
    jmp .loop_dequeue

.done_dequeue:
    mov dword [queuePtr], r12d
    ret