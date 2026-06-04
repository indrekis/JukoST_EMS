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
		dw exit_int67_handler_err     ; краще, ніж dw 0FFh
		
EMS_logic_pages_tbl dw 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh; 0
		dw 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh; 9 ;
		dw 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh, 0FFh; 18 ;
		dw 0FFh			; 27 ; Descriptor:
					; +0: logical_page_number within handle	або FFh	якщо стор_нка в_льна
					; +1: handle id
					; 4+24 = 28 records: 4 physical	slots +	16*24 =	384 Кб backing memory
					;
handler_context_flags times 24 db 0		
handler_page_maps times 192 db 0	
EMS_slots_state	 times 4 db 0
					; Групи	синхронізації для alisa:
					; 0 - не має alias-конфлікту
					; 1 - належить до групи	синхронізації 1
					; 2 - належить до групи	синхронізації 2
CRC_group1	dw 0			
					
CRC_group2	dw 0	
					
old_int21_offs	dd 0
					
do_call_orig_int21 db 0
temp_phys_EMS_slot dw 0			
mem_dispos    EQU 0 ; 40h	
mem_dispos_kb EQU mem_dispos*16 ; 1	Kb 
segs_for_EMS_frames dw 9000h-mem_dispos, 9400h-mem_dispos, 9800h-mem_dispos, 9C00h-mem_dispos; TODO: test for 639 
		dw 2000h, 2400h, 2800h, 2C00h
        dw 3000h, 3400h, 3800h, 3C00h
        dw 4000h, 4400h, 4800h, 4C00h
        dw 5000h, 5400h, 5800h, 5C00h
        dw 6000h, 6400h, 6800h, 6C00h
        dw 7000h, 7400h, 7800h, 7C00h

%define B8000_DEBUG_TRACE 1

%ifdef B8000_DEBUG_TRACE
dbg_pos db 0

dbg_mark:
        push ax
        push bx
        push es

        mov     bx, 0B800h       ; CGA/EGA/VGA text memory
        mov     es, bx

        xor     bh, bh
        mov     bl, [cs:dbg_pos]
        and     bl, 0Fh          ; 16 positions
        shl     bx, 1

        ; row 0, col 64 + dbg_pos
        add     bx, 64*2

        mov     ah, 1Eh          ; yellow on blue-ish / visible attribute
        mov     [es:bx], ax

        inc     byte [cs:dbg_pos]

        pop     es
        pop     bx
        pop     ax
        ret
%endif

%ifdef B8000_DEBUG_TRACE

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
        out     dx, al              ; УВАГА: це НЕПРАВИЛЬНО для imm index
                                    ; не використовувати напряму
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
		push AX
        mov     al, %1
        call    dbg_mark
		pop  AX
		popf 
%endmacro

%else

%macro DBG_MARK 1
%endmacro

%endif
		
		
Strategy_Routine_0: ; proc	far		
		mov	[cs:ReqBlock_Seg], es ; ES:BX -> Device Request Block
		mov	[cs:ReqBlock_Off], bx
		retf
; Strategy_Routine_0 endp


Interrupt_Routine_0:		
		push	ds		; Device Request Block:
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

int67_hndl:				
		cli
		push	ds		; На момент виклику диспетчера в jmp [bx]:
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
		DBG_MARK 'R'
		mov	bx, cs
		mov	ds, bx
;		assume ds:seg000
		mov	bx, EMS_funcs_table
		mov	cl, ah		; Номер	EMS функц_ї з AH в CL
		and	cl, 0F0h
		cmp	cl, 40h	; '@'   ; Check if function code is 0x4y for any y
;		DBG_MARK 'G'
		jnz	short short_exit_int67
;		DBG_MARK 'H'
		xchg	al, ah		; Підфункція (або номер	сторінки, як для 44h, MAP MEMORY) з AL в AH
		mov	cl, ah
		and	al, 0Fh
		shl	al, 1
		xor	ah, ah
		add	bx, ax
		mov	bp, sp
;		DBG_MARK 'I'
		jmp	word [bx]	; Dispatch by function number.
					; CL --	ex-AH, EMS function
					; CH --	ex-AL, subfunction or page
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
		mov	word [bp+0Ah], 9000h-mem_dispos ; Upper 64Kb of the 640Kb-mem_dispos
					; Returned in saved BX:	[BP+0xAh]
					; TODO:	allow customization for	639 Kb and so on
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

EMS_fn04:				; Map/Unmap Handle Page
		DBG_MARK '4'		
		cmp	cl, 3		; AH = 44h
					; AL = physical	page number (0-3)
					; BX = logical page number
					; or FFFFh to unmap (QEMM)
					; DX = handle
					; We have 4 pages?
		jle	short map_page_1
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
		mov	ah, 83h	; 'Г'   ; The memory manager can not find the handle specified.
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
		mov	ah, 8Eh	; 'О'   ; The mapping register context stack does not have
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

EMS_fn0B:				; "Get EMM Handle Count" according to the standart.
		DBG_MARK 'B'
		mov	ax, [bp+6]	; In fact, returns count of the	pages for handler in DL
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
		jmp	exit_int67_handler ; short is too short when debug is active 
; ───────────────────────────────────────────────────────────────────────────

EMS_fn0C:				; Should be "Get EMM Handle Pages", looks like this and	previous functions are mismatched
		DBG_MARK 'C'
		call	count_active_handlers ;	Bug!
		xor	ah, ah
		mov	[bp+0Ah], ax
		xor	al, al
		jmp	short exit_int67_handler
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
		pop	bp
		pop	di
		pop	si
		pop	dx
		pop	cx
		pop	bx
		pop	es
		pop	ds
;		assume ds:nothing
		iret
; ───────────────────────────────────────────────────────────────────────────

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
		cmp	bl, 36h	; '6'   ; 36h/2 = 18h = 27, останн_й елемент
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
		cmp	bl, 36h	; '6'   ; Until the table end
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
		cmp	bl, 36h	; '6'   ;  Until the table end
		jbe	short cont_search1

to_next_handler:			
		inc	cl
		cmp	cl, 1Ch		; 28 decimal...
		jbe	short cont_calc2
		retn
; ───────────────────────────────────────────────────────────────────────────

inc_AL:				
		inc	al
		jmp	short to_next_handler
; ───────────────────────────────────────────────────────────────────────────
; Ймов_рно, алгоритм:

; 1. знайти backing copy стор_нки	DX
; 2. ув_мкнути JUKO alternate mapping через OUT E0h,1
; 3. записати назад у backing store вс_ 4	поточн_	page-frame slots
; 4. скоп_ювати потр_бну backing page у slot AL
; 5. вимкнути JUKO alternate mapping через OUT E0h,0
; 6. оновити current page	map
; 7. перебудувати	alias-groups _ синхрон_зувати дубл_кати

map_EMS_page_to_frame:			
		mov	di, EMS_logic_pages_tbl ; AL = physical EMS frame/page-frame slot: 0..3
					;
					; DX = logical (backing) EMS-page
					; DH = handle
					;
					; DL = logical page number within handle
					;
					; Saves	previous contents to the backing store
		or	dh, dh		; Тут DH не мав	би бути	нульовим
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
		cmp	bl, 36h	; '6'   ; 2*1Bh
		jbe	short To_next_handler2
		retn
; ───────────────────────────────────────────────────────────────────────────

we_found_entry1:			
		shr	bl, 1
		mov	ah, bl		; AH - page index
		
		mov	bl, al		; BL - destination slot
		mov	al, 1
		out	0E0h, al	; Map Juko additional memory
		mov	al, bl		; AL - destination slot
		xor	bx, bx

to_next_slot1:			
		mov	di, EMS_logic_pages_tbl
		mov	si, segs_for_EMS_frames
		mov	dx, [cs:bx+di]
		cmp	dl, 0FFh
		jz found_free_slot; short
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
		ISABUG_SHOW_WORD BX
		mov	es, word [cs:bx+si]
		mov	bl, cl
		mov	ds, word [cs:bx+si]
		mov	cx, 2000h ; 2000h	; Move bytes from page in upper	64Kb to	backing	memory of Juko to save changes
		xor	si, si
		xor	di, di
		cld 
		rep movsw
;		ISABUG_REPORT_BAD_ES
        mov     bx, [cs:temp_phys_EMS_slot]

found_free_slot:			
		inc	bl
		inc	bl
		cmp	bl, 6
		jbe	to_next_slot1; short 
		mov	di, segs_for_EMS_frames
		mov	bl, ah		; AH --	backing	page index
		shl	bl, 1
		mov	ds, word [cs:bx+di]	; Baking page segment to DS
		mov	bl, al		; Logical EMS frame in upper 64Kb
		shl	bl, 1
		mov	es, word [cs:bx+di]	; ES --	logical	EMS segment
		xor	di, di
		xor	si, si
		mov	cx, 2000h
		cld 
		rep movsw		; Copy data from backing memory	to EMS slot

		mov	bl, al
		xor	al, al
		out	0E0h, al	; Return traditional mapping
		mov	al, bl
		mov	di, EMS_logic_pages_tbl
		mov	cx, cs
		mov	ds, cx
;		assume ds:seg000
		mov	bl, ah
		shl	bl, 1
		mov	cx, [bx+di]
		mov	bl, al
		shl	bl, 1
		mov	[bx+di], cx	; Save backing page number for slot
					; falls	through	to the next function

sync_aliases:				
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
		mov	ah, 83h	; 'Г'   ; The memory manager can not find the handle specified.
		jmp	exit_int67_handler
; ───────────────────────────────────────────────────────────────────────────

loc_5D0:				
		cmp	dx, 18h
		jle	short loc_5DA
		mov	ah, 83h	; 'Г'   ; The memory manager can not find the handle specified.
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
		cmp	bx, 36h	; '6'   ; Check all the table
		jbe	short check_next_entry
		pop	ax
		mov	ah, 83h	; 'Г'   ; The memory manager can not find the handle specified.
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
		jle	short loc_626
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
		mov	cx, 2000h	; 2000h	words =	16Кб, EMS frame
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
		mov	cx, 3FFEh	; 16Кб
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
;		assume ds:seg000		
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
		xor	al, al
		out	0E0h, al	; Стандартне відображення
		mov	word [ds:0FFFEh], 6996h ; Останнє слово області 128 Кб + (відмаплених)384 Кб
		inc	al
		out	0E0h, al	; Відобразити додаткову	пам'ять
		mov	word [ds:0FFFEh], 9669h
		xor	al, al
		out	0E0h, al	; Стандартне відображення
		cmp	word [ds:0FFFEh], 6996h
		jnz	short mapping_does_not_work
		inc	al
		out	0E0h, al	; Відобразити додаткову	пам'ять
		cmp	word [ds:0FFFEh], 9669h
		mov	al, 0
		out	0E0h, al
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
		cmp	ax, 1F3Fh	; Межа 128Кб --	куди плата в_дображає RAM
		jle	short we_are_lo_enough
		call	prn_banner
		mov	dx, aTooHighTRSAddr ; "\nCan't install: DOS offers too high add"...
		int	21h		; DOS -
		jmp	exit_on_error ; short 

we_are_lo_enough:		
		mov	ax, 9000h-mem_dispos
		mov	ds, ax
;		assume ds:nothing
		cmp	word [ds:0], 6996h
		jz	short we_have_upper_64Kb ; Seg 9000h --	576 КБ,	тобто, відкусуємо верхні 64 Кб
					; TODO:	adapt for the 639Kb
		mov	word [ds:0], 6996h		
		xor	ax, ax
		mov	ds, ax
;		assume ds:seg000
		cmp	word [413h], 640-mem_dispos_kb ;	If 640Kb-mem_dispos_kb -- in mem size in BIOS Data Area
		jnae short is_186_or_above
		mov	word [413h], 576-mem_dispos_kb;	Cut to 640-mem_dispos_kb-64 =	576-mem_dispos_kb and	reboot
		int	19h		; Soft reboot -- reinit	BIOS for new mem size

we_have_upper_64Kb:		
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
; ───────────────────────────────────────────────────────────────────────────

is_186_or_above:			
		call	prn_banner
		mov	dx, aCanTInstallThisPc ;	"\nCan't install: this PC is not a JUKO X"...
		int	21h		; DOS -

exit_on_error:				
		mov	bx, [cs:ReqBlock_Off]
		mov	es, [cs:ReqBlock_Seg]
		mov	word [es:bx+3], 100Ch ; Дивний код помилки:	Done, без Error, але є код помилки 0xC = General failure
		mov	word [es:bx+10h], cs
		mov	word [es:bx+0Eh], 0	; К_нець резидентної частини --	0 байт в_д початку, тобто - не встановлювати.
					; Але без коду "error" це дивно
		jmp	exit_request
; Interrupt_Routine_0 endp

prn_banner:			
		mov	ax, cs
		mov	ds, ax
		mov	ax, 900h
		mov	dx, aExpandedMemoryEmu ;	"\n\rExpanded memory emulator V1.0 by Geor"...
		int	21h		; DOS -	PRINT STRING
					; DS:DX	-> string terminated by	"$"
		retn
; prn_banner	endp

prn_test:			
		mov	ax, cs
		mov	ds, ax
		mov	ax, 900h
		mov	dx, teststr ;	"\n\rExpanded memory emulator V1.0 by Geor"...
		int	21h		; DOS -	PRINT STRING
					; DS:DX	-> string terminated by	"$"
		retn
; prn_banner	endp

; ───────────────────────────────────────────────────────────────────────────
aExpandedMemoryEmu db 0Ah		
		db 0Dh,'Expanded memory emulator V1.0 by George Lefterov, Sofia, Decembe'
		db 'r 1991.',0Ah
		db 0Dh,'$'
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
		db    0
		db    0
		db    0
		db    0
teststr	db 0Ah			
		db 'Test string 1',0Ah
		db 0Ah
		db 0Dh,'$'