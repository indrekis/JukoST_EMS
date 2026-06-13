; emstest.asm
; NASM:
;   nasm -f bin emstest.asm -o EMSTEST.COM

bits 16
cpu 8086
org 100h

EMS_PAGE_WORDS equ 2000h      ; 16 KB / 2
EMS_PAGE_BYTES equ 4000h

start:
    push cs
    pop ds
    cld

    mov dx, msg_start
    call print

; AH=40h: Get EMM status
    mov ah, 40h
    int 67h
    cmp ah, 0
    jne fail_no_ems

    mov dx, msg_ok_status
    call print

; AH=41h: Get page frame segment
    mov ah, 41h
    int 67h
    cmp ah, 0
    jne fail_frame
    mov [frame_seg], bx

    mov dx, msg_ok_frame
    call print

; AH=42h: Get unallocated page count
    mov ah, 42h
    int 67h
    cmp ah, 0
    jne fail_pages

    ; BX = free pages, DX = total pages
    cmp bx, 2
    jb fail_not_enough

    mov dx, msg_ok_pages
    call print

; AH=43h: Allocate 2 EMS pages
    mov ah, 43h
    mov bx, 2
    int 67h
    cmp ah, 0
    jne fail_alloc
    mov [handle], dx

    mov dx, msg_ok_alloc
    call print

; ES = EMS page frame segment
    mov ax, [frame_seg]
    mov es, ax

; Map logical page 0 into physical page 0
    mov ah, 44h
    mov al, 0          ; physical slot 0
    mov bx, 0          ; logical page 0
    mov dx, [handle]
    int 67h
    cmp ah, 0
    jne fail_map0

    mov dx, msg_ok_map0
    call print

; Fill physical slot 0 with 1111h
    xor di, di
    mov ax, 1111h
    call fill_16k

    mov dx, msg_ok_fill0
    call print

; Map logical page 1 into physical page 1
    mov ah, 44h
    mov al, 1          ; physical slot 1
    mov bx, 1          ; logical page 1
    mov dx, [handle]
    int 67h
    cmp ah, 0
    jne fail_map1

    mov dx, msg_ok_map1
    call print

; Fill physical slot 1 with 2222h
    mov di, EMS_PAGE_BYTES
    mov ax, 2222h
    call fill_16k

    mov dx, msg_ok_fill1
    call print

; Remap logical page 0 into physical page 2
    mov ah, 44h
    mov al, 2          ; physical slot 2
    mov bx, 0          ; logical page 0
    mov dx, [handle]
    int 67h
    cmp ah, 0
    jne fail_remap0

    mov dx, msg_ok_remap0
    call print

; Verify slot 2 contains 1111h
    mov di, EMS_PAGE_BYTES * 2
    mov ax, 1111h
    call verify_16k
    jc fail_verify0

    mov dx, msg_ok_verify0
    call print

; Remap logical page 1 into physical page 3
    mov ah, 44h
    mov al, 3          ; physical slot 3
    mov bx, 1          ; logical page 1
    mov dx, [handle]
    int 67h
    cmp ah, 0
    jne fail_remap1

    mov dx, msg_ok_remap1
    call print

; Verify slot 3 contains 2222h
    mov di, EMS_PAGE_BYTES * 3
    mov ax, 2222h
    call verify_16k
    jc fail_verify1

    mov dx, msg_ok_verify1
    call print

; Map logical page 0 into physical page 1 too.
; This tests alias/same logical page in two physical slots.
    mov ah, 44h
    mov al, 1
    mov bx, 0
    mov dx, [handle]
    int 67h
    cmp ah, 0
    jne fail_alias_map

    mov dx, msg_ok_alias_map
    call print

; Write new non-uniform pattern 3333h,3334h,... through slot 1.
    mov di, EMS_PAGE_BYTES
    mov ax, 3333h
    call fill_16k_incrementing

    mov dx, msg_ok_alias_write
    call print

; Map logical page 0 back into physical page 0.
; It should preserve the data written through the alias slot.
    mov ah, 44h
    mov al, 0
    mov bx, 0
    mov dx, [handle]
    int 67h
    cmp ah, 0
    jne fail_alias_back

    mov dx, msg_ok_alias_back
    call print

; Verify slot 0 now contains the non-uniform pattern 3333h,3334h,...
    xor di, di
    mov ax, 3333h
    call verify_16k_incrementing
    jc fail_alias_verify

    mov dx, msg_ok_alias_verify
    call print

; AH=45h: Release handle
    mov ah, 45h
    mov dx, [handle]
    int 67h
    cmp ah, 0
    jne fail_release

    mov dx, msg_ok_release
    call print

    mov dx, msg_ok
    call print
    mov ax, 4C00h
    int 21h

; ------------------------------------------------------------
; fill_16k
; IN:
;   ES:DI = destination page-frame slot
;   AX    = word pattern
; OUT:
;   none
; ------------------------------------------------------------
fill_16k:
    push cx
    push di
    mov cx, EMS_PAGE_WORDS
    rep stosw
    pop di
    pop cx
    ret

; ------------------------------------------------------------
; fill_16k_incrementing
; IN:
;   ES:DI = destination page-frame slot
;   AX    = first word pattern
; OUT:
;   none
; ------------------------------------------------------------
fill_16k_incrementing:
    push cx
    push di
    mov cx, EMS_PAGE_WORDS

.fill_loop:
    stosw
    inc ax
    loop .fill_loop

    pop di
    pop cx
    ret

; ------------------------------------------------------------
; verify_16k
; IN:
;   ES:DI = page-frame slot
;   AX    = expected word pattern
; OUT:
;   CF=0 ok
;   CF=1 mismatch
; ------------------------------------------------------------
verify_16k:
    push cx
    push di
    mov cx, EMS_PAGE_WORDS

.verify_loop:
    cmp [es:di], ax
    jne .bad
    add di, 2
    loop .verify_loop

    clc
    pop di
    pop cx
    ret

.bad:
    stc
    pop di
    pop cx
    ret

; ------------------------------------------------------------
; verify_16k_incrementing
; IN:
;   ES:DI = page-frame slot
;   AX    = first expected word pattern
; OUT:
;   CF=0 ok
;   CF=1 mismatch
; ------------------------------------------------------------
verify_16k_incrementing:
    push cx
    push di
    mov cx, EMS_PAGE_WORDS

.verify_loop:
    cmp [es:di], ax
    jne .bad
    add di, 2
    inc ax
    loop .verify_loop

    clc
    pop di
    pop cx
    ret

.bad:
    stc
    pop di
    pop cx
    ret

print:
    mov ah, 09h
    int 21h
    ret

fail_no_ems:
    mov dx, msg_no_ems
    jmp fail

fail_frame:
    mov dx, msg_frame
    jmp fail

fail_pages:
    mov dx, msg_pages
    jmp fail

fail_not_enough:
    mov dx, msg_not_enough
    jmp fail

fail_alloc:
    mov dx, msg_alloc
    jmp fail

fail_map0:
    mov dx, msg_map0
    jmp fail_release_if_needed

fail_map1:
    mov dx, msg_map1
    jmp fail_release_if_needed

fail_remap0:
    mov dx, msg_remap0
    jmp fail_release_if_needed

fail_remap1:
    mov dx, msg_remap1
    jmp fail_release_if_needed

fail_verify0:
    mov dx, msg_verify0
    jmp fail_release_if_needed

fail_verify1:
    mov dx, msg_verify1
    jmp fail_release_if_needed

fail_alias_map:
    mov dx, msg_alias_map
    jmp fail_release_if_needed

fail_alias_back:
    mov dx, msg_alias_back
    jmp fail_release_if_needed

fail_alias_verify:
    mov dx, msg_alias_verify
    jmp fail_release_if_needed

fail_release:
    mov dx, msg_release
    jmp fail

fail_release_if_needed:
    push dx
    mov dx, [handle]
    or dx, dx
    jz .skip
    mov ah, 45h
    int 67h
.skip:
    pop dx
    jmp fail

fail:
    call print
    mov ax, 4C01h
    int 21h

frame_seg dw 0
handle    dw 0

msg_start          db 'EMS test started...', 13, 10, '$'

msg_ok_status      db 'OK: EMS manager status', 13, 10, '$'
msg_ok_frame       db 'OK: page frame segment acquired', 13, 10, '$'
msg_ok_pages       db 'OK: page count acquired, at least 2 free pages', 13, 10, '$'
msg_ok_alloc       db 'OK: allocated 2 EMS pages', 13, 10, '$'
msg_ok_map0        db 'OK: mapped logical page 0 to physical slot 0', 13, 10, '$'
msg_ok_fill0       db 'OK: filled logical page 0 with 1111h', 13, 10, '$'
msg_ok_map1        db 'OK: mapped logical page 1 to physical slot 1', 13, 10, '$'
msg_ok_fill1       db 'OK: filled logical page 1 with 2222h', 13, 10, '$'
msg_ok_remap0      db 'OK: remapped logical page 0 to physical slot 2', 13, 10, '$'
msg_ok_verify0     db 'OK: verified logical page 0 data', 13, 10, '$'
msg_ok_remap1      db 'OK: remapped logical page 1 to physical slot 3', 13, 10, '$'
msg_ok_verify1     db 'OK: verified logical page 1 data', 13, 10, '$'
msg_ok_alias_map   db 'OK: mapped logical page 0 as alias in physical slot 1', 13, 10, '$'
msg_ok_alias_write db 'OK: wrote 3333h through alias slot', 13, 10, '$'
msg_ok_alias_back  db 'OK: remapped logical page 0 back to physical slot 0', 13, 10, '$'
msg_ok_alias_verify db 'OK: verified alias/writeback preservation', 13, 10, '$'
msg_ok_release     db 'OK: released EMS handle', 13, 10, '$'

msg_ok             db 'EMS test OK', 13, 10, '$'

msg_no_ems         db 'FAIL: EMS status AH=40h failed', 13, 10, '$'
msg_frame          db 'FAIL: get page frame AH=41h failed', 13, 10, '$'
msg_pages          db 'FAIL: get page count AH=42h failed', 13, 10, '$'
msg_not_enough     db 'FAIL: less than 2 free EMS pages', 13, 10, '$'
msg_alloc          db 'FAIL: allocate AH=43h failed', 13, 10, '$'
msg_map0           db 'FAIL: map logical page 0 failed', 13, 10, '$'
msg_map1           db 'FAIL: map logical page 1 failed', 13, 10, '$'
msg_remap0         db 'FAIL: remap logical page 0 failed', 13, 10, '$'
msg_remap1         db 'FAIL: remap logical page 1 failed', 13, 10, '$'
msg_verify0        db 'FAIL: logical page 0 data not preserved', 13, 10, '$'
msg_verify1        db 'FAIL: logical page 1 data not preserved', 13, 10, '$'
msg_alias_map      db 'FAIL: alias map failed', 13, 10, '$'
msg_alias_back     db 'FAIL: alias remap failed', 13, 10, '$'
msg_alias_verify   db 'FAIL: alias/writeback data not preserved', 13, 10, '$'
msg_release        db 'FAIL: release handle failed', 13, 10, '$'
