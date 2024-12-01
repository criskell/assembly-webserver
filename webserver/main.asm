global _start

%define SYS_socket 41
%define SYS_listen 50
%define SYS_accept 288
%define SYS_bind 49

%define SYS_write 1
%define SYS_close 3
%define SYS_exit 60

%define SYS_nanosleep 35

%define AF_INET 2
%define SOCK_STREAM 1
%define SOCK_PROTOCOL 0

%define EXIT_SUCCESSFUL_STATUS 0
%define STDOUT 1

%define NUL 0
%define CR 0xD
%define LF 0xA

%define CONNECTIONS_BACKLOG 2

; This section stores uninitialized data.
; It does not take up space in the program size.
; Use cases
;  - Global or static variables.
;  - Large buffers or arrays.
; It is different from the .data section as it is initialized with some explicit value.
; Zero-filled.
section .bss
socket_file_descriptor: resb 1

section .data
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

section .text
_start:

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
    mov rsi, CONNECTIONS_BACKLOG
    syscall

; int accept(int sockfd, struct* addr, int addrlen, int flags)
.accept:
    mov rax, SYS_accept
    mov rdi, [socket_file_descriptor]
    mov rsi, 0
    mov rdx, 0
    mov r10, 0
    syscall

    mov r8, rax
    call .write
    call .close
    jmp .accept

handle:
    lea rdi, [sleep_timespec]
    mov rax, SYS_nanosleep
    syscall

; int write(int fd, buffer* bf, int bfLen)
.write:
    mov rax, SYS_write
    mov rdi, r8 ; client socket file descriptor
    mov rsi, http_response
    mov rdx, http_response_length
    syscall
    ret

; int close(int fd)
.close:
    mov rdi, r8
    mov rax, SYS_close
    syscall
    ret

.exit:
    mov rax, SYS_exit
    mov rdi, EXIT_SUCCESSFUL_STATUS
    syscall