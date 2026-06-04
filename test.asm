; decmem_reboot.asm
; Decrease BIOS Data Area conventional memory size by 1 KB
; and reboot via INT 19h.

bits 16
org 100h

start:
    cli

    ; BIOS Data Area:
    ; 0040:0013 = conventional memory size in KB
    mov ax, 0040h
    mov ds, ax

    cmp word [0013h], 1
    jbe .skip_decrement
    dec word [0013h]

.skip_decrement:
    ; Optional: set warm boot flag
    ; 0040:0072 = 1234h means warm boot request
    mov word [0072h], 1234h

    sti

    ; Bootstrap loader / reboot
    int 19h

    ; If INT 19h returns for some reason, do hard reboot jump
    jmp 0FFFFh:0000h
	