bits 16

org 0x100

;all images are 16x16 pixels

;creates an image struc with max 16 pixels
struc wordImage
	;the coordinates (on the dosbox display) of the upper left corner of the image
    .x_coord: resw 0
    .y_coord: resb 0
    ;the position of each pixel in the image relative to the top left corner. For each byte: lower half: x, higher half: y
    .posMap: TIMES 2 resq 0
	;each byte is the color of the pixel in the same byte of posMap
	.colMap:	TIMES 2 resq 0
    .size:
endstruc

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
struc octImage
	;the coordinates (on the dosbox display) of the upper left corner of the image
    .x_coord: resw 0
    .y_coord: resb 0
    ;the position of each pixel in the image relative to the top left corner. For each byte: lower half: x, higher half: y
    .posMap: TIMES 8 resq 0
	;each byte is the color of the pixel in the same byte of posMap
	.colMap:	TIMES 8 resq 0
    .size:
endstruc

SECTION .text

;assumes vga mode is already set and es is set to A0000
;accepts the memory address of an image struc in bx as a parameter
global displayWordImage
displayWordImage:
	;save all registers
	pusha
	;set allPurposeCounter to 0
	mov dword [allPurposeCounter], 0
	;mov the address of the colMap and posMap into regs
	lea dx, [bx + wordImage.colMap]
	lea cx, [bx + wordImage.posMap]
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

section .data
	allPurposeCounter: dd 0