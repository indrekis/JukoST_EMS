; decmem_reboot.asm
; Decrease BIOS Data Area conventional memory size by 1 KB
; and reboot via INT 19h.

bits 16
org 100h

start:
    cli

    ; BIOS Data Area:
    ; 0040:0013 = conventional memory size in KB
    xor ax, ax
    mov ds, ax

    dec word [ds:00413h]

    sti

    ; Bootstrap loader / reboot
	mov word [0472h], 1234h
	jmp 0FFFFh:0000h
    int 19h

    ; If INT 19h returns for some reason, do hard reboot jump
    jmp 0FFFFh:0000h
	