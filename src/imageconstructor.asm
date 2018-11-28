bits 16

org 0x100

;all images are 16x16 pixels

;creates an image struc with max 16 pixels
struc wordImage
	;the coordinates (on the dosbox display) of the upper left corner of the image
    .x_coord: dw 0
    .y_coord: db 0
    ;the position of each pixel in the image relative to the top left corner. For each byte: lower half: x, higher half: y
    .posMap: TIMES 2 dq 0
	;each byte is the color of the pixel in the same byte of posMap
	.colMap:	TIMES 2 dq 0
    .size:
endstruc

;creates an image struc with max 32 pixels
struc quadImage
	;the coordinates (on the dosbox display) of the upper left corner of the image
    .x_coord: dw 0
    .y_coord: db 0
    ;the position of each pixel in the image relative to the top left corner. For each byte: lower half: x, higher half: y
    .posMap: TIMES 4 dq 0
	;each byte is the color of the pixel in the same byte of posMap
	.colMap:	TIMES 4 dq 0
    .size:
endstruc

;creates an image struc with max 64 pixels
struc octImage
	;the coordinates (on the dosbox display) of the upper left corner of the image
    .x_coord: dw 0
    .y_coord: db 0
    ;the position of each pixel in the image relative to the top left corner. For each byte: lower half: x, higher half: y
    .posMap: TIMES 8 dq 0
	;each byte is the color of the pixel in the same byte of posMap
	.colMap:	TIMES 8 dq 0
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
	mov [allPurposeCounter], 0
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
	;mov upper half into bx and multiply by 320
	mov [bx], [cx]
	mov ax, [bx]
	mov [bx], bh
	mov ax, bx
	mov bp, 320
	mul bp
	mov [bx], ax
	mov bp, bx
	;add lower half of coordinate reg (x-value)
	add bp, al
	;get color byte
	mov [bx], dx
	add [bx], [allPurposeCounter]
	mov ax, [bx]
	;display to screen
	mov     [es:bp], ax
	;increase memory address for cx and increment counter
	add cx, 8
	add [allPurposeCounter], 8
	jmp .loopPix
.completePix

section .data
	allPurposeCounter: dq 0