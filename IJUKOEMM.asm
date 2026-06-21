; Based on the disassembly by the Interactive Disassembler (IDA) 2010 Freeware version 

bits 16
cpu 8086
org 0

NextDevice_0	dw 0FFFFh		; The last device
				dw 0FFFFh
DevAttr_0		dw 0C000h		; supports IOCTL
								; character device
Strategy_0		dw Strategy_Routine_0
Interrupt_0		dw Interrupt_Routine_0
DeviceName_0	db 'EMMXXXX0      '    
ReqBlock_Seg	dw 0			
ReqBlock_Off	dw 0			

; See list:	https://www.lo-tech.co.uk/wiki/LIM_Expanded_Memory_Specification_V4:_Appendix_A					
; Looks like will crash on 0x4F fn.	It is not defined in the 3.2 version
EMS_funcs_table:	
		dw EMS_fn00
		dw EMS_fn01
		dw EMS_fn02
		dw EMS_fn03
		dw EMS_fn04
		dw EMS_fn05
		dw EMS_fn06
		dw EMS_fn07
		dw EMS_fn08
		dw EMS_fn09_fn0A
		dw EMS_fn09_fn0A
		dw EMS_fn0B
		dw EMS_fn0C
		dw EMS_fn0D
		dw EMS_fn0E
		dw exit_int67_handler_err
		
EMS_logic_pages_tbl dw 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh; 0
		dw 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh; 9 ;
		dw 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh; 18 ;
		dw 0FFh			; 27 ; Descriptor:
					; +0: logical_page_number within handle, or FFh if the page is free
					; +1: handle id
					; 4+24 = 28 records: 4 physical	slots +	16*24 =	384 Kb backing memory
					;
handler_context_flags times 24 db 0		
handler_page_maps times 192 db 0	
EMS_slots_state	 times 4 db 0
					; Synchronization groups for aliases:
					; 0 - no alias conflict
					; 1 - belongs to synchronization group 1
					; 2 - belongs to synchronization group 2
CRC_group1	dw 0			
					
CRC_group2	dw 0	
					
old_int21_offs	dd 0
					
do_call_orig_int21 db 0
temp_phys_EMS_slot dw 0		

; Reboot detection modes used during driver initialization.
; Add new modes by assigning a new DETECT_* value and extending
; is_upper64_reserved / write_reboot_detection_marker.
DETECT_BANKED_MARKER equ 0    ; marker in Juko banked memory, requires ENABLE_TRANS
DETECT_PLAIN_MARKER  equ 1    ; marker in normal memory, no bank switch
DETECT_BDA_SIZE      equ 2    ; no marker; use BIOS Data Area memory size [0:413]
DETECT_86BOX_E0_BIT  equ 3    ; 86Box-only: reboot marker in bit 7 of port E0h
DETECT_MODE_MAX      equ 3

REBOOT_MARKER        equ 6996h
REBOOT_MARKER_SEG    equ 7000h
REBOOT_MARKER_OFF    equ 0000h

JUKO_E0_PORT         equ 0E0h
JUKO_E0_TRANS_BIT    equ 01h
JUKO_E0_REBOOT_BIT   equ 80h

mem_dispos_kb      dw 0
detect_mode        db DETECT_BDA_SIZE
detect_mode_pad    db 0
ems_frame_base_seg dw 9000h
	
segs_for_EMS_frames dw 9000h, 9400h, 9800h, 9C00h
					dw 2000h, 2400h, 2800h, 2C00h
					dw 3000h, 3400h, 3800h, 3C00h
					dw 4000h, 4400h, 4800h, 4C00h
					dw 5000h, 5400h, 5800h, 5C00h
					dw 6000h, 6400h, 6800h, 6C00h
					dw 7000h, 7400h, 7800h, 7C00h
	
; %define B8000_DEBUG_TRACE 1
; %define A86BOX_ISABUGGER_TRACE 1

%ifdef B8000_DEBUG_TRACE

; ------------------------------------------------------------
; Direct screen debug output for text/CGA/VGA mode 13h.
;
; This is deliberately BIOS-free, because DBG_MARK is used from
; INT 67h / INT 21h related paths where INT 10h is unsafe.
; ------------------------------------------------------------

dbg_pos db 0
dbg_video_mode db 0

; Expand one 4-bit monochrome nibble into one CGA 320x200 byte:
; bit set -> pixel color 3, bit clear -> pixel color 0.
; Input nibble order: bit 3 is the leftmost pixel.
dbg_cga2_expand:
        db 00000000b, 00000011b, 00001100b, 00001111b
        db 00110000b, 00110011b, 00111100b, 00111111b
        db 11000000b, 11000011b, 11001100b, 11001111b
        db 11110000b, 11110011b, 11111100b, 11111111b

; 8x8 debug font, one byte per scanline, bit 7 is the leftmost pixel.
; Glyph set: '0'..'9', 'A'..'Z'. Unknown characters use '?'.
dbg_font_digits:
        db 3Ch,66h,6Eh,76h,66h,66h,3Ch,00h ; 0
        db 18h,38h,18h,18h,18h,18h,7Eh,00h ; 1
        db 3Ch,66h,06h,0Ch,18h,30h,7Eh,00h ; 2
        db 3Ch,66h,06h,1Ch,06h,66h,3Ch,00h ; 3
        db 0Ch,1Ch,3Ch,6Ch,7Eh,0Ch,0Ch,00h ; 4
        db 7Eh,60h,7Ch,06h,06h,66h,3Ch,00h ; 5
        db 1Ch,30h,60h,7Ch,66h,66h,3Ch,00h ; 6
        db 7Eh,66h,06h,0Ch,18h,18h,18h,00h ; 7
        db 3Ch,66h,66h,3Ch,66h,66h,3Ch,00h ; 8
        db 3Ch,66h,66h,3Eh,06h,0Ch,38h,00h ; 9

dbg_font_letters:
        db 18h,3Ch,66h,66h,7Eh,66h,66h,00h ; A
        db 7Ch,66h,66h,7Ch,66h,66h,7Ch,00h ; B
        db 3Ch,66h,60h,60h,60h,66h,3Ch,00h ; C
        db 78h,6Ch,66h,66h,66h,6Ch,78h,00h ; D
        db 7Eh,60h,60h,7Ch,60h,60h,7Eh,00h ; E
        db 7Eh,60h,60h,7Ch,60h,60h,60h,00h ; F
        db 3Ch,66h,60h,6Eh,66h,66h,3Ch,00h ; G
        db 66h,66h,66h,7Eh,66h,66h,66h,00h ; H
        db 7Eh,18h,18h,18h,18h,18h,7Eh,00h ; I
        db 1Eh,0Ch,0Ch,0Ch,0Ch,6Ch,38h,00h ; J
        db 66h,6Ch,78h,70h,78h,6Ch,66h,00h ; K
        db 60h,60h,60h,60h,60h,60h,7Eh,00h ; L
        db 63h,77h,7Fh,6Bh,63h,63h,63h,00h ; M
        db 66h,76h,7Eh,7Eh,6Eh,66h,66h,00h ; N
        db 3Ch,66h,66h,66h,66h,66h,3Ch,00h ; O
        db 7Ch,66h,66h,7Ch,60h,60h,60h,00h ; P
        db 3Ch,66h,66h,66h,6Eh,6Ch,36h,00h ; Q
        db 7Ch,66h,66h,7Ch,78h,6Ch,66h,00h ; R
        db 3Ch,66h,60h,3Ch,06h,66h,3Ch,00h ; S
        db 7Eh,18h,18h,18h,18h,18h,18h,00h ; T
        db 66h,66h,66h,66h,66h,66h,3Ch,00h ; U
        db 66h,66h,66h,66h,66h,3Ch,18h,00h ; V
        db 63h,63h,63h,6Bh,7Fh,77h,63h,00h ; W
        db 66h,66h,3Ch,18h,3Ch,66h,66h,00h ; X
        db 66h,66h,66h,3Ch,18h,18h,18h,00h ; Y
        db 7Eh,06h,0Ch,18h,30h,60h,7Eh,00h ; Z

dbg_font_unknown:
        db 3Ch,66h,06h,0Ch,18h,00h,18h,00h ; ?

dbg_font_cursor:
        db 7Eh,42h,42h,42h,42h,42h,7Eh,00h ; hollow cursor rectangle

; Extra punctuation used by register debug output.
dbg_font_equal:
        db 00h,00h,7Eh,00h,7Eh,00h,00h,00h ; =
dbg_font_colon:
        db 00h,18h,18h,00h,00h,18h,18h,00h ; :
dbg_font_dash:
        db 00h,00h,00h,7Eh,00h,00h,00h,00h ; -
dbg_font_space:
        db 00h,00h,00h,00h,00h,00h,00h,00h ; space

; ------------------------------------------------------------
; dbg_get_glyph
;
; Input:
;   DL = ASCII marker
;   DS = CS
;
; Output:
;   SI = glyph offset in CS
;
; Destroys:
;   AX
; ------------------------------------------------------------

dbg_get_glyph:
        mov     al, dl

        ; uppercase ASCII a..z
        cmp     al, 'a'
        jb      .not_lower
        cmp     al, 'z'
        ja      .not_lower
        and     al, 0DFh
        mov     dl, al

.not_lower:
        cmp     al, '='
        je      .equal
        cmp     al, ':'
        je      .colon
        cmp     al, '-'
        je      .dash
        cmp     al, ' '
        je      .space

        cmp     al, '0'
        jb      .try_letter
        cmp     al, '9'
        ja      .try_letter
        sub     al, '0'
        xor     ah, ah
        shl     ax, 1
        shl     ax, 1
        shl     ax, 1              ; AX = index * 8
        mov     si, dbg_font_digits
        add     si, ax
        retn

.try_letter:
        cmp     al, 'A'
        jb      .unknown
        cmp     al, 'Z'
        ja      .unknown
        sub     al, 'A'
        xor     ah, ah
        shl     ax, 1
        shl     ax, 1
        shl     ax, 1              ; AX = index * 8
        mov     si, dbg_font_letters
        add     si, ax
        retn

.equal:
        mov     si, dbg_font_equal
        retn

.colon:
        mov     si, dbg_font_colon
        retn

.dash:
        mov     si, dbg_font_dash
        retn

.space:
        mov     si, dbg_font_space
        retn

.unknown:
        mov     si, dbg_font_unknown
        retn

; ------------------------------------------------------------
; dbg_draw_cga_glyph
;
; Input:
;   ES = B800h
;   SI = glyph offset in CS
;   BL = glyph position
;   [cs:dbg_video_mode] = 04h/05h/06h
;
; Destroys:
;   AX,BX,CX,DX,DI,BP,SI
; ------------------------------------------------------------

dbg_draw_cga_glyph:
        xor     bh, bh

        cmp     byte [cs:dbg_video_mode], 06h
        je      .pos_640

        ; 320x200: 8 pixels = 2 bytes, 40 glyphs fit across.
        and     bl, 1Fh             ; 0..31, conservative wrap
        shl     bx, 1
        jmp     short .have_xbyte

.pos_640:
        ; 640x200: 8 pixels = 1 byte, 80 glyphs fit across.
        and     bl, 3Fh             ; 0..63, conservative wrap

.have_xbyte:
        mov     bp, bx              ; BP = x byte offset
        xor     dx, dx              ; DL = row 0..7

.row_loop:
        ; Compute CGA offset for scanline DL:
        ; even lines: B800:0000 + (y/2)*80 + x
        ; odd  lines: B800:2000 + (y/2)*80 + x

        xor     di, di
        mov     al, dl
        xor     ah, ah
        shr     ax, 1               ; y / 2

        mov     di, ax
        mov     cl, 6
        shl     di, cl              ; *64
        mov     bx, ax
        mov     cl, 4
        shl     bx, cl              ; *16
        add     di, bx              ; *80

        test    dl, 1
        jz      .even
        add     di, 2000h

.even:
        add     di, bp

        mov     al, [cs:si]         ; glyph row bits

        cmp     byte [cs:dbg_video_mode], 06h
        jne     .row_320

        ; Mode 06h: one glyph row byte maps directly to 8 pixels.
        mov     [es:di], al
        jmp     short .next_row

.row_320:
        ; Modes 04h/05h: expand each glyph bit to a 2-bit color-3 pixel.
        mov     ah, al
        mov     bl, al
        xor     bh, bh
        shr     bl, 1
        shr     bl, 1
        shr     bl, 1
        shr     bl, 1               ; high nibble
        mov     al, [cs:dbg_cga2_expand+bx]

        mov     bl, ah
        xor     bh, bh
        and     bl, 0Fh             ; low nibble
        mov     ah, [cs:dbg_cga2_expand+bx]

        mov     [es:di], ax

.next_row:
        inc     si
        inc     dl
        cmp     dl, 8
        jb      .row_loop

        retn

; ------------------------------------------------------------
; dbg_draw_vga13_glyph
;
; Input:
;   ES = A000h
;   SI = glyph offset in CS
;   BL = glyph position
;
; Destroys:
;   AX,BX,CX,DX,DI,BP,SI
; ------------------------------------------------------------

dbg_draw_vga13_glyph:
        xor     bh, bh
        and     bl, 1Fh             ; 0..31 glyphs across

        ; x = pos * 8
        mov     cl, 3
        shl     bx, cl
        mov     bp, bx              ; BP = base x offset

        xor     dx, dx              ; DL = row 0..7

.row_loop:
        mov     di, dx
        mov     cl, 6
        shl     di, cl              ; row * 64
        mov     bx, dx
        mov     cl, 8
        shl     bx, cl              ; row * 256
        add     di, bx              ; row * 320
        add     di, bp              ; + x

        mov     ah, [cs:si]         ; AH = glyph row pattern
        mov     cx, 8

.pixel_loop:
        shl     ah, 1               ; next glyph bit -> CF
        mov     al, 00h
        jnc     .store
        mov     al, 0Fh

.store:
        stosb
        loop    .pixel_loop

        inc     si
        inc     dl
        cmp     dl, 8
        jb      .row_loop

        retn

; ------------------------------------------------------------
; dbg_hex_digit
;
; Input:
;   AL low nibble = 0..0Fh
;
; Output:
;   Emits one hexadecimal digit through dbg_mark.
;
; Destroys:
;   AL
; ------------------------------------------------------------

dbg_hex_digit:
        and     al, 0Fh
        cmp     al, 9
        jbe     .decimal
        add     al, 'A' - 10
        jmp     short .emit

.decimal:
        add     al, '0'

.emit:
        call    dbg_mark
        retn

; ------------------------------------------------------------
; dbg_hex8
;
; Input:
;   AL = byte to print as two hexadecimal digits
;
; Preserves:
;   AX,CX
; ------------------------------------------------------------

dbg_hex8:
        push    ax
        push    cx

        mov     ah, al              ; AH = original byte

        mov     al, ah
        mov     cl, 4
        shr     al, cl              ; high nibble
        call    dbg_hex_digit

        mov     al, ah
        call    dbg_hex_digit       ; low nibble

        pop     cx
        pop     ax
        retn

; ------------------------------------------------------------
; dbg_hex16
;
; Input:
;   AX = word to print as four hexadecimal digits
;
; Preserves:
;   AX,BX
; ------------------------------------------------------------

dbg_hex16:
        push    ax
        push    bx

        mov     bx, ax

        mov     al, bh
        call    dbg_hex8

        mov     al, bl
        call    dbg_hex8

        pop     bx
        pop     ax
        retn

; ------------------------------------------------------------
; dbg_mark
;
; Input:
;   AL = marker byte, usually ASCII: '0', '1', 'Z', etc.
;
; The routine writes the marker at dbg_pos, advances dbg_pos,
; then draws a cursor marker at the next position. Therefore,
; after a hang the last completed DBG_MARK is immediately before
; the cursor rectangle.
;
; Supports:
;   text modes 00h..03h, 07h  -> text memory
;   CGA graphics 04h,05h,06h  -> B800 graphics memory
;   VGA mode 13h              -> A000 linear framebuffer
;
; Does nothing in planar EGA/VGA modes 0Dh/0Eh/0Fh/10h/12h.
;
; Preserves:
;   AX,BX,CX,DX,SI,DI,DS,ES,BP
; ------------------------------------------------------------

DBG_TEXT_ROW        equ 0
DBG_TEXT_COL        equ 0
DBG_TEXT_WIDTH      equ 79       ; 79 printable positions + cursor
DBG_TEXT_ATTR       equ 1Eh
DBG_TEXT_CURSOR_ATR equ 70h	

dbg_mark:
        push    ax
        push    bx
        push    cx
        push    dx
        push    si
        push    di
        push    ds
        push    es
        push    bp

        mov     dl, al              ; DL = marker byte

        ; Read current video mode from BIOS Data Area:
        ; 0040:0049 = current video mode
        mov     ax, 0040h
        mov     ds, ax
        mov     dh, [0049h]         ; DH = current video mode
        mov     [cs:dbg_video_mode], dh

        mov     ax, cs
        mov     ds, ax
        call    dbg_get_glyph       ; SI = CS:font glyph

        cmp     byte [cs:dbg_video_mode], 03h
        jbe     .text_color

        cmp     byte [cs:dbg_video_mode], 07h
        je      .text_mono

        cmp     byte [cs:dbg_video_mode], 04h
        jb      .done
        cmp     byte [cs:dbg_video_mode], 06h
        jbe     .cga_graphics

        cmp     byte [cs:dbg_video_mode], 13h
        je      .vga_13h

        jmp     .done

; ------------------------------------------------------------
; Text modes 00h..03h: color text memory B800
; ------------------------------------------------------------

.text_color:
        mov     ax, 0B800h
        mov     es, ax
        jmp     short .text_common

; ------------------------------------------------------------
; Text mode 07h: monochrome text memory B000
; ------------------------------------------------------------

.text_mono:
        mov     ax, 0B000h
        mov     es, ax
	
		
.text_common:
        ; ES already points to B800h or B000h

        ; BX = row*160 + col*2
        xor     bx, bx
        mov     bl, [cs:dbg_pos]

        cmp     bl, DBG_TEXT_WIDTH
        jb      .text_pos_ok
        xor     bl, bl
        mov     [cs:dbg_pos], bl

.text_pos_ok:
        ; offset = row*160 + (DBG_TEXT_COL + dbg_pos)*2
        xor     bh, bh
        add     bl, DBG_TEXT_COL
        shl     bx, 1
%if DBG_TEXT_ROW != 0
        add     bx, DBG_TEXT_ROW * 160
%endif

        ; draw actual character
        mov     al, dl              ; marker char
        mov     ah, DBG_TEXT_ATTR
        mov     [es:bx], ax

        ; advance dbg_pos
        inc     byte [cs:dbg_pos]
        cmp     byte [cs:dbg_pos], DBG_TEXT_WIDTH
        jb      .text_cursor_pos_ok
        mov     byte [cs:dbg_pos], 0

.text_cursor_pos_ok:
        ; draw cursor at next write position
        xor     bx, bx
        mov     bl, [cs:dbg_pos]
        add     bl, DBG_TEXT_COL
        shl     bx, 1
%if DBG_TEXT_ROW != 0
        add     bx, DBG_TEXT_ROW * 160
%endif

        mov     al, ' '
        mov     ah, DBG_TEXT_CURSOR_ATR
        mov     [es:bx], ax

        jmp     .done

; ------------------------------------------------------------
; CGA graphics modes:
;   04h/05h = 320x200, 2 bits per pixel, B800
;   06h     = 640x200, 1 bit per pixel, B800
;
; Draws an 8x8 glyph and then a hollow cursor rectangle
; at the next write position.
; ------------------------------------------------------------

.cga_graphics:
        mov     ax, 0B800h
        mov     es, ax

        mov     bl, [cs:dbg_pos]
        call    dbg_draw_cga_glyph

        inc     byte [cs:dbg_pos]

        mov     si, dbg_font_cursor
        mov     bl, [cs:dbg_pos]
        call    dbg_draw_cga_glyph

        jmp     .done

; ------------------------------------------------------------
; VGA mode 13h:
;   320x200, 256 colors, linear framebuffer A000:0000
;
; Draws an 8x8 glyph and then a hollow cursor rectangle
; at the next write position.
; ------------------------------------------------------------

.vga_13h:
        mov     ax, 0A000h
        mov     es, ax

        mov     bl, [cs:dbg_pos]
        call    dbg_draw_vga13_glyph

        inc     byte [cs:dbg_pos]

        mov     si, dbg_font_cursor
        mov     bl, [cs:dbg_pos]
        call    dbg_draw_vga13_glyph

.done:
        pop     bp
        pop     es
        pop     ds
        pop     di
        pop     si
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        ret

%endif

%ifdef A86BOX_ISABUGGER_TRACE

; https://86box.readthedocs.io/en/latest/hardware/isabugger.html
; ------------------------------------------------------------
; 86Box ISABugger ports/registers
; ------------------------------------------------------------

ISABUG_IDX_PORT      equ 07Ah
ISABUG_DATA_PORT     equ 07Bh

ISABUG_RED_LEDS      equ 00h
ISABUG_GREEN_LEDS    equ 01h
ISABUG_RIGHT_DISP    equ 02h
ISABUG_LEFT_DISP     equ 04h
ISABUG_RESET         equ 0FFh


; ------------------------------------------------------------
; Write AL to ISABugger register imm8
; destroys: nothing
; ------------------------------------------------------------
%macro ISABUG_WRITE_REG_AL 1
        push    dx

        mov     dx, ISABUG_IDX_PORT
        out     dx, al              ; WARNING: this is wrong for an imm index
									; do not use directly
        pop     dx
%endmacro


; ------------------------------------------------------------
; Write immediate byte to ISABugger register
; preserves: AX, DX
; ------------------------------------------------------------
%macro ISABUG_WRITE_IMM 2
        push    ax
        push    dx

        mov     dx, ISABUG_IDX_PORT
        mov     al, %1
        out     dx, al

        mov     dx, ISABUG_DATA_PORT
        mov     al, %2
        out     dx, al

        pop     dx
        pop     ax
%endmacro


; ------------------------------------------------------------
; Write AL to ISABugger register imm8
; preserves: AX, DX
; value is taken from AL before macro call
; ------------------------------------------------------------
%macro ISABUG_WRITE_AL 1
        push    ax
        push    dx

        mov     ah, al              ; save value in AH

        mov     dx, ISABUG_IDX_PORT
        mov     al, %1
        out     dx, al

        mov     dx, ISABUG_DATA_PORT
        mov     al, ah
        out     dx, al

        pop     dx
        pop     ax
%endmacro

; ------------------------------------------------------------
; Clear displays and LEDs
; preserves: AX, DX
; ------------------------------------------------------------
%macro ISABUG_CLEAR 0
        push    ax
        push    dx

        mov     dx, ISABUG_IDX_PORT
        mov     al, ISABUG_RESET
        out     dx, al

        pop     dx
        pop     ax
%endmacro


; ------------------------------------------------------------
; Show 16-bit register or immediate word on hex displays
;
; left  display = high byte
; right display = low byte
;
; examples:
;   ISABUG_SHOW_WORD ax
;   ISABUG_SHOW_WORD bx
;   ISABUG_SHOW_WORD 9C00h
;
; preserves: AX, BX, DX
; ------------------------------------------------------------
%macro ISABUG_SHOW_WORD 1
        push    ax
        push    bx
        push    dx

        mov     bx, %1

        ; left display = BH
        mov     dx, ISABUG_IDX_PORT
        mov     al, ISABUG_LEFT_DISP
        out     dx, al

        mov     dx, ISABUG_DATA_PORT
        mov     al, bh
        out     dx, al

        ; right display = BL
        mov     dx, ISABUG_IDX_PORT
        mov     al, ISABUG_RIGHT_DISP
        out     dx, al

        mov     dx, ISABUG_DATA_PORT
        mov     al, bl
        out     dx, al

        pop     dx
        pop     bx
        pop     ax
%endmacro



; ------------------------------------------------------------
; Show segment register on hex displays
;
; examples:
;   ISABUG_SHOW_SEG ds
;   ISABUG_SHOW_SEG es
;   ISABUG_SHOW_SEG cs
;   ISABUG_SHOW_SEG ss
;
; preserves: AX, BX, DX
; ------------------------------------------------------------
%macro ISABUG_SHOW_SEG 1
        push    ax
        push    bx
        push    dx

        mov     bx, %1              ; NASM accepts: mov bx, ds / es / cs / ss

        ; left display = high byte of segment
        mov     dx, ISABUG_IDX_PORT
        mov     al, ISABUG_LEFT_DISP
        out     dx, al

        mov     dx, ISABUG_DATA_PORT
        mov     al, bh
        out     dx, al

        ; right display = low byte of segment
        mov     dx, ISABUG_IDX_PORT
        mov     al, ISABUG_RIGHT_DISP
        out     dx, al

        mov     dx, ISABUG_DATA_PORT
        mov     al, bl
        out     dx, al

        pop     dx
        pop     bx
        pop     ax
%endmacro


; ------------------------------------------------------------
; Show marker on LEDs
;
; red LEDs   = first byte
; green LEDs = second byte
;
; examples:
;   ISABUG_LEDS 0E5h, 00h
;   ISABUG_LEDS 'E', 'S'
;
; preserves: AX, DX
; ------------------------------------------------------------
%macro ISABUG_LEDS 2
        ISABUG_WRITE_IMM ISABUG_GREEN_LEDS, %1
        ISABUG_WRITE_IMM ISABUG_RED_LEDS,   %2
%endmacro


; ------------------------------------------------------------
; Wait approximately N BIOS timer ticks.
;
; 18.2065 ticks/sec, so:
;   3 seconds ≈ 55 ticks
;
; IMPORTANT:
; Your INT67 handler enters with CLI.
; This macro temporarily enables interrupts with STI so that
; the BIOS timer tick at 0040:006C can advance.
;
; preserves: FLAGS, AX, BX, ES
; ------------------------------------------------------------
%macro DEBUG_WAIT_TICKS 1
        pushf
        push    ax
        push    bx
        push    es

        sti                         ; needed, otherwise BIOS tick will not advance

        mov     ax, 0040h
        mov     es, ax
        mov     bx, [es:006Ch]      ; BIOS timer tick low word

%%wait_loop:
        mov     ax, [es:006Ch]
        sub     ax, bx
        cmp     ax, %1
        jb      %%wait_loop

        pop     es
        pop     bx
        pop     ax
        popf
%endmacro


; ------------------------------------------------------------
; Wait approximately 3 seconds
; ------------------------------------------------------------
%macro DEBUG_WAIT_3S 0
		nop
        ; DEBUG_WAIT_TICKS 55
%endmacro

; ------------------------------------------------------------
; Report bad ES:
;   - red LEDs   = 'E'
;   - green LEDs = 'S'
;   - displays   = ES value
;   - pause ~3 seconds
;
; preserves: FLAGS, AX, BX, DX, ES
; ------------------------------------------------------------
%macro ISABUG_REPORT_BAD_ES 0
        pushf
        push    ax
        push    bx
        push    dx

        ISABUG_LEDS 10b, 0
        ISABUG_SHOW_SEG es
        DEBUG_WAIT_3S

        pop     dx
        pop     bx
        pop     ax
        popf
%endmacro


; ------------------------------------------------------------
; Report bad DS
; ------------------------------------------------------------
%macro ISABUG_REPORT_BAD_DS 0
        pushf
        push    ax
        push    bx
        push    dx

        ISABUG_LEDS 01b, 0
        ISABUG_SHOW_SEG ds
        DEBUG_WAIT_3S

        pop     dx
        pop     bx
        pop     ax
        popf
%endmacro


; ------------------------------------------------------------
; Report bad SI or BX value as 16-bit word
; ------------------------------------------------------------
%macro ISABUG_REPORT_WORD 3
        ; %1 = red LED marker
        ; %2 = green LED marker
        ; %3 = word register/value to show
        pushf
        push    ax
        push    bx
        push    dx

        ISABUG_LEDS %1, %2
        ISABUG_SHOW_WORD %3
        DEBUG_WAIT_3S

        pop     dx
        pop     bx
        pop     ax
        popf
%endmacro

%else 

%macro ISABUG_WRITE_REG_AL 1
%endmacro

%macro ISABUG_WRITE_IMM 2
%endmacro

%macro ISABUG_WRITE_AL 1
%endmacro

%macro ISABUG_CLEAR 0
%endmacro

%macro ISABUG_SHOW_WORD 1
%endmacro

%macro ISABUG_SHOW_SEG 1
%endmacro

%macro ISABUG_LEDS 2
%endmacro

%macro DEBUG_WAIT_TICKS 1
%endmacro

%macro DEBUG_WAIT_3S 0
%endmacro

%macro ISABUG_REPORT_BAD_ES 0
%endmacro

%macro ISABUG_REPORT_BAD_DS 0
%endmacro

%macro ISABUG_REPORT_WORD 3
%endmacro


%endif

%ifdef B8000_DEBUG_TRACE

%macro DBG_MARK 1
        pushf
        push    ax
        mov     al, %1
        call    dbg_mark
        pop     ax
        popf
%endmacro

; Emit an immediate/register/memory byte as two hex digits.
; Examples:
;   DBG_HEX8 al
;   DBG_HEX8 ah
;   DBG_HEX8 byte [cs:some_var]
%macro DBG_HEX8 1
        pushf
        push    ax
        mov     al, %1
        call    dbg_hex8
        pop     ax
        popf
%endmacro

; Emit an immediate/register/memory word as four hex digits.
; Examples:
;   DBG_HEX16 ax
;   DBG_HEX16 bx
;   DBG_HEX16 word [bp+0Ah]
%macro DBG_HEX16 1
        pushf
        push    ax
        mov     ax, %1
        call    dbg_hex16
        pop     ax
        popf
%endmacro

; Emit two-letter register name, '=', and a 16-bit value.
; Examples:
;   DBG_REG16 'A','X', ax        ; AX=1234
;   DBG_REG16 'B','X', bx        ; BX=1234
;   DBG_REG16 'D','S', ds        ; DS=1234
;   DBG_REG16 'S','P', sp        ; SP=1234
%macro DBG_REG16 3
        DBG_MARK %1
        DBG_MARK %2
;        DBG_MARK '='
        DBG_HEX16 %3
%endmacro

; Emit a compact separator between debug fields.
; Examples:
;   DBG_SEP
;   DBG_REG16 'A','X', ax
;   DBG_SEP
;   DBG_REG16 'B','X', bx
%macro DBG_SEP 0
;        DBG_MARK ' '
;        DBG_MARK '-'
;        DBG_MARK ' '
        DBG_MARK ':'
%endmacro

; Dump general 16-bit registers visible at the call site.
; Preserves the caller's register values, but note that SP is the
; value after macro entry pushes, so use DBG_REG16 'S','P', sp
; manually if exact SP-at-point is not critical.
%macro DBG_DUMP_GPRS 0
        DBG_REG16 'A','X', ax
        DBG_SEP
        DBG_REG16 'B','X', bx
        DBG_SEP
        DBG_REG16 'C','X', cx
        DBG_SEP
        DBG_REG16 'D','X', dx
        DBG_SEP
        DBG_REG16 'S','I', si
        DBG_SEP
        DBG_REG16 'D','I', di
        DBG_SEP
        DBG_REG16 'B','P', bp
%endmacro

; Dump segment registers visible at the call site.
%macro DBG_DUMP_SEGS 0
        DBG_REG16 'C','S', cs
        DBG_SEP
        DBG_REG16 'D','S', ds
        DBG_SEP
        DBG_REG16 'E','S', es
        DBG_SEP
        DBG_REG16 'S','S', ss
%endmacro

%else

%macro DBG_MARK 1
%endmacro

%macro DBG_HEX8 1
%endmacro

%macro DBG_HEX16 1
%endmacro

%macro DBG_REG16 3
%endmacro

%macro DBG_SEP 0
%endmacro

%macro DBG_DUMP_GPRS 0
%endmacro

%macro DBG_DUMP_SEGS 0
%endmacro

%endif
		
		
Strategy_Routine_0: ; proc	far		
		mov	[cs:ReqBlock_Seg], es ; ES:BX -> Device Request Block
		mov	[cs:ReqBlock_Off], bx
		retf


Interrupt_Routine_0:		
		push	ds	; Device Request Block:
					; 0 db length
					; 1 db unit number
					; 2 db command code
					; 5 d? reserved
					; 0D d?	command	specific data
		push	es

loc_19E:				
		push	bx
		push	cx
		push	dx
		push	si
		push	di
		push	bp
		pushf
		mov	bx, [cs:ReqBlock_Off]
		mov	es, [cs:ReqBlock_Seg]
		mov	al, [es:bx+2]	; Get command code
		or	al, al
		jnz	short loc_1BA
		jmp	init_drv

loc_1BA:				
		mov	word [es:bx+3], 100h ; Set done for	request, no error

exit_request:			
		popf
		pop	bp
		pop	di
		pop	si
		pop	dx
		pop	cx
		pop	bx
		pop	es
		pop	ds
		retf
; ───────────────────────────────────────────────────────────────────────────
%macro ENABLE_TRANS 0
        pushf
        cmp     byte [cs:detect_mode], DETECT_86BOX_E0_BIT
        jne     %%normal_enable

        ; 86Box-only E0 marker mode:
        ; keep bit 7 intact while changing the translation bit.
        push    dx
        mov     dx, JUKO_E0_PORT
        in      al, dx
        or      al, JUKO_E0_TRANS_BIT
        out     dx, al
        pop     dx
        jmp     short %%done

%%normal_enable:
        mov     al, JUKO_E0_TRANS_BIT
        out     JUKO_E0_PORT, al

%%done:
        popf
%endmacro

%macro DISABLE_TRANS 0
        pushf
        cmp     byte [cs:detect_mode], DETECT_86BOX_E0_BIT
        jne     %%normal_disable

        ; 86Box-only E0 marker mode:
        ; keep bit 7 intact while clearing the translation bit.
        push    dx
        mov     dx, JUKO_E0_PORT
        in      al, dx
        and     al, 0FEh
        out     dx, al
        pop     dx
        jmp     short %%done

%%normal_disable:
        xor     al, al
        out     JUKO_E0_PORT, al

%%done:
        popf
%endmacro

; ───────────────────────────────────────────────────────────────────────────

driver_old_ss dw 0
driver_old_sp dw 0					
driver_old_ax dw 0					
driver_stack  times 64 dw 0 ; Hope it is enough 
driver_stack_top:

%macro SWITCH_TO_DRIVER_STACK 0
        cli

        mov     [cs:driver_old_ss], ss
        mov     [cs:driver_old_sp], sp
        mov     [cs:driver_old_ax], ax

        mov     ax, cs
        mov     ss, ax
        mov     sp, driver_stack_top
		
		mov     ax, [cs:driver_old_ax]
%endmacro


%macro RESTORE_CALLER_STACK 0
        cli

        mov     ax, [cs:driver_old_ss]
        mov     ss, ax
        mov     sp, [cs:driver_old_sp]
%endmacro
				

int67_hndl:				
		SWITCH_TO_DRIVER_STACK
		push	ds  ; At dispatcher call time, before jmp [bx]:
					; [bp+00] - BP
					; [bp+02] - DI
					; [bp+04] - SI
					; [bp+06] - DX
					; [bp+08] - CX
					; [bp+0A] - BX
					; [bp+0C] - ES
					; [bp+0E] - DS
		push	es
		push	bx
		push	cx
		push	dx
		push	si
		push	di
		push	bp
		mov		byte [cs:do_call_orig_int21], 1
;		DBG_MARK 'S'
		call	int21_hndl
;		DBG_MARK 'R'
		mov	bx, cs
		mov	ds, bx
		mov	bx, EMS_funcs_table
		mov	cl, ah		    ; EMS function number from AH into CL
		and	cl, 0F0h
		cmp	cl, 40h	; '@'   ; Check if function code is 0x4y for any y
;		DBG_MARK 'G'
		jnz	short short_exit_int67
;		DBG_MARK 'H'
		xchg	al, ah		; Subfunction, or page number for AH=44h MAP MEMORY, from AL into AH
		mov	cl, ah
		and	al, 0Fh
		shl	al, 1
		xor	ah, ah
		add	bx, ax
		mov	bp, sp
;		DBG_MARK 'I'
		jmp	word [bx]	; Dispatch by function number.
					; CL --	ex-AL, EMS function
; ───────────────────────────────────────────────────────────────────────────

short_exit_int67:			
		jmp	exit_int67_handler_err
; ───────────────────────────────────────────────────────────────────────────

EMS_fn00:				; GET MANAGER STATUS
		DBG_MARK '0'
		xor	ax, ax		; Returns OK, see https://www.ctyme.com/intr/rb-7415.htm
		jmp	exit_int67_handler		
; ───────────────────────────────────────────────────────────────────────────

EMS_fn01:				; Get Page Frame Segment Address
		DBG_MARK '1'
		mov ax, [cs:ems_frame_base_seg]
		mov	word [bp+0Ah], ax ; Upper 64Kb of the 640Kb-mem_dispos
							  ; Returned in saved BX:	[BP+0xAh]
		xor	ax, ax
		jmp	exit_int67_handler
; ───────────────────────────────────────────────────────────────────────────

EMS_fn02:				; GET NUMBER OF	PAGES
		DBG_MARK '2'
		mov	word [bp+6], 18h ; BX = number of unallocated pages
					; DX = total number of pages, 28 = 18h
		call	calc_free_pages
		mov	[bp+0Ah], si
		xor	ax, ax
		jmp	exit_int67_handler
; ───────────────────────────────────────────────────────────────────────────

EMS_fn03:				; GET HANDLE AND ALLOCATE MEMORY
		DBG_MARK '3'
		mov	ax, [bp+0Ah]	; Saved	BX -- number of	logical	pages to allocate
		cmp	ax, 18h		; Max number
		jbe	short allocate_page1
		mov	ah, 87h	    ; The number of total pages that are available in the system is insufficient to honor the request,
					; return error "insufficient memory pages in system"
		jmp	exit_int67_handler
; ───────────────────────────────────────────────────────────────────────────

allocate_page1:		
		call	calc_free_pages
		cmp	ax, si
		jbe	short allocate_page2
		mov	ah, 88h	; The number of unallocated pages currently available is insufficient to honor the allocation request,
					; return insufficient memory pages available
		jmp	exit_int67_handler
; ───────────────────────────────────────────────────────────────────────────

allocate_page2:				
		or	ax, ax
		jnz	short allocate_page3
		mov	ah, 89h	 ; Zero pages could not be assigned to a handle.
		jmp	exit_int67_handler
; ───────────────────────────────────────────────────────────────────────────

allocate_page3:		
		mov	di, EMS_logic_pages_tbl
		mov	dx, 1

search_next_backing_page:		
		mov	bx, 8

search_next1:			
		mov	cx, [bx+di]
		cmp	ch, dl
		jnz	short loc_255
		cmp	cl, 0FFh
		jnz	short found_free_backing_page

loc_255:				
		inc	bl
		inc	bl
		cmp	bl, 36h	; To the backing pages table end
		jbe	short search_next1
		jmp	short found_all_pages_1
; ───────────────────────────────────────────────────────────────────────────

found_free_backing_page:		
		inc	dl
		jmp	short search_next_backing_page
; ───────────────────────────────────────────────────────────────────────────

found_all_pages_1:			
		xor	si, si
		mov	bx, 8
		mov	di, EMS_logic_pages_tbl

search_next_backing_id2:	
        cmp     bl, 36h
        ja      alloc_table_corrupt
		
		mov	cx, [bx+di]
		cmp	cl, 0FFh
		jnz	short is_not_free1
		mov	cx, si
		mov	ch, dl
		mov	[bx+di], cx
		inc	si
		cmp	si, ax
		jz	short set_all_pages

is_not_free1:				
		inc	bl
		inc	bl
		jmp	short search_next_backing_id2
		
alloc_table_corrupt:
        mov     ah, 88h        ; insufficient free pages / allocation failed
        jmp     exit_int67_handler		
; ───────────────────────────────────────────────────────────────────────────

set_all_pages:			
		mov	[bp+6],	dx	; Save handler to saved	in stack DX
		xor	ax, ax
		jmp	exit_int67_handler
; ───────────────────────────────────────────────────────────────────────────

dbg_calls4 dw 0;

EMS_fn04:				; Map/Unmap Handle Page
		DBG_MARK '4'		
		; Leaving this code as an example of deep debug 
;		push ax
;		push dx
;		push bx 
;		inc  [cs:dbg_calls4]
;		mov  ax, [cs:dbg_calls4]
;		mov  dx, [bp+6] ; DX on int 67h call
;		mov  bx, [bp+0Ah] ; BX on int 67h call
;		DBG_DUMP_GPRS
;		pop  bx 
;		pop  dx
;		pop  ax
		
		cmp	cl, 3	; On call: AL -> CL
					; AH = 44h, 
					; AL = physical	page number (0-3)
					; BX = logical page number
					; or FFFFh to unmap (QEMM)
					; DX = handle
					; We have 4 pages?
		jbe	short map_page_1
		mov	ah, 8Bh	; One or more of the physical pages is out of the range of allowable physical pages.
		jmp	exit_int67_handler
; ───────────────────────────────────────────────────────────────────────────

map_page_1:				
		mov	dx, [bp+6]	; Restore saved	DX
		call	check_handler
		mov	al, dl
		call	calc_pages_for_handler
		mov	bx, [bp+0Ah]	; Restore saved	BX
		cmp	bx, dx
		jb	short loc_2AE
		mov	ah, 8Ah	; The logical page to map into memory is out of the range of logical pages which are allocated to the handle.
		jmp	exit_int67_handler
; ───────────────────────────────────────────────────────────────────────────

loc_2AE:				 
		mov	dh, al
		mov	al, cl
		mov	dl, [bp+0Ah]
		call	map_EMS_page_to_frame ;	AL = physical EMS frame/page-frame slot: 0..3
					;
					; DX = logical (backing) EMS-page
					; DH = handle
					;
					; DL = logical page number within handle
					;
					; Saves	previous contents to the backing store
		xor	ax, ax
		jmp	exit_int67_handler
; ───────────────────────────────────────────────────────────────────────────

EMS_fn05:				; RELEASE HANDLE AND MEMORY
		DBG_MARK '5'
		mov	dx, [bp+6]	; DX = EMM handle
		or	dl, dl
		jnz	short loc_2C9
		mov	ah, 83h	    ; The memory manager can not find the handle specified.
		jmp	exit_int67_handler
; ───────────────────────────────────────────────────────────────────────────

loc_2C9:				 
		mov	di, handler_context_flags
		mov	bx, dx
		cmp	byte [cs:bx+di], 0
		jz	short loc_2D9
		mov	ah, 86h	; A mapping context restoration error has been detected.
					; This error occurs when a program attempts to return
					; a handle and there is	still a	"mapping context"
					; on the context stack for the indicated handle.
		jmp	exit_int67_handler
; ───────────────────────────────────────────────────────────────────────────

loc_2D9:				
		mov	di, EMS_logic_pages_tbl
		xor	bx, bx
		xor	cl, cl

loc_2E0:				
		mov	ax, [bx+di]
		cmp	ah, dl
		jnz	short loc_2F0
		cmp	al, 0FFh
		jz	short loc_2F0
		mov	al, 0FFh
		mov	[bx+di], ax
		mov	cl, 1

loc_2F0:				
		inc	bl
		inc	bl
		cmp	bl, 36h	; To the end of table
		jbe	short loc_2E0
		or	cl, cl
		jnz	short loc_302
		mov	ah, 83h	; 'Г'
		jmp	exit_int67_handler
; ───────────────────────────────────────────────────────────────────────────

loc_302:				
		call	sync_aliases
		xor	ax, ax
		jmp	exit_int67_handler
; ───────────────────────────────────────────────────────────────────────────

EMS_fn06:				; Get EMM Version
		DBG_MARK '6'
		mov	ax, 32h	; Returns 3.2
		jmp	exit_int67_handler
; ───────────────────────────────────────────────────────────────────────────

EMS_fn07:				; Save Page Map
		DBG_MARK '7'
		mov	bx, [bp+6]
		mov	si, handler_context_flags
		cmp	byte [cs:bx+si], 0
		jz	short loc_321
		mov	ah, 8Dh	; The mapping register context stack already has
					; a context associated with the	handle.	The program
					; has attempted	to save	the mapping register context
					; when there was already a context for the handle
					; on the stack.
		jmp	exit_int67_handler
; ───────────────────────────────────────────────────────────────────────────

loc_321:				
		mov	dx, bx
		call	check_handler
		mov	bx, dx
		mov	byte [cs:bx+si], 1
		mov	di, handler_page_maps
		mov	si, EMS_logic_pages_tbl
		shl	bx, 1
		shl	bx, 1
		shl	bx, 1
		add	di, bx
		xor	bx, bx

save_next1:				
		mov	ax, [cs:bx+si]
		mov	[cs:bx+di], ax
		inc	bl
		inc	bl
		cmp	bl, 8
		jb	short save_next1
		xor	ax, ax
		jmp	exit_int67_handler
; ───────────────────────────────────────────────────────────────────────────

EMS_fn08:				; Restore Page Map
		mov	bx, [bp+6]
		mov	si, handler_context_flags
		cmp	byte [cs:bx+si], 0
		jnz	short loc_361
		mov	ah, 8Eh	; The mapping register context stack does not have
					; a context associated with the	handle.	The program
					; has attempted	to restore the mapping register
					; context when there was no context for	the handle
					; on the stack.
		jmp	exit_int67_handler
; ───────────────────────────────────────────────────────────────────────────

loc_361:			
		mov	dx, bx
		call	check_handler
		mov	bx, dx
		mov	byte [cs:bx+si], 0
		mov	si, handler_page_maps
		shl	bx, 1
		shl	bx, 1
		shl	bx, 1
		add	si, bx
		xor	bx, bx

restore_next1:			
		mov	dx, [cs:bx+si]
		mov	al, bl
		shr	al, 1
		push	si
		push	bx
		call	map_EMS_page_to_frame ;	AL = physical EMS frame/page-frame slot: 0..3
					;
					; DX = logical (backing) EMS-page
					; DH = handle
					;
					; DL = logical page number within handle
					;
					; Saves	previous contents to the backing store
		pop	bx
		pop	si
		inc	bl
		inc	bl
		cmp	bl, 6
		jbe	short restore_next1
		xor	ax, ax
		jmp	exit_int67_handler
; ───────────────────────────────────────────────────────────────────────────

EMS_fn09_fn0A:				; Reserved functions
		DBG_MARK '9'
		jmp	exit_int67_handler_err
; ───────────────────────────────────────────────────────────────────────────

EMS_fn0B:				; Get EMM Handle Count
		DBG_MARK 'B'
		call	count_active_handlers 
		xor	ah, ah
		mov	[bp+0Ah], ax
		xor	al, al
		jmp	exit_int67_handler ; short 
; ───────────────────────────────────────────────────────────────────────────

EMS_fn0C:				; Get EMM Handle Pages 
		DBG_MARK 'C'
		mov	ax, [bp+6]	; Returns count of the pages for handler in DL
					    ; Restore DX from [BP+6]
		call	calc_pages_for_handler
		or	dl, dl
		jnz	short loc_3A7
		mov	ah, 83h	; 'Г'   ; The memory manager can not find the handle specified.
		jmp	exit_int67_handler
; ───────────────────────────────────────────────────────────────────────────

loc_3A7:				
		xor	dh, dh
		mov	[bp+0Ah], dx	; Return to BX
		xor	ax, ax
		jmp	short exit_int67_handler ; short is too short when debug is active 
; ───────────────────────────────────────────────────────────────────────────


EMS_fn0D:				; Get All EMM Handle Pages
		DBG_MARK 'D'
		mov	si, [bp+2]
		call	count_active_handlers
		xor	ah, ah
		xor	dh, dh
		mov	[bp+0Ah], ax	; Return into BX
		mov	al, 1

loc_3CD:				
		call	calc_pages_for_handler
		or	dl, dl
		jz	short loc_3DE
		mov	[es:si], ax
		inc	si
		inc	si
		mov	[es:si], dx
		inc	si
		inc	si

loc_3DE:				
		inc	al
		cmp	al, 1Ch
		jbe	short loc_3CD
		xor	ax, ax
		jmp	short exit_int67_handler
; ───────────────────────────────────────────────────────────────────────────

EMS_fn0E:				; Many functions, code from AL was saved in AL 		
		DBG_MARK 'E'
		cld			; AL = subfunction
					; 00h get mapping registers
					; 01h set mapping registers
					; 02h get and set mapping registers at once
					; 03h get size of page-mapping array
					; DS:SI	-> array holding information (AL=01h/02h)
					; ES:DI	-> array to receive information	(AL=00h/02h)
					;
					; Return:
					; AH = status, 00h successful
					; AL = bytes in	page-mapping array (AL=03h only)
					; array	pointed	to by ES:DI receives mapping info (AL=00h/02h)
		mov	al, cl
		or	al, al
		jnz	short loc_3F9
		call	get_page_map
		mov	ax, 8
		jmp	short exit_int67_handler
; ───────────────────────────────────────────────────────────────────────────

loc_3F9:				
		cmp	al, 1
		jnz	short loc_406
		call	set_page_map
		mov	ax, 8
		jmp	short exit_int67_handler
; ───────────────────────────────────────────────────────────────────────────

loc_406:				
		cmp	al, 2
		jnz	short loc_416
		call	get_page_map
		call	set_page_map
		mov	ax, 8
		jmp	short exit_int67_handler
; ───────────────────────────────────────────────────────────────────────────

loc_416:			
		cmp	al, 3
		jnz	short loc_420
		mov	ax, 8
		jmp	short exit_int67_handler
; ───────────────────────────────────────────────────────────────────────────

loc_420:			
		mov	ah, 8Fh	; undefined subfunction
		jmp	short exit_int67_handler
; ───────────────────────────────────────────────────────────────────────────

exit_int67_handler_err:			
		mov	ah, 84h	; 0x84: unsupported function
					; https://www.lo-tech.co.uk/wiki/LIM_Expanded_Memory_Specification_V4:_Appendix_A

exit_int67_handler:			
		DBG_MARK 'Z'
		mov [cs:int67_ret_ax], ax
		
		pop	bp
		pop	di
		pop	si
		pop	dx
		pop	cx
		pop	bx
		pop	es
		pop	ds
		
		RESTORE_CALLER_STACK 
		mov ax, [cs:int67_ret_ax]
		iret
; ───────────────────────────────────────────────────────────────────────────
int67_ret_ax dw 0

calc_free_pages:			
		mov	di, EMS_logic_pages_tbl
		xor	si, si
		mov	bx, 8

cont_calc_freepg:			
		cmp	byte [cs:bx+di], 0FFh
		jnz	short not_free_page1
		inc	si

not_free_page1:			
		inc	bl
		inc	bl
		cmp	bl, 36h	; 36h/2 = 1Bh = 27, last element
		jbe	short cont_calc_freepg
		retn
; ───────────────────────────────────────────────────────────────────────────

calc_pages_for_handler:			
		mov	di, EMS_logic_pages_tbl
		mov	bx, 8
		xor	dl, dl

cont_calc1:				
		cmp	[cs:bx+di+1], al ; Handle in AL; handler in +1 offset in table
		jnz	short not_found1
		cmp	byte [cs:bx+di], 0FFh
		jz	short not_found1
		inc	dl

not_found1:				
		inc	bl
		inc	bl
		cmp	bl, 36h	; Until the table end
		jbe	short cont_calc1
		retn
; ───────────────────────────────────────────────────────────────────────────

count_active_handlers:			
		xor	al, al		; AL - result
		mov	di, EMS_logic_pages_tbl
		mov	cl, 1

cont_calc2:				
		mov	bx, 8

cont_search1:			
		cmp	[cs:bx+di+1], cl ; Has handler equal to	CL
		jnz	short not_our_handler
		cmp	byte [cs:bx+di], 0FFh ; Is it free?
		jz	short not_our_handler
		jmp	short inc_AL
; ───────────────────────────────────────────────────────────────────────────

not_our_handler:			
		inc	bl
		inc	bl
		cmp	bl, 36h	; Until the table end
		jbe	short cont_search1

to_next_handler:			
		inc	cl
		cmp	cl, 1Ch	; 28 decimal...
		jbe	short cont_calc2
		retn
; ───────────────────────────────────────────────────────────────────────────

inc_AL:				
		inc	al
		jmp	short to_next_handler
; ───────────────────────────────────────────────────────────────────────────
; Probable algorithm:
;
; 1. Find the backing copy of page DX.
; 2. Enable JUKO alternate mapping with OUT E0h,1.
; 3. Write back all 4 current page-frame slots to the backing store.
; 4. Copy the requested backing page into slot AL.
; 5. Disable JUKO alternate mapping with OUT E0h,0.
; 6. Update the current page map.
; 7. Rebuild alias groups and synchronize duplicates.

; AL = physical EMS frame/page-frame slot: 0..3
;
; DX = logical (backing) EMS-page
; DH = handle
;
; DL = logical page number within handle
;
; Saves	previous contents to the backing store

map_EMS_page_to_frame:			
		mov	di, EMS_logic_pages_tbl 
		or	dh, dh  ; DH should not be zero here
		jnz	short DH_OK
		retn
; ───────────────────────────────────────────────────────────────────────────

DH_OK:				
		cmp	dh, 18h		; Max. 24 = 18h	handlers
		jbe	short DH_OK1
		retn
; ───────────────────────────────────────────────────────────────────────────

DH_OK1:				
		mov	bx, 8		; This strange offset in the table -- for EMS slots (physical) pages

To_next_handler2:	
		cmp	[cs:bx+di], dx	; DX has same format as	the table entry, see above
		jz	short we_found_entry1
		inc	bl
		inc	bl
		cmp	bl, 36h	; 2*1Bh
		jbe	short To_next_handler2
		DBG_MARK 'N'
		; mov ah, 8Ah
        ; jmp exit_int67_handler
		retn
; ───────────────────────────────────────────────────────────────────────────

we_found_entry1:			
		shr	bl, 1
		mov	ah, bl		; AH - page index
		
		mov	bl, al		; BL - destination slot
		ENABLE_TRANS    ; Map Juko additional memory
		mov	al, bl		; AL - destination slot
		xor	bx, bx

to_next_slot1:			
		mov	di, EMS_logic_pages_tbl
		mov	si, segs_for_EMS_frames
		mov	dx, [cs:bx+di]
		cmp	dl, 0FFh
		jz short found_free_slot
		mov	cl, bl		; CL --	logical	page number for	handler
		mov	[cs:temp_phys_EMS_slot], bx
		mov	bl, 8

loc_4DC:				
        cmp     bl, 36h				; Reached end of the table 
        ja      loc_4DC_not_found

        cmp     [cs:bx+di], dx
        jz      short found_corresp_phys_page
        inc     bl
        inc     bl
        jmp     short loc_4DC

loc_4DC_not_found:
        mov     bx, [cs:temp_phys_EMS_slot]

        ; current_map[physical_slot] refers to a page that no longer
        ; has a corresponding backing entry.  Mark this physical slot
        ; as unmapped and continue with the next slot.
        mov     word [cs:bx+di], 00FFh

        jmp     found_free_slot
; ───────────────────────────────────────────────────────────────────────────

found_corresp_phys_page:		
		mov	es, word [cs:bx+si]
		mov	bl, cl
		mov	ds, word [cs:bx+si]
		mov	cx, 2000h ; 2000h	; Move bytes from page in upper	64Kb to	backing	memory of Juko to save changes
		xor	si, si
		xor	di, di
		cld 
		rep movsw
        mov     bx, [cs:temp_phys_EMS_slot]

found_free_slot:			
		inc	bl
		inc	bl
		cmp	bl, 6
		jbe	short to_next_slot1
		mov	di, segs_for_EMS_frames
		mov	bl, ah		; AH --	backing	page index
		shl	bl, 1
		mov	ds, word [cs:bx+di]	; Backing page segment to DS
		mov	bl, al		; Logical EMS frame in upper 64Kb
		shl	bl, 1
		mov	es, word [cs:bx+di]	; ES --	logical	EMS segment
		xor	di, di
		xor	si, si
		mov	cx, 2000h
		cld 
		rep movsw		; Copy data from backing memory	to EMS slot

		mov	bl, al
		DISABLE_TRANS ; Return traditional mapping
		mov	al, bl
		mov	di, EMS_logic_pages_tbl
		mov	cx, cs
		mov	ds, cx
		mov	bl, ah
		shl	bl, 1
		mov	cx, [bx+di]
		mov	bl, al
		shl	bl, 1
		mov	[bx+di], cx	; Save backing page number for slot
					; falls	through	to the next function

sync_aliases:
		DBG_MARK 'K'
		
		mov	si, EMS_slots_state ; Looks like	syncing	aliases	-- does	not analyzed thoroughly
		mov	word [si], 0
		mov	word [si+2], 0
		xor	cx, cx
		mov	ax, [di]
		cmp	al, 0FFh
		jz	short loc_573
		cmp	[di+2],	ax
		jnz	short loc_55B
		mov	cl, 1
		mov	[si], cl
		mov	[si+1],	cl

loc_55B:				
		cmp	[di+4],	ax
		jnz	short loc_567
		mov	cl, 1
		mov	[si], cl
		mov	[si+2],	cl

loc_567:				
		cmp	[di+6],	ax
		jnz	short loc_573
		mov	cl, 1
		mov	[si], cl
		mov	[si+3],	cl

loc_573:				
		cmp	byte [si+1], 0
		jnz	short loc_5A3
		mov	ax, [di+2]
		cmp	al, 0FFh
		jz	short loc_5A3
		cmp	[di+4],	ax
		jnz	short loc_58F
		inc	cl
		inc	ch
		mov	[si+1],	cl
		mov	[si+2],	cl

loc_58F:				
		cmp	[di+6],	ax
		jnz	short loc_5A3
		cmp	ch, 1
		jz	short loc_59D
		inc	ch
		inc	cl

loc_59D:				
		mov	[si+1],	cl
		mov	[si+3],	cl

loc_5A3:				
		cmp	byte [si+2], 0
		jnz	short loc_5BD
		mov	ax, [di+4]
		cmp	al, 0FFh
		jz	short loc_5BD
		cmp	[di+6],	ax
		jnz	short loc_5BD
		inc	cl
		mov	[si+2],	cl
		mov	[si+3],	cl

loc_5BD:				
		mov	byte [cs:do_call_orig_int21], 1
;		DBG_MARK 'Q'
		call	int21_hndl
;		DBG_MARK 'T'
		retn
; ───────────────────────────────────────────────────────────────────────────

check_handler:				
		or	dx, dx
		jnz	short loc_5D0
		mov	ah, 83h	; The memory manager can not find the handle specified.
		jmp	exit_int67_handler
; ───────────────────────────────────────────────────────────────────────────

loc_5D0:				
		cmp	dx, 18h
		jbe	short loc_5DA
		mov	ah, 83h	; The memory manager can not find the handle specified.
		jmp	exit_int67_handler
; ───────────────────────────────────────────────────────────────────────────

loc_5DA:				
		mov	di, EMS_logic_pages_tbl
		mov	bx, 8

check_next_entry:			
		cmp	byte [cs:bx+di], 0FFh
		jz	short loc_5ED
		cmp	[cs:bx+di+1], dl
		jnz	short loc_5ED
		retn			; Handler found	and checked
; ───────────────────────────────────────────────────────────────────────────

loc_5ED:				
		inc	bx
		inc	bx
		cmp	bx, 36h	; Check all the table
		jbe	short check_next_entry
		pop	ax
		mov	ah, 83h	; The memory manager can not find the handle specified.
		jmp	exit_int67_handler
; ───────────────────────────────────────────────────────────────────────────

get_page_map:				
		mov	es, word [bp+0Ch]
		mov	di, [bp+2]
		mov	si, EMS_logic_pages_tbl
		mov	cx, 4
		cld 
		rep movsw
		retn
; ───────────────────────────────────────────────────────────────────────────

set_page_map:				
		xor	ax, ax
		mov	si, [bp+4]

loc_60E:				
		mov	ds, word [bp+0Eh]
;		assume ds:nothing
		mov	dx, [si]
		cmp	dl, 0FFh
		jz	short loc_643
		or	dh, dh
		jnz	short loc_61E
		jmp	short loc_643
; ───────────────────────────────────────────────────────────────────────────

loc_61E:				
		cmp	dh, 18h
		jbe	short loc_626
		jmp	short loc_643
; ───────────────────────────────────────────────────────────────────────────

loc_626:				
		mov	di, EMS_logic_pages_tbl
		mov	bx, 8

loc_62C:				
		cmp	[cs:bx+di], dx
		jnz	short loc_63A
		push	ax
		push	si
		call	map_EMS_page_to_frame ;	AL = physical EMS frame/page-frame slot: 0..3
					;
					; DX = logical (backing) EMS-page
					; DH = handle
					;
					; DL = logical page number within handle
					;
					; Saves	previous contents to the backing store
		pop	si
		pop	ax
		jmp	short loc_643
; ───────────────────────────────────────────────────────────────────────────

loc_63A:				
		inc	bl
		inc	bl
		cmp	bx, 36h
		jbe	short loc_62C

loc_643:				
		inc	al
		inc	si
		inc	si
		cmp	al, 3
		jbe	short loc_60E
		retn
; ───────────────────────────────────────────────────────────────────────────

int21_hndl:				
		push	ax
		push	bx
		push	cx
		push	dx
		push	ds
		push	es
		push	si
		push	di
		push	bp
;		DBG_MARK 'U'
		mov	di, EMS_slots_state
		mov	ax, [cs:di]
		mov	bx, [cs:di+2]
		add	al, ah
		add	bl, bh
		add	al, bl
		or	al, al		; Test if all states are 0
		jz	short short_ret1
		xor	bx, bx

loop_on_EMS_slots0:			
		cmp	byte [cs:bx+di], 1
		jnz	short is_not_group1_0
		mov	dl, bl
		call	calc_CRC
		cmp	ax, [cs:CRC_group1]
		jnz	short copy_to_all_group1
		mov	bl, dl

is_not_group1_0:			
		inc	bl
		cmp	bl, 3
		jbe	short loop_on_EMS_slots0
		jmp	short to_group2_1
; ───────────────────────────────────────────────────────────────────────────

short_ret1:				
		jmp	short exit_int21_handler
; ───────────────────────────────────────────────────────────────────────────

copy_to_all_group1:		
;		DBG_MARK 'L'
		mov	[cs:CRC_group1], ax
		mov	ah, dl
		xor	bx, bx

loop_on_EMS_slots1:			
		mov	di, EMS_slots_state
		cmp	byte [cs:bx+di], 1
		jnz	short is_not_group1
		push	bx
		mov	al, bl
		call	copy_mem_if_diff
		pop	bx

is_not_group1:				
		inc	bl
		cmp	bl, 3
		jbe	short loop_on_EMS_slots1

to_group2_1:				
		xor	bl, bl
		mov	di, EMS_slots_state

loop_on_EMS_slots2:			
		cmp	byte [cs:bx+di], 2
		jnz	short is_not_group2
		mov	dl, bl
		call	calc_CRC
		cmp	ax, [cs:CRC_group2]
		jnz	short loc_6CE
		mov	bl, dl

is_not_group2:			
		inc	bl
		cmp	bl, 3
		jbe	short loop_on_EMS_slots2
		jmp	short exit_int21_handler
; ───────────────────────────────────────────────────────────────────────────

loc_6CE:			
;		DBG_MARK 'M'	
		mov	[cs:CRC_group2], ax
		mov	ah, dl
		xor	bx, bx

loc_6D6:				
		mov	di, EMS_slots_state
		cmp	byte [cs:bx+di], 2
		jnz	short loc_6E6
		push	bx
		mov	al, bl
		call	copy_mem_if_diff
		pop	bx

loc_6E6:				
		inc	bl
		cmp	bl, 3
		jbe	short loc_6D6
		

exit_int21_handler:		
;		DBG_MARK 'V'	
		pop	bp
		pop	di
		pop	si
		pop	es
		pop	ds
		pop	dx
		pop	cx
		pop	bx
		pop	ax
		cmp	byte [cs:do_call_orig_int21], 1
		jnz	short call_old_int21
;		DBG_MARK 'W' 
		mov	byte [cs:do_call_orig_int21], 0
		retn
; ───────────────────────────────────────────────────────────────────────────

call_old_int21:		
;		DBG_MARK 'X'
		jmp	far [cs:old_int21_offs]
; ───────────────────────────────────────────────────────────────────────────

copy_mem_if_diff:			
		cmp	ah, al
		jnz	short copy_mem1
		retn
; ───────────────────────────────────────────────────────────────────────────

copy_mem1:				
		cld
		mov	di, segs_for_EMS_frames
		xor	bh, bh
		mov	bl, al
		shl	bl, 1
		mov	es, word [cs:bx+di]
		mov	bl, ah
		shl	bl, 1
		mov	ds, word [cs:bx+di]
		xor	di, di
		xor	si, si
		mov	cx, 2000h	; 2000h	words =	16 Kb, EMS frame
		cld 
		rep movsw
		retn
; ───────────────────────────────────────────────────────────────────────────

calc_CRC:				
		cld
		mov	si, segs_for_EMS_frames
		xor	bh, bh
		mov	bl, dl
		shl	bl, 1
		mov	ds, word [cs:bx+si]
		mov	cx, 3FFEh	; 16 Kb
		xor	ax, ax

CRC_loop1:				
		mov	bx, cx
		xor	ax, [bx]
		rol	ax, 1
		dec	cx
		loop	CRC_loop1
		xor	bx, bx
		xor	ax, [bx]
		retn
; ───────────────────────────────────────────────────────────────────────────

init_drv:	
		mov	cx, cs
		mov	ds, cx
		
        call parse_mem_dispos_config
        jc   bad_config_error

        call build_mem_layout
        jc   bad_config_error
		
		push	sp
		mov	bp, sp
		cmp	[bp+0],	sp
		pop	ax
		jz	short is_86_88
		jmp	is_186_or_above
; ───────────────────────────────────────────────────────────────────────────

is_86_88:				
		mov	ax, 7000h
		mov	ds, ax
;		assume ds:nothing
		DISABLE_TRANS  ; Standard mapping
		mov	word [ds:0FFFEh], 6996h ; Last word of the 128 Kb area + mapped 384 Kb
		ENABLE_TRANS        ; Map additional memory
		mov	word [ds:0FFFEh], 9669h
		DISABLE_TRANS  ; Standard mapping
		cmp	word [ds:0FFFEh], 6996h
		jnz	short mapping_does_not_work
		ENABLE_TRANS        ; Map additional memory  / alternate mapping 
		cmp	word [ds:0FFFEh], 9669h
		DISABLE_TRANS  ; Standard mapping
		jnz	short mapping_does_not_work
		xor	ax, ax
		mov	ds, ax
;		assume ds:seg000
		cmp	word [67h*4], int67_hndl; Check if our handler here
		jnz	short install_int_handlers
		call	prn_banner
		mov	dx, aAlreadyIsInstalle ;	"\nAlready is installed	!\n\n\n\r$"
		int	21h		; DOS -
		jmp	exit_on_error

mapping_does_not_work:			
		jmp	is_186_or_above

install_int_handlers:	
		mov	ax, cs
		cmp	ax, 1F3Fh	; 128 Kb boundary -- where the board maps RAM
		jle	short we_are_lo_enough
		call	prn_banner
		mov	dx, aTooHighTRSAddr ; "\nCan't install: DOS offers too high add"...
		int	21h		; DOS -
		jmp exit_on_error; short

we_are_lo_enough:		
        call    is_upper64_reserved
        jz      short we_have_upper_64Kb ; The upper 64 Kb has already been reserved

        call    write_reboot_detection_marker

		xor	ax, ax
		mov	ds, ax
;		assume ds:seg000
		mov ax, word [413h] ; mem size in BIOS Data Area
		mov bx, 640
        sub bx, [cs:mem_dispos_kb]      ; required top before frame steal
        cmp ax, bx
        jb  is_186_or_above
		sub bx, 64 
		mov	word [413h], bx;	Cut to 640-mem_dispos_kb-64
		
        mov word [0472h], 1234h
		
		int	19h		; Soft reboot -- reinit	BIOS for new mem size
		; cli 
		; cld 
		; jmp     0F000h:0FFF0h

we_have_upper_64Kb:		
        call    consume_reboot_detection_marker

        ; xor     ax, ax
        ; mov     ds, ax
        ; mov     ax, [413h]
        ; DBG_REG16 'M','M', ax
		
		mov	bx, [cs:ReqBlock_Off]
		mov	es, [cs:ReqBlock_Seg]
		xor	ax, ax
		mov	ds, ax
		mov	word [19Ch], int67_hndl	; int 67h handler offs
		mov	word [19Eh], cs ; int 67h handler seg
		mov	ax, [84h]	; int 21h handler
		mov	word [cs:old_int21_offs], ax
		mov	ax, [86h]
		mov	word [cs:old_int21_offs+2], ax ; old_int21_seg
		mov	word [84h], int21_hndl
		mov	[86h], cs
		mov	word [es:bx+0Eh], init_drv ;	End of resident	drv part
		mov	word [es:bx+10h], cs
		mov	word [es:bx+3], 100h ; Done
		call	prn_banner
		mov	dx, aSuccessfullyInsta ;	"\nSuccessfully	installed: now you have	3"...
		int	21h		; DOS -
		jmp	exit_request

; ------------------------------------------------------------
; is_upper64_reserved
;
; Tests whether the reboot/reserve step has already happened.
; Selection is controlled by [cs:detect_mode].
;
; Output:
;   ZF=1: upper 64 Kb is considered already reserved
;   ZF=0: reserve-and-reboot step is still needed
;
; Destroys:
;   AX,BX,DS
; ------------------------------------------------------------

is_upper64_reserved:
        mov     al, [cs:detect_mode]

        cmp     al, DETECT_BANKED_MARKER
        je      short .banked_marker

        cmp     al, DETECT_PLAIN_MARKER
        je      short .plain_marker

        cmp     al, DETECT_BDA_SIZE
        je      short .bda_size

        cmp     al, DETECT_86BOX_E0_BIT
        je      short .e0_bit

        ; Unknown mode: fall back to the current/default behavior.
.banked_marker:
        mov     ax, REBOOT_MARKER_SEG
        mov     ds, ax
        ENABLE_TRANS
        mov     bx, [REBOOT_MARKER_OFF]
        DISABLE_TRANS
        cmp     bx, REBOOT_MARKER
        retn

.plain_marker:
        mov     ax, [cs:ems_frame_base_seg]
        mov     ds, ax
        mov     bx, [REBOOT_MARKER_OFF]
        cmp     bx, REBOOT_MARKER
        retn

.bda_size:
        xor     ax, ax
        mov     ds, ax
        mov     ax, [413h]
        mov     bx, 640
        sub     bx, [cs:mem_dispos_kb]
        sub     bx, 64
        cmp     ax, bx
        retn

.e0_bit:
        ; 86Box-specific mode.  The emulator must implement readback
        ; of the Juko E0h latch and keep bit 7 across the requested reboot.
        mov     dx, JUKO_E0_PORT
        in      al, dx
        and     al, JUKO_E0_REBOOT_BIT
        cmp     al, JUKO_E0_REBOOT_BIT
        retn

; ------------------------------------------------------------
; write_reboot_detection_marker
;
; Stores the reboot marker if the selected detection mode needs one.
; For DETECT_BDA_SIZE no marker is written.
;
; Destroys:
;   AX,DS
; ------------------------------------------------------------

write_reboot_detection_marker:
        mov     al, [cs:detect_mode]

        cmp     al, DETECT_BANKED_MARKER
        je      short .write_banked_marker

        cmp     al, DETECT_PLAIN_MARKER
        je      short .write_plain_marker

        cmp     al, DETECT_BDA_SIZE
        je      short .no_marker

        cmp     al, DETECT_86BOX_E0_BIT
        je      short .write_e0_bit

        ; Unknown mode: fall back to the current/default behavior.
        jmp     short .write_banked_marker

.no_marker:
        retn

.write_banked_marker:
        mov     ax, REBOOT_MARKER_SEG
        mov     ds, ax
        ENABLE_TRANS
        mov     word [REBOOT_MARKER_OFF], REBOOT_MARKER
        DISABLE_TRANS
        retn

.write_plain_marker:
        mov     ax, [cs:ems_frame_base_seg]
        mov     ds, ax
        mov     word [REBOOT_MARKER_OFF], REBOOT_MARKER
        retn

.write_e0_bit:
        ; Store the reboot marker in bit 7 of the 86Box Juko E0h latch.
        ; Keep bit 0 cleared so the normal memory map is active before reboot.
        mov     dx, JUKO_E0_PORT
        in      al, dx
        and     al, 0FEh
        or      al, JUKO_E0_REBOOT_BIT
        out     dx, al
        retn

; ------------------------------------------------------------
; consume_reboot_detection_marker
;
; Clears one-shot markers after they have served their purpose.
; At present this is needed only for the 86Box E0h-bit mode, otherwise
; a later reboot could see a stale bit 7 and skip the reserve step.
;
; Destroys:
;   AX,DX
; ------------------------------------------------------------

consume_reboot_detection_marker:
        mov     al, [cs:detect_mode]
        cmp     al, DETECT_86BOX_E0_BIT
        jne     short .done

        mov     dx, JUKO_E0_PORT
        in      al, dx
        and     al, 07Eh             ; clear bit 7 marker and bit 0 translation
        out     dx, al

        ; From now on, runtime EMS mapping must use plain OUT 1 / OUT 0.
        mov     byte [cs:detect_mode], DETECT_BANKED_MARKER
.done:
        retn
		
; ------------------------------------------------------------
; input:
; 		  [cs:mem_dispos_kb] = 0..64
;
; output:
;   	  ems_frame_base_seg
;   	  segs_for_EMS_frames[0..3]
; preserves: AX, BX, DI
; ------------------------------------------------------------

build_mem_layout:
        push ax
        push bx
        push di

        mov ax, [cs:mem_dispos_kb]
        cmp ax, 64
        ja  bad_mem_dispos_config
		
        mov cl, 6 ; AX = mem_dispos_kb * 64 = 2^6 paragraphs
        shl ax, cl
		
        mov bx, 9000h
        sub bx, ax                      ; BX = first EMS frame slot segment
        mov [cs:ems_frame_base_seg], bx

        mov di, segs_for_EMS_frames

        mov [cs:di+0], bx
        add bx, 0400h                   ; +16 Kb
        mov [cs:di+2], bx
        add bx, 0400h
        mov [cs:di+4], bx
        add bx, 0400h
        mov [cs:di+6], bx

        pop di
        pop bx
        pop ax
        clc
        retn

bad_mem_dispos_config:
        pop di
        pop bx
        pop ax
        stc
        retn		
; ───────────────────────────────────────────────────────────────────────────
INIT_CMDLINE_PTR_OFF equ 12h     ; DOS 3.x+ init packet command-line pointer,

; ------------------------------------------------------------
; Defaults:
;   /D:0
;   /M:1
;
; Accept displacement:
;   /D:0
;   /D=1
;   /D4
;   -D3
;   -D:2
;   -D=0
;
; Accept reboot detection mode:
;   /M:0 or /R:0   banked-memory marker, current/default behavior
;   /M:1 or /R:1   plain-memory marker, no bank switch
;   /M:2 or /R:2   BIOS Data Area size [0:413]
;   /M:3 or /R:3   86Box-only marker in bit 7 of port E0h
;
; Result:
;   [cs:mem_dispos_kb] = 0..64
;   [cs:detect_mode]   = 0..DETECT_MODE_MAX
;
; CF=0 ok, CF=1 bad config.
; ------------------------------------------------------------

parse_mem_dispos_config:
        push ax
        push bx
        push cx
        push dx
        push si
        push es

        mov bx, [cs:ReqBlock_Off]
        mov es, [cs:ReqBlock_Seg]

        mov si, [es:bx+INIT_CMDLINE_PTR_OFF]
        mov ax, [es:bx+INIT_CMDLINE_PTR_OFF+2]
        or  ax, ax
        jz  .ok_default

        mov es, ax

.scan:
        mov al, [es:si]
        inc si

        cmp al, 0
        je  .ok_default
        cmp al, 0Dh
        je  .ok_default
        cmp al, 0Ah
        je  .ok_default

        cmp al, '/'
        je  .after_switch
        cmp al, '-'
        jne .scan

.after_switch:
        mov al, [es:si]
        inc si
        and al, 0DFh                    ; uppercase

        cmp al, 'D'
        je  .parse_d_option

        cmp al, 'M'
        je  .parse_mode_option

        cmp al, 'R'                     ; alias: reboot-detection mode
        je  .parse_mode_option

        jmp .scan

.parse_d_option:
        call skip_optional_separator_es_si

        call parse_uint_es_si            ; AX=value, CF=0 if at least one digit
        jc   .bad

        cmp ax, 64
        ja  .bad

        mov [cs:mem_dispos_kb], ax
        jmp .scan

.parse_mode_option:
        call skip_optional_separator_es_si

        call parse_uint_es_si            ; AX=value, CF=0 if at least one digit
        jc   .bad

        cmp ax, DETECT_MODE_MAX
        ja  .bad

        mov [cs:detect_mode], al
        jmp .scan

.ok_default:
.ok:
        clc
        jmp short .ret

.bad:
        stc

.ret:
        pop es
        pop si
        pop dx
        pop cx
        pop bx
        pop ax
        retn		

; ------------------------------------------------------------
; Skip optional ':' or '=' after an option letter.
;
; input/output:
;   ES:SI -> option value, or unchanged if no separator is present
;
; preserves:
;   AX
; ------------------------------------------------------------

skip_optional_separator_es_si:
        push ax

        mov al, [es:si]
        cmp al, ':'
        je  short .skip
        cmp al, '='
        jne short .done

.skip:
        inc si

.done:
        pop ax
        retn

; ------------------------------------------------------------
; Parse unsigned decimal number at ES:SI.
; Stops at first non-digit.
; 
; output:
;   AX = parsed value
;   SI = after number
;   CF = 0 if at least one digit
;   CF = 1 if no digits
;
; destroys:
;   BX,CX,DX
; ------------------------------------------------------------

parse_uint_es_si:
        xor ax, ax
        xor cx, cx                      ; digit count

.next_digit:
        mov dl, [es:si]
        cmp dl, '0'
        jb  .done
        cmp dl, '9'
        ja  .done

        sub dl, '0'
        xor dh, dh

        ; AX = AX*10 + DX
        mov bx, ax
        shl ax, 1                       ; AX = 2x
        shl bx, 1
        shl bx, 1
        shl bx, 1                       ; BX = 8x
        add ax, bx                      ; AX = 10x
        add ax, dx

        inc si
        inc cx
        jmp .next_digit

.done:
        or cx, cx
        jz .no_digits
        clc
        retn

.no_digits:
        stc
        retn
; ───────────────────────────────────────────────────────────────────────────

is_186_or_above:			
		call	prn_banner
		mov	dx, aCanTInstallThisPc ;	"\nCan't install: this PC is not a JUKO X"...
		int	21h		; DOS -

exit_on_error:				
		mov	bx, [cs:ReqBlock_Off]
		mov	es, [cs:ReqBlock_Seg]
		mov	word [es:bx+3], 810Ch ; Done + Error + General failure
		mov	word [es:bx+10h], cs
		mov	word [es:bx+0Eh], 0	; End of resident part: 0 bytes from the beginning, i.e. do not install.
		jmp	exit_request

prn_banner:			
		mov	ax, cs
		mov	ds, ax
		mov	ax, 900h
		mov	dx, aExpandedMemoryEmu ;	"\n\rExpanded memory emulator V1.0 by Geor"...
		int	21h		; DOS -	PRINT STRING
					; DS:DX	-> string terminated by	"$"
		retn


bad_config_error:
        call prn_banner
        mov dx, aBadConfig
        int 21h
        jmp exit_on_error
		
; ───────────────────────────────────────────────────────────────────────────
aExpandedMemoryEmu db 0Ah		
		db 0Dh,'Expanded memory emulator V1.0 by George Lefterov, Sofia, Decembe'
		db 'r 1991.',0Ah, 0Dh
		db 'Reconsturced and fixed a little by Oleg Farenyuk aka Indrekis, Lviv, June 2026.'
		db 0Ah, 0Dh,'$'
aCanTInstallThisPc db 0Ah		
		db 'Can',27h,'t install: this PC is not a JUKO XT with 1M RAM!',0Ah
		db 0Ah
		db 0Ah
		db 0Dh,'$'
aSuccessfullyInsta db 0Ah		
		db 'Successfully installed: now you have 384K expanded memory.',0Ah
		db 0Ah
		db 0Ah
		db 0Dh,'$'
aAlreadyIsInstalle db 0Ah		
		db 'Already is installed !',0Ah
		db 0Ah
		db 0Ah
		db 0Dh,'$'
aTooHighTRSAddr	db 0Ah			
		db 'Can',27h,'t install: DOS offers too high address for TSR !',0Ah
		db 0Ah
		db 0Ah
		db 0Dh,'$'

aBadConfig db 0Ah
        db 'Bad IJUKOEMM configuration. Use /D:0../D:64 and /M:0../M:2.',0Ah
        db 'M/R modes: 0=banked marker, 1=plain marker, 2=BDA size.',0Ah,0Ah,0Dh,'$'		
		