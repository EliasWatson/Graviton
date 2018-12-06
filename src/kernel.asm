bits 16

org 0

; Where to find the INT 8 handler vector within the IVT [interrupt vector table]
IVT8_OFFSET_SLOT	equ	4 * 8			; Each IVT entry is 4 bytes; this is the 8th
IVT8_SEGMENT_SLOT	equ	IVT8_OFFSET_SLOT + 2	; Segment after Offset

IVT9_OFFSET_SLOT	equ	4 * 9
IVT9_SEGMENT_SLOT	equ	IVT9_OFFSET_SLOT + 2


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
    ;mov ax, 0x0C73
    ;mov bx, 0x0
	;mov cx, [rect_b_x]
    ;mov dx, 100
    ;int 0x10

    ;cmp byte [keypress], 0x1E
    ;jne .key_a_exit
    ;    inc word [rect_b_x]
    ;.key_a_exit:
    
    ;cmp byte [keypress], 0x20
    ;jne .key_d_exit
    ;    dec word [rect_b_x]
    ;.key_d_exit:

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

	current_task: dw 0 ; must always be a multiple of 2
	stacks: times (256 * 4) db 0 ; 31 fake stacks of size 256 bytes
	task_status: times 5 dw 0 ; 0 means inactive, 1 means active
	stack_pointers: dw 0 ; the first pointer needs to be to the real stack !
                %assign i 1
                %rep    4
                    dw stacks + (256 * i)
                %assign i i+1
                %endrep
