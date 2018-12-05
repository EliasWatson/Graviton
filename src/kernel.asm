bits 16

org 0

; Where to find the INT 8 handler vector within the IVT [interrupt vector table]
IVT8_OFFSET_SLOT	equ	4 * 8			; Each IVT entry is 4 bytes; this is the 8th
IVT8_SEGMENT_SLOT	equ	IVT8_OFFSET_SLOT + 2	; Segment after Offset

IVT9_OFFSET_SLOT	equ	4 * 9
IVT9_SEGMENT_SLOT	equ	IVT9_OFFSET_SLOT + 2

;all images are 16x16 pixels

;creates an image struc with max 16 pixels
;struc wordImage
	;the coordinates (on the dosbox display) of the upper left corner of the image
;    .x_coord: resw 0
;    .y_coord: resb 0
    ;the position of each pixel in the image relative to the top left corner. For each byte: lower half: x, higher half: y
;    .posMap: TIMES 2 resq 0
	;each byte is the color of the pixel in the same byte of posMap
;	.colMap:	TIMES 2 resq 0
;    .size:
;endstruc

;creates an image struc with max 32 pixels
struc quadImage
	;the coordinates (on the dosbox display) of the upper left corner of the image
    .x_coord: resw 0
    .y_coord: resb 0
    ;the position of each pixel in the image relative to the top left corner. For each byte: lower half: x, higher half: y
    .posMap: TIMES 4 resq 0
	;each byte is the color of the pixel in the same byte of posMap
	.colMap:	TIMES 4 resq 0
    .size:
endstruc

;creates an image struc with max 64 pixels
;struc octImage
	;the coordinates (on the dosbox display) of the upper left corner of the image
;    .x_coord: resw 0
;    .y_coord: resb 0
    ;the position of each pixel in the image relative to the top left corner. For each byte: lower half: x, higher half: y
;    .posMap: TIMES 8 resq 0
	;each byte is the color of the pixel in the same byte of posMap
;	.colMap:	TIMES 8 resq 0
;    .size:
;endstruc

;creates a gravity well struc
struc grav_well
	;the coordinates (on the dosbox display) of the upper left corner of the well
    .x_coord: resw 0
    .y_coord: resb 0
	;denotes the current energy level of the well (can only go to 10 before resetting)
	.power_level: resb 0
    .size:
endstruc

SECTION .text
main:
	mov     ah, 0x0
	mov     al, 0x1
	int     0x10                    ; set video to text mode

	; Set ES=0x0000 (segment of IVT)
	mov	ax, 0x0000
	mov	es, ax
	
	; TODO Install interrupt hook
	; 0. disable interrupts (so we can't be...INTERRUPTED...)
	cli
	; 1. save current INT 8 handler address (segment:offset) into ivt8_offset and ivt8_segment
	mov ax, [es:IVT8_OFFSET_SLOT]
    mov [ivt8_offset], ax
    mov ax, [es:IVT8_SEGMENT_SLOT]
    mov [ivt8_segment], ax
	; 2. set new INT 8 handler address (OUR code's segment:offset)
	lea ax, [timer_isr]
    mov [es:IVT8_OFFSET_SLOT], ax
    mov ax, cs
    mov [es:IVT8_SEGMENT_SLOT], ax

	mov ax, [es:IVT9_OFFSET_SLOT]
    mov [ivt9_offset], ax
    mov ax, [es:IVT9_SEGMENT_SLOT]
    mov [ivt9_segment], ax

	lea ax, [keyboard_int]
    mov [es:IVT9_OFFSET_SLOT], ax
    mov ax, cs
    mov [es:IVT9_SEGMENT_SLOT], ax
	; 3. reenable interrupts (GO!)
	sti

	mov     ah, 0x0
	mov     al, 0x13
	int     0x10                    ; set video to vga mode

	mov     byte [task_status], 1               ; set main task to active

	lea     di, [render_environment]                        ; create graphics thread
	call    spawn_new_task

	lea     di, [control_player]                        ; create player thread
	call    spawn_new_task

	lea     di, [sustain_wells]                        ; create gravity wells thread
	call    spawn_new_task

	lea     di, [render_wells]                        ; create task b
	call    spawn_new_task

	mov     ax, 0xA000
	mov     es, ax                  ; set memory to vga position

.loop_forever_main:                             ; have main print for eternity
	;either have this be one of our threads or have it be an error handler
	jmp     .loop_forever_main	
	; does not terminate or return

; di should contain the address of the function to run for a task
spawn_new_task:
	lea     bx, [stack_pointers]                ; get the location of the stack pointers
    add     bx, [current_task]                  ; get the location of the current stack pointer
	mov     [bx], sp                            ; save current stack so we can switch back
	mov     cx, [current_task]                  ; look for a new task 
	add     cx, 2                               ; start searching at the next one though
.sp_loop_for_available_stack:
	cmp     cx, [current_task]                  ; we are done when we get back to the original
	jne     .sp_check_if_available
	jmp     .sp_no_available_stack
.sp_check_if_available:
	lea     bx, [task_status]                   ; get status of this stack
	add     bx, cx                              
	cmp     word [bx], 0
	je      .sp_is_available
	add     cx, 2                               ; next stack to search
    and     cx, 0x2F                            ; make sure stack to search is always less than 64
	jmp     .sp_loop_for_available_stack
.sp_is_available:
	lea     bx, [task_status]                   ; we found a stack, set it to active
	add     bx, cx
	mov     word [bx], 1
	lea     bx, [stack_pointers]                ; switch to the fake stack so we can do stuff with it
	add     bx, cx
	mov     sp, [bx]                            ; swap stacks
	push    di                                  ; push address of function to run
	pusha                                       ; push registers
	pushf                                       ; push flags
	lea     bx, [stack_pointers]                ; update top of this stack
	add     bx, cx
	mov     [bx], sp
.sp_no_available_stack:                         ; restore to original stack
	lea     bx, [stack_pointers]
	add     bx, [current_task]
	mov     sp, [bx]
	ret

;environment graphics thread
render_environment:
.loop_forever_1:
	jmp     .loop_forever_1
	; does not terminate or return

;player thread
control_player:
.loop_forever_2:
    mov ax, 0x0C73
    mov bx, 0x0
	mov cx, [rect_b_x]
    mov dx, 100
    int 0x10

    cmp byte [keypress], 0x1E
    jne .key_a_exit
        inc word [rect_b_x]
    .key_a_exit:
    
    cmp byte [keypress], 0x20
    jne .key_d_exit
        dec word [rect_b_x]
    .key_d_exit:

	jmp     .loop_forever_2
	; does not terminate or return

; Custom keyboard interrupt
keyboard_int:
    push ax
    in al, 0x60
    mov [keypress], al
    mov ax, 0x20
    out 0x20, al
    pop ax
    iret

;gravity well thread
sustain_wells:
.loop_forever_3:
	jmp     .loop_forever_3
	; does not terminate or return

;well graphics thread
render_wells:
.loop_forever_4:
	mov bx, [grav_one]
	mov ax, word [bx]
	mov cx, [bx + 2]
	mov bx, [grav_sprite]
	mov [bx], ax
	mov [bx + 2], cx
	call mutex
	call displayQuadImage
	call release
	jmp     .loop_forever_4
	; does not terminate or return

	;not entirely sure where to put this
	mov ax, 0x800
	mov ds, ax

; INT 8 Timer ISR (interrupt service routine)
; cannot clobber anything; must CHAIN to original caller (for interrupt acknowledgment)
; DS/ES == ???? (at entry, and must retain their original values at exit)
timer_isr:
	;save any registers we clobber to the stack
	pusha
    lea     bx, [stack_pointers]                ; get the location of the stack pointers
    add     bx, [current_task]                  ; get the location of the current stack pointer
    mov     [bx], sp                            ; save current stack so we can switch back
    mov     cx, [current_task]                  ; look for a new task 
    add     cx, 2
.sp_loop_for_active_stack:
    cmp     cx, [current_task]                  ; we are done when we get back to the original
    jne     .sp_check_if_active
    jmp     .sp_none_active
.sp_check_if_active:
    lea     bx, [task_status]                   ; get status of this stack
    add     bx, cx                              
    cmp     word [bx], 1
    je      .sp_is_active
    add     cx, 2                               ; next stack to search
    and     cx, 0x2F                            ; make sure stack to search is always less than 64
    jmp     .sp_loop_for_active_stack
.sp_is_active:
    mov     [current_task], cx
    lea     bx, [stack_pointers]                ; get the location of the stack pointers
    add     bx, [current_task]                  ; get the location of the current stack pointer
    mov     sp, [bx]
.sp_none_active:
    popa
	; Chain (i.e., jump) to the original INT 8 handler 
	jmp	far [cs:ivt8_offset]	; Use CS as the segment here, since who knows what DS is now

;assumes vga mode is already set and es is set to A0000
;accepts the memory address of an image struc in bx as a parameter
global displayQuadImage
displayQuadImage:
	;save all registers
	pusha
	;set allPurposeCounter to 0
	mov dword [allPurposeCounter], 0
	;mov the address of the colMap and posMap into regs
	lea dx, [bx + quadImage.colMap]
	lea cx, [bx + quadImage.posMap]
;loop through the posmap until the address equals the address of the colmap
.loopPix:
	;check if the current posMap address is equal to the starting address of colMap
	cmp cx, dx
	;if yes, jump out of loop
	je .completePix
	;get the posmap byte
	mov bx, cx
	mov bx, [bx]
	;mov upper half into ax and multiply by 320
	movzx ax, bh
	mov bp, 320
	mul bp
	;add lower half of coordinate reg (x-value) and mov it into bp
	movzx bx, bl
	add bx, ax
	mov bp, [bx]
	;get color byte
	mov bx, dx
	mov bx, [bx]
	add bx, [allPurposeCounter]
	mov ax, [bx]
	;display to screen
	mov     [es:bp], ax
	;increase memory address for cx and increment counter
	add cx, 8
	add dword [allPurposeCounter], 8
	jmp .loopPix
.completePix:
	ret

; takes a char to print in dx
; no return value
; putchar:
; 	mov     ax, dx          ; call interrupt x10 sub interrupt xE
; 	mov     ah, 0x0E
; 	mov     cx, 1
; 	int     0x10
; 	ret

;takes an address to write to in di
;writes to address until a newline is encountered
;returns nothing
; putstring:
; 	cmp     byte [di], 0        ; see if the current byte is a null terminator
; 	je     	.done 				; nope keep printing
; .continue:
; 	mov     dl, [di]            ; grab the next character of the string
; 	mov     dh, 0               ; print it
; 	call    putchar
; 	inc     di                  ; move to the next character
; 	jmp     putstring
; .done:
; 	ret

mutex:
    push    ax
    mov     ax, 0
    jmp     .try
.loop:
    int     0x8
.try:
    xchg    [mutex_v], ax                        ; when ax is 1, we got the lock so move one
    cmp     ax, 0
    je      .loop                                ; loop while ax is 0, we didn't get the lock
    pop     ax
    ret

release:
    push    ax
    mov     ax, 1
    xchg    [mutex_v], ax                        ; set mutex_v back to 1 so someone else can grab the lock
    pop     ax
    int     0x8
    ret

SECTION .data
	rect_a_x: dw 0
	rect_b_x: dw 0
	rect_c_x: dw 0
	rect_d_x: dw 0

    keypress: db 0

	ivt8_offset	 dw	0
	ivt8_segment dw	0

	ivt9_offset	 dw	0
	ivt9_segment dw	0

	allPurposeCounter: dq 0

	;create six empty well strucs at six positions
	grav_one:
        dw 0x64
        db 0x32
        db 0
    grav_two:
        dw 0xC8
        db 0x32
        db 0
    grav_three:
        dw 0x96
        db 0x64
        db 0
    grav_four:
        dw 0xFA
        db 0x64
        db 0
    grav_five:
        dw 0x64
        db 0x96
        db 0
    grav_six:
        dw 0xC8
        db 0x96
        db 0

	;gravity well sprites
	grav_sprite:
		dw 0
		db 0
		TIMES 4 dq 0x9537CA
		TIMES 4 dq 0x0B0B0B

	;energy sprites
	;quadImage

	mutex_v: dw 1

	current_task: dw 0 ; must always be a multiple of 2
	stacks: times (256 * 4) db 0 ; 31 fake stacks of size 256 bytes
	task_status: times 5 dw 0 ; 0 means inactive, 1 means active
	stack_pointers: dw 0 ; the first pointer needs to be to the real stack !
                %assign i 1
                %rep    4
                    dw stacks + (256 * i)
                %assign i i+1
                %endrep
