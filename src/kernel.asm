bits 16

org 0x0

; Where to find the INT 8 handler vector within the IVT [interrupt vector table]
IVT8_OFFSET_SLOT	equ	4 * 8			        ; Each IVT entry is 4 bytes; this is the 8th
IVT8_SEGMENT_SLOT	equ	IVT8_OFFSET_SLOT + 2	; Segment after Offset

; Where to find the INT 9 handler vector within the IVT [interrupt vector table]
IVT9_OFFSET_SLOT	equ	4 * 9
IVT9_SEGMENT_SLOT	equ	IVT9_OFFSET_SLOT + 2

SECTION .text
main:
    ; ds = cs
	mov		ax, cs
	mov 	ds, ax

    ; Reset es
	mov	ax, 0x0000
	mov	es, ax
	
    ; Replace interrupts
	cli
	mov ax, [es:IVT8_OFFSET_SLOT]
    mov [ivt8_offset], ax
    mov ax, [es:IVT8_SEGMENT_SLOT]
    mov [ivt8_segment], ax
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
	sti

    ; Set VGA mode
	mov     ah, 0x0
	mov     al, 0x13
	int     0x10

	mov     word [task_status], 1   ; set main task to active

	lea     di, [render_player]     ; create graphics thread
	call    spawn_new_task

	lea     di, [control_player]    ; create player thread
	call    spawn_new_task

	lea     di, [rect_1]     ; create gravity wells thread
	call    spawn_new_task

	lea     di, [rect_2]      ; create task b
	call    spawn_new_task

	mov     ax, 0xA000
	mov     es, ax                  ; set memory to vga position

.loop_forever_main:
    ; Main does nothing
	jmp     .loop_forever_main	

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
    cmp     cx, 10
	jl      .sp_loop_for_available_stack
	mov		cx, 0
    jmp     .sp_loop_for_available_stack
.sp_is_available:
	lea     bx, [task_status]                   ; we found a stack, set it to active
	add     bx, cx
	mov     word [bx], 1
	lea     bx, [stack_pointers]                ; switch to the fake stack so we can do stuff with it
	add     bx, cx
	mov     sp, [bx]                            ; swap stacks
	pushf                                       ; emulate an interrupt, which pushes flags
    push    cs                                  ; then a segment
    push    di                                  ; then an address (just so happens to be the address of the function we want to run)
    pusha
	lea     bx, [stack_pointers]                ; update top of this stack
	add     bx, cx
	mov     [bx], sp
.sp_no_available_stack:                         ; restore to original stack
	lea     bx, [stack_pointers]
	add     bx, [current_task]
	mov     sp, [bx]
	ret

;environment graphics thread
render_player:
.loop_forever_1:
    ; Setup interrupt arguments
    mov ax, 0x0C3F
    mov bx, 0x0
	mov cx, [player_x]
    mov dx, [player_y]

    ; Draw 3x3 at player position
    %rep 3
    int 0x10
    inc cx
    %endrep

	mov cx, [player_x]
    inc dx
    %rep 3
    int 0x10
    inc cx
    %endrep

	mov cx, [player_x]
    inc dx
    %rep 3
    int 0x10
    inc cx
    %endrep
    
	jmp     .loop_forever_1

;player thread
control_player:
.loop_forever_2:
    ; Check for keystroke
    cmp byte [keypress], 0
	je .loop_forever_2

    ; 0x1E - A Down
    ; 0x9E - A Up
    cmp byte [keypress], 0x1E
    jne .key_a_exit
        dec word [player_x]
    .key_a_exit:
    
    ; 0x20 - D Down
    ; 0xA0 - D Up
    cmp byte [keypress], 0x20
    jne .key_d_exit
        inc word [player_x]
    .key_d_exit:
    
    ; 0x11 - W Down
    ; 0x91 - W Up
    cmp byte [keypress], 0x11
    jne .key_w_exit
        inc byte [player_y]
    .key_w_exit:

    ; 0x1F - S Down
    ; 0x9F - S Up
    cmp byte [keypress], 0x1F
    jne .key_s_exit
        dec byte [player_y]
    .key_s_exit:

	jmp     .loop_forever_2

rect_1:
.loop_forever_3:
    ; Draw rectangle #1
    mov ax, 0x0C2F
    mov bx, 0x0
    mov cx, [rect_a_x]
    mov dx, 0x0
    int 0x10

    inc word [rect_a_x]
    and word [rect_a_x], 0x3F
    jmp     .loop_forever_3

rect_2:
.loop_forever_4:
    ; Draw rectangle #2
    mov ax, 0x0C73
    mov bx, 0x0
    mov cx, [rect_b_x]
    mov dx, 0x2
    int 0x10

    inc word [rect_b_x]
    and word [rect_b_x], 0x3F
    jmp .loop_forever_4

; Custom keyboard interrupt
keyboard_int:
    push ax

    in al, 0x60
    mov [keypress], al
    mov al, 0x20
    out 0x20, al

    pop ax
    iret

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
    cmp     cx, 10
	jl      .sp_loop_for_active_stack
	mov		cx, 0
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

    player_x: dw 0
    player_y: db 0

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
