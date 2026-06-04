; Based on the disassembly by the Interactive Disassembler (IDA) 2010 Freeware version 

bits 16
cpu 8086
org 0

; ═══════════════════════════════════════════════════════════════════════════

; Segment type:	Pure code
; seg000		segment	byte public 'CODE' use16
; 		assume cs:seg000
;		assume es:nothing, ss:nothing, ds:nothing, fs:nothing, gs:nothing

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
handler_context_flags db 0		
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		dw 	  0			
		dw    0			
		db    0
		db    0
handler_page_maps db 0	
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db 0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
		db    0
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
segs_for_EMS_frames dw 9000h, 9400h, 9800h, 9C00h ; TODO: fix for 639 
		db    0
		db  20h
		db    0
		db  24h	; $
		db    0
		db  28h	; (
		db    0
		db  2Ch	; ,
		db    0
		db  30h	; 0
		db    0
		db  34h	; 4
		db    0
		db  38h	; 8
		db    0
		db  3Ch	; <
		db    0
		db  40h	; @
		db    0
		db  44h	; D
		db    0
		db  48h	; H
		db    0
		db  4Ch	; L
		db    0
		db  50h	; P
		db    0
		db  54h	; T
		db    0
		db  58h	; X
		db    0
		db  5Ch	; \
		db    0
		db  60h	; `
		db    0
		db  64h	; d
		db    0
		db  68h	; h
		db    0
		db  6Ch	; l
		db    0
		db  70h	; p
		db    0
		db  74h	; t
		db    0
		db  78h	; x
		db    0
		db  7Ch	; |


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
		call	int21_hndl
		mov	bx, cs
		mov	ds, bx
;		assume ds:seg000
		mov	bx, EMS_funcs_table
		mov	cl, ah		; Номер	EMS функц_ї з AH в CL
		and	cl, 0F0h
		cmp	cl, 40h	; '@'   ; Check if function code is 0x4y for any y
		jnz	short short_exit_int67
		xchg	al, ah		; Підфункція (або номер	сторінки, як для 44h, MAP MEMORY) з AL в AH
		mov	cl, ah
		and	al, 0Fh
		shl	al, 1
		xor	ah, ah
		add	bx, ax
		mov	bp, sp
		jmp	word [bx]	; Dispatch by function number.
					; CL --	ex-AH, EMS function
					; CH --	ex-AL, subfunction or page
; ───────────────────────────────────────────────────────────────────────────

short_exit_int67:			
		jmp	exit_int67_handler_err
; ───────────────────────────────────────────────────────────────────────────

EMS_fn00:				; GET MANAGER STATUS
		xor	ax, ax		; Returns OK, see https://www.ctyme.com/intr/rb-7415.htm
		jmp	exit_int67_handler
; ───────────────────────────────────────────────────────────────────────────

EMS_fn01:				; Get Page Frame Segment Address
		mov	word [bp+0Ah], 9000h ; Upper 64Kb of the 640Kb
					; Returned in saved BX:	[BP+0xAh]
					; TODO:	allow customization for	639 Kb and so on
		xor	ax, ax
		jmp	exit_int67_handler
; ───────────────────────────────────────────────────────────────────────────

EMS_fn02:				; GET NUMBER OF	PAGES
		mov	word [bp+6], 18h ; BX = number of unallocated pages
					; DX = total number of pages, 28 = 18h
		call	calc_free_pages
		mov	[bp+0Ah], si
		xor	ax, ax
		jmp	exit_int67_handler
; ───────────────────────────────────────────────────────────────────────────

EMS_fn03:				; GET HANDLE AND ALLOCATE MEMORY
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
		nop

found_free_backing_page:		; CODE XREF: Interrupt_Routine_0+B7j
		inc	dl
		jmp	short search_next_backing_page
; ───────────────────────────────────────────────────────────────────────────

found_all_pages_1:			; CODE XREF: Interrupt_Routine_0+C2j
		xor	si, si
		mov	bx, 8
		mov	di, EMS_logic_pages_tbl

search_next_backing_id2:		; CODE XREF: Interrupt_Routine_0+E7j
		mov	cx, [bx+di]
		cmp	cl, 0FFh
		jnz	short is_not_free1
		mov	cx, si
		mov	ch, dl
		mov	[bx+di], cx
		inc	si
		cmp	si, ax
		jz	short set_all_pages

is_not_free1:				; CODE XREF: Interrupt_Routine_0+D6j
		inc	bl
		inc	bl
		jmp	short search_next_backing_id2
; ───────────────────────────────────────────────────────────────────────────

set_all_pages:			
		mov	[bp+6],	dx	; Save handler to saved	in stack DX
		xor	ax, ax
		jmp	exit_int67_handler
; ───────────────────────────────────────────────────────────────────────────

EMS_fn04:				; Map/Unmap Handle Page
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
		mov	ax, 32h	; '2'   ; Returns 3.2
		jmp	exit_int67_handler
; ───────────────────────────────────────────────────────────────────────────

EMS_fn07:				; Save Page Map
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

loc_321:				; CODE XREF: Interrupt_Routine_0+17Ej
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

save_next1:				; CODE XREF: Interrupt_Routine_0+1ADj
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

restore_next1:			; CODE XREF: Interrupt_Routine_0+1F2j
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
		jmp	exit_int67_handler_err
; ───────────────────────────────────────────────────────────────────────────

EMS_fn0B:				; "Get EMM Handle Count" according to the standart.
		mov	ax, [bp+6]	; In fact, returns count of the	pages for handler in DL
					; Restore DX from [BP+6]
		call	calc_pages_for_handler
		or	dl, dl
		jnz	short loc_3A7
		mov	ah, 83h	; 'Г'   ; The memory manager can not find the handle specified.
		jmp	exit_int67_handler
; ───────────────────────────────────────────────────────────────────────────

loc_3A7:				; CODE XREF: Interrupt_Routine_0+204j
		xor	dh, dh
		mov	[bp+0Ah], dx	; Return to BX
		xor	ax, ax
		jmp	short exit_int67_handler
; ───────────────────────────────────────────────────────────────────────────
		nop

EMS_fn0C:				; Should be "Get EMM Handle Pages", looks like this and	previous functions are mismatched
		call	count_active_handlers ;	Bug!
		xor	ah, ah
		mov	[bp+0Ah], ax
		xor	al, al
		jmp	short exit_int67_handler
; ───────────────────────────────────────────────────────────────────────────
		nop

EMS_fn0D:				; Get All EMM Handle Pages
		mov	si, [bp+2]
		call	count_active_handlers
		xor	ah, ah
		xor	dh, dh
		mov	[bp+0Ah], ax	; Return into BX
		mov	al, 1

loc_3CD:				; CODE XREF: Interrupt_Routine_0+246j
		call	calc_pages_for_handler
		or	dl, dl
		jz	short loc_3DE
		mov	[es:si], ax
		inc	si
		inc	si
		mov	[es:si], dx
		inc	si
		inc	si

loc_3DE:				; CODE XREF: Interrupt_Routine_0+236j
		inc	al
		cmp	al, 1Ch
		jbe	short loc_3CD
		xor	ax, ax
		jmp	short exit_int67_handler
; ───────────────────────────────────────────────────────────────────────────
		nop

EMS_fn0E:				; Many functions, code from AL was saved in AL 		
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
		nop

loc_3F9:				; CODE XREF: Interrupt_Routine_0+252j
		cmp	al, 1
		jnz	short loc_406
		call	set_page_map
		mov	ax, 8
		jmp	short exit_int67_handler
; ───────────────────────────────────────────────────────────────────────────
		nop

loc_406:				; CODE XREF: Interrupt_Routine_0+25Fj
		cmp	al, 2
		jnz	short loc_416
		call	get_page_map
		call	set_page_map
		mov	ax, 8
		jmp	short exit_int67_handler
; ───────────────────────────────────────────────────────────────────────────
		nop

loc_416:				; CODE XREF: Interrupt_Routine_0+26Cj
		cmp	al, 3
		jnz	short loc_420
		mov	ax, 8
		jmp	short exit_int67_handler
; ───────────────────────────────────────────────────────────────────────────
		nop

loc_420:				; CODE XREF: Interrupt_Routine_0+27Cj
		mov	ah, 8Fh	; 'П'   ; undefined subfunction
		jmp	short exit_int67_handler
; ───────────────────────────────────────────────────────────────────────────
		nop

exit_int67_handler_err:			; CODE XREF: Interrupt_Routine_0:short_exit_int67j
					; Interrupt_Routine_0:EMS_fn09_fn0Aj
		mov	ah, 84h	; 'Д'   ; 0x84: unsupported function
					; https://www.lo-tech.co.uk/wiki/LIM_Expanded_Memory_Specification_V4:_Appendix_A

exit_int67_handler:			; CODE XREF: Interrupt_Routine_0+66j
					; Interrupt_Routine_0+70j ...
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

calc_free_pages:			; CODE XREF: Interrupt_Routine_0+78p
					; Interrupt_Routine_0:allocate_page1p
		mov	di, EMS_logic_pages_tbl
		xor	si, si
		mov	bx, 8

cont_calc_freepg:			; CODE XREF: Interrupt_Routine_0+2AAj
		cmp	byte [cs:bx+di], 0FFh
		jnz	short not_free_page1
		inc	si

not_free_page1:			; CODE XREF: Interrupt_Routine_0+2A0j
		inc	bl
		inc	bl
		cmp	bl, 36h	; '6'   ; 36h/2 = 18h = 27, останн_й елемент
		jbe	short cont_calc_freepg
		retn
; ───────────────────────────────────────────────────────────────────────────

calc_pages_for_handler:			; CODE XREF: Interrupt_Routine_0+103p
					; Interrupt_Routine_0+1FFp ...
		mov	di, EMS_logic_pages_tbl
		mov	bx, 8
		xor	dl, dl

cont_calc1:				; CODE XREF: Interrupt_Routine_0+2CAj
		cmp	[cs:bx+di+1], al ; Handle in AL; handler in +1 offset in table
		jnz	short not_found1
		cmp	byte [cs:bx+di], 0FFh
		jz	short not_found1
		inc	dl

not_found1:				; CODE XREF: Interrupt_Routine_0+2B9j
					; Interrupt_Routine_0+2BFj
		inc	bl
		inc	bl
		cmp	bl, 36h	; '6'   ; Until the table end
		jbe	short cont_calc1
		retn
; ───────────────────────────────────────────────────────────────────────────

count_active_handlers:			; CODE XREF: Interrupt_Routine_0:EMS_fn0Cp
					; Interrupt_Routine_0+225p
		xor	al, al		; AL - result
		mov	di, EMS_logic_pages_tbl
		mov	cl, 1

cont_calc2:				; CODE XREF: Interrupt_Routine_0+2F4j
		mov	bx, 8

cont_search1:				; CODE XREF: Interrupt_Routine_0+2EDj
		cmp	[cs:bx+di+1], cl ; Has handler equal to	CL
		jnz	short not_our_handler
		cmp	byte [cs:bx+di], 0FFh ; Is it free?
		jz	short not_our_handler
		jmp	short inc_AL
; ───────────────────────────────────────────────────────────────────────────
		nop

not_our_handler:			; CODE XREF: Interrupt_Routine_0+2DBj
					; Interrupt_Routine_0+2E1j
		inc	bl
		inc	bl
		cmp	bl, 36h	; '6'   ;  Until the table end
		jbe	short cont_search1

to_next_handler:			; CODE XREF: Interrupt_Routine_0+2F9j
		inc	cl
		cmp	cl, 1Ch		; 28 decimal...
		jbe	short cont_calc2
		retn
; ───────────────────────────────────────────────────────────────────────────

inc_AL:				; CODE XREF: Interrupt_Routine_0+2E3j
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

we_found_entry1:			; CODE XREF: Interrupt_Routine_0+30Fj
		shr	bl, 1
		mov	ah, bl		; AH - page index
		mov	bl, al		; BL - destination slot
		mov	al, 1
		out	0E0h, al	; Map Juko additional memory
		mov	al, bl		; AL - destination slot
		xor	bx, bx

to_next_slot1:			; CODE XREF: Interrupt_Routine_0+368j
		mov	di, EMS_logic_pages_tbl
		mov	si, segs_for_EMS_frames
		mov	dx, [cs:bx+di]
		cmp	dl, 0FFh
		jz	short found_free_slot
		mov	cl, bl		; CL --	logical	page number for	handler
		mov	[cs:temp_phys_EMS_slot], bx
		mov	bl, 8

loc_4DC:				
        cmp     [cs:bx+di], dx
        jz      short found_corresp_phys_page
        inc     bl
        inc     bl
        jmp     short loc_4DC
; ───────────────────────────────────────────────────────────────────────────

found_corresp_phys_page:		; CODE XREF: Interrupt_Routine_0+343j
		mov	es, word [cs:bx+si]
		mov	bl, cl
		mov	ds, word [cs:bx+si]
		mov	cx, 2000h	; Move bytes from page in upper	64Kb to	backing	memory of Juko to save changes
		xor	si, si
		xor	di, di
		rep movsw
        mov     bx, [cs:temp_phys_EMS_slot]

found_free_slot:			; CODE XREF: Interrupt_Routine_0+335j
		inc	bl
		inc	bl
		cmp	bl, 6
		jbe	short to_next_slot1
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

sync_aliases:				; CODE XREF: Interrupt_Routine_0:loc_302p
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

loc_55B:				; CODE XREF: Interrupt_Routine_0+3B6j
		cmp	[di+4],	ax
		jnz	short loc_567
		mov	cl, 1
		mov	[si], cl
		mov	[si+2],	cl

loc_567:				; CODE XREF: Interrupt_Routine_0+3C2j
		cmp	[di+6],	ax
		jnz	short loc_573
		mov	cl, 1
		mov	[si], cl
		mov	[si+3],	cl

loc_573:				; CODE XREF: Interrupt_Routine_0+3B1j
					; Interrupt_Routine_0+3CEj
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

loc_58F:				; CODE XREF: Interrupt_Routine_0+3E7j
		cmp	[di+6],	ax
		jnz	short loc_5A3
		cmp	ch, 1
		jz	short loc_59D
		inc	ch
		inc	cl

loc_59D:				; CODE XREF: Interrupt_Routine_0+3FBj
		mov	[si+1],	cl
		mov	[si+3],	cl

loc_5A3:				; CODE XREF: Interrupt_Routine_0+3DBj
					; Interrupt_Routine_0+3E2j ...
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

loc_5BD:				; CODE XREF: Interrupt_Routine_0+40Bj
					; Interrupt_Routine_0+412j ...
		mov	byte [cs:do_call_orig_int21], 1
		call	int21_hndl
		retn
; ───────────────────────────────────────────────────────────────────────────

check_handler:				; CODE XREF: Interrupt_Routine_0+FEp
					; Interrupt_Routine_0+187p ...
		or	dx, dx
		jnz	short loc_5D0
		mov	ah, 83h	; 'Г'   ; The memory manager can not find the handle specified.
		jmp	exit_int67_handler
; ───────────────────────────────────────────────────────────────────────────

loc_5D0:				; CODE XREF: Interrupt_Routine_0+42Dj
		cmp	dx, 18h
		jle	short loc_5DA
		mov	ah, 83h	; 'Г'   ; The memory manager can not find the handle specified.
		jmp	exit_int67_handler
; ───────────────────────────────────────────────────────────────────────────

loc_5DA:				; CODE XREF: Interrupt_Routine_0+437j
		mov	di, EMS_logic_pages_tbl
		mov	bx, 8

check_next_entry:			; CODE XREF: Interrupt_Routine_0+456j
		cmp	byte [cs:bx+di], 0FFh
		jz	short loc_5ED
		cmp	[cs:bx+di+1], dl
		jnz	short loc_5ED
		retn			; Handler found	and checked
; ───────────────────────────────────────────────────────────────────────────

loc_5ED:				; CODE XREF: Interrupt_Routine_0+448j
					; Interrupt_Routine_0+44Ej
		inc	bx
		inc	bx
		cmp	bx, 36h	; '6'   ; Check all the table
		jbe	short check_next_entry
		pop	ax
		mov	ah, 83h	; 'Г'   ; The memory manager can not find the handle specified.
		jmp	exit_int67_handler
; ───────────────────────────────────────────────────────────────────────────

get_page_map:				; CODE XREF: Interrupt_Routine_0+254p
					; Interrupt_Routine_0+26Ep
		mov	es, word [bp+0Ch]
		mov	di, [bp+2]
		mov	si, EMS_logic_pages_tbl
		mov	cx, 4
		rep movsw
		retn
; ───────────────────────────────────────────────────────────────────────────

set_page_map:				; CODE XREF: Interrupt_Routine_0+261p
					; Interrupt_Routine_0+271p
		xor	ax, ax
		mov	si, [bp+4]

loc_60E:				; CODE XREF: Interrupt_Routine_0+4ADj
		mov	ds, word [bp+0Eh]
;		assume ds:nothing
		mov	dx, [si]
		cmp	dl, 0FFh
		jz	short loc_643
		or	dh, dh
		jnz	short loc_61E
		jmp	short loc_643
; ───────────────────────────────────────────────────────────────────────────

loc_61E:				; CODE XREF: Interrupt_Routine_0+47Ej
		cmp	dh, 18h
		jle	short loc_626
		jmp	short loc_643
; ───────────────────────────────────────────────────────────────────────────
		nop

loc_626:				; CODE XREF: Interrupt_Routine_0+485j
		mov	di, EMS_logic_pages_tbl
		mov	bx, 8

loc_62C:				; CODE XREF: Interrupt_Routine_0+4A5j
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

loc_63A:				; CODE XREF: Interrupt_Routine_0+493j
		inc	bl
		inc	bl
		cmp	bx, 36h	; '6'
		jbe	short loc_62C

loc_643:				; CODE XREF: Interrupt_Routine_0+47Aj
					; Interrupt_Routine_0+480j ...
		inc	al
		inc	si
		inc	si
		cmp	al, 3
		jbe	short loc_60E
		retn
; ───────────────────────────────────────────────────────────────────────────

int21_hndl:				; CODE XREF: Interrupt_Routine_0+3Dp
					; Interrupt_Routine_0+427p
					; DATA XREF: ...
		push	ax
		push	bx
		push	cx
		push	dx
		push	ds
		push	es
		push	si
		push	di
		push	bp
		mov	di, EMS_slots_state
		mov	ax, [cs:di]
		mov	bx, [cs:di+2]
		add	al, ah
		add	bl, bh
		add	al, bl
		or	al, al		; Test if all states are 0
		jz	short short_ret1
		xor	bx, bx

loop_on_EMS_slots0:			; CODE XREF: Interrupt_Routine_0+4E8j
		cmp	byte [cs:bx+di], 1
		jnz	short is_not_group1_0
		mov	dl, bl
		call	calc_CRC
		cmp	ax, [cs:CRC_group1]
		jnz	short copy_to_all_group1
		mov	bl, dl

is_not_group1_0:			; CODE XREF: Interrupt_Routine_0+4D3j
		inc	bl
		cmp	bl, 3
		jbe	short loop_on_EMS_slots0
		jmp	short to_group2_1
; ───────────────────────────────────────────────────────────────────────────
		nop

short_ret1:				; CODE XREF: Interrupt_Routine_0+4CBj
		jmp	short exit_int21_handler
; ───────────────────────────────────────────────────────────────────────────
		nop

copy_to_all_group1:			; CODE XREF: Interrupt_Routine_0+4DFj
		mov	[cs:CRC_group1], ax
		mov	ah, dl
		xor	bx, bx

loop_on_EMS_slots1:			; CODE XREF: Interrupt_Routine_0+50Dj
		mov	di, EMS_slots_state
		cmp	byte [cs:bx+di], 1
		jnz	short is_not_group1
		push	bx
		mov	al, bl
		call	copy_mem_if_diff
		pop	bx

is_not_group1:				; CODE XREF: Interrupt_Routine_0+4FFj
		inc	bl
		cmp	bl, 3
		jbe	short loop_on_EMS_slots1

to_group2_1:				; CODE XREF: Interrupt_Routine_0+4EAj
		xor	bl, bl
		mov	di, EMS_slots_state

loop_on_EMS_slots2:			; CODE XREF: Interrupt_Routine_0+52Dj
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
		nop

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

exit_int21_handler:			; CODE XREF: Interrupt_Routine_0:short_ret1j
					; Interrupt_Routine_0+52Fj
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
		mov	byte [cs:do_call_orig_int21], 0
		retn
; ───────────────────────────────────────────────────────────────────────────

call_old_int21:				; CODE XREF: Interrupt_Routine_0+560j
		jmp	far [cs:old_int21_offs]
; ───────────────────────────────────────────────────────────────────────────

copy_mem_if_diff:			; CODE XREF: Interrupt_Routine_0+504p
					; Interrupt_Routine_0+546p
		cmp	ah, al
		jnz	short copy_mem1
		retn
; ───────────────────────────────────────────────────────────────────────────

copy_mem1:				; CODE XREF: Interrupt_Routine_0+570j
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
		rep movsw
		retn
; ───────────────────────────────────────────────────────────────────────────

calc_CRC:				; CODE XREF: Interrupt_Routine_0+4D7p
					; Interrupt_Routine_0+51Cp
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
		mov	ax, 9000h
		mov	ds, ax
;		assume ds:nothing
		cmp	word [ds:0], 6996h
		jz	short we_have_upper_64Kb ; Seg 9000h --	576 КБ,	тобто, відкусуємо верхні 64 Кб
					; TODO:	adapt for the 639Kb
		mov	word [ds:0], 6996h		
		xor	ax, ax
		mov	ds, ax
;		assume ds:seg000
		cmp	word [413h], 640 ;	If 640Kb -- Mem size in BIOS Data Area
		jnz	short is_186_or_above
		mov	word [413h], 576 ;	Cut to 640-64 =	576 and	reboot
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

is_186_or_above:			; CODE XREF: Interrupt_Routine_0+5F0j
					; Interrupt_Routine_0:mapping_does_not_workj ...
		call	prn_banner
		mov	dx, aCanTInstallThisPc ;	"\nCan't install: this PC is not a JUKO X"...
		int	21h		; DOS -

exit_on_error:				; CODE XREF: Interrupt_Routine_0+63Cj
					; Interrupt_Routine_0+651j
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