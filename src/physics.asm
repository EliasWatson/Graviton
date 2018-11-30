global gravity

section .text

; First  vector: (ax, bx)
; Second vector: (cx, dx)
; Returns force in ax
gravity:
    ; (ax - cx)
    FLD ax
    FSUB cx
    FST ax

    ; (bx - dx)
    FLD bx
    FSUB dx
    FST bx
    
    call vector_length_squared

    ; (1 / length_squared)
    FLD1
    FDIV ax
    FST ax
    ret

; Returns (ax^2 + bx^2) in ax
vector_length_squared:
    ; ax ^ 2
    FLD ax
    FMUL ax
    FST ax

    ; bx ^ 2
    FLD bx
    FMUL bx

    ; (ax^2 + bx^2)
    FADD ax
    FST ax
    ret
