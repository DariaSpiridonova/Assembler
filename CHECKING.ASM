.model tiny
.code
org 100h
start:
    mov ax, 0AAAAh
    mov bx, 0BBBBh
    mov cx, 0CCCCh
    mov dx, 0DDDDh
    mov si, 1111h
    mov di, 2222h
    mov bp, 3333h
    
    jmp $ ; «вечный цикл»
end start