.model tiny             
.code 
org 100h                

VIDEO   equ     0b800h
Start:

    call ConfigureVideoMemory
    call SuggestStyles
    call ChooseStyle

    call CleanWindow

    call DisplaySelectedFrame
    call PrintStringInTheFrame

    call MoveCursorDown

    jmp Exit                    

SuggestStyles:
    mov ah, 09h
    mov dx, offset STYLE_SUGGESTIONS
    int 21h
    ret

ConfigureVideoMemory:
    mov ax, VIDEO
    mov es, ax
    ret

ChooseStyle:
    mov ah, 01h
    int 21h

    ret

CleanWindow:
    push ax
    mov ax, 0003h 
    int 10h
    pop ax
    ret

DisplaySelectedFrame:
    cmp al, FIRST_STYLE
    je DisplayTheFirstFrame

    cmp al, SECOND_STYLE
    je DisplayTheSecondFrame

    ;cmp al, THIRD_STYLE
    ;je DisplayTheThirdFrame

    ret

DisplayTheFirstFrame:
    mov bx, VB_START1

    call DisplayFrame
    ret

DisplayTheSecondFrame:
    mov bx, VB_START1
    mov ATTR, 0FDh
    mov ANGLE1,    177
    mov ANGLE2,    177
    mov ANGLE3,    177
    mov ANGLE4,    177
    mov HOR_LINE,  177
    mov VERT_LINE, 177

    call DisplayFrame
    
    ret

DisplayTheThirdFrame:

    ret

DisplayFrame:
    mov ah, ATTR
    mov al, ANGLE1 ; Угол ╔
    mov es:[bx], ax
    
    add bx, 2
    mov cx, FRAME_W1 - 2
top_line:
    mov al, 205                 ; Линия ═
    mov es:[bx], ax
    add bx, 2
    loop top_line
    
    mov al, ANGLE2                 ; Угол ╗
    mov es:[bx], ax

    ; --- 2. БОКОВЫЕ СТЕНКИ ---
    mov cx, FRAME_H1 - 2
    mov bx, VB_START1 + 160
side_walls:
    push bx
    mov al, VERT_LINE                 ; Линия ║
    mov es:[bx], ax             ; Левая
    add bx, (FRAME_W1 - 1) * 2
    mov es:[bx], ax             ; Правая
    pop bx
    add bx, 160
    loop side_walls

    ; --- 3. НИЖНЯЯ ГРАНИЦА ---
    mov al, ANGLE3                 ; Угол ╚
    mov es:[bx], ax
    add bx, 2
    mov cx, FRAME_W1 - 2
bottom_line:
    mov al, HOR_LINE                 ; Линия ═
    mov es:[bx], ax
    add bx, 2
    loop bottom_line
    
    mov al, ANGLE4                 ; Угол ╝
    mov es:[bx], ax

    ret

PrintStringInTheFrame:

    mov ah, 02h ; перевод курсора на нужную позицию
    mov bh, 0 
    mov dh, 12
    mov dl, 30
    int 10h

    mov cx, 20

display_symbol:
    mov ah, 01h         ; ввод с эхом (символ появится там, где стоит курсор)
    int 21h
    cmp al, 0dh
    je stop
    loop display_symbol

stop:
    ret

MoveCursorDown:
    mov ah, 02h 
    mov bh, 0 
    mov dh, 20
    mov dl, 20
    int 10h

Exit:
    mov ax, 4c00h   
    int 21h

; --- КОНСТАНТЫ (размещаем в конце, чтобы не мешали коду) ---
VB_START1  equ (9 * 160) + (20 * 2) ; Строка 9, Столбец 20 (центр)
VB_START2  equ (8 * 160) + (19 * 2) ; Строка 8, Столбец 19 (центр)

FRAME_W1   equ 40
FRAME_H1   equ 7
FRAME_W2   equ 42
FRAME_H2   equ 9

ATTR      db 1Fh               ; Белый на синем 

ANGLE1    db  0C9h
ANGLE2    db  187
ANGLE3    db  200
ANGLE4    db  188

HOR_LINE  db  205
VERT_LINE db  186

FIRST_STYLE  equ '1'
SECOND_STYLE equ '2'
THIRD_STYLE  equ '3'

BUFFER_FOR_STYLE_NUMBER db 3
BUF_LEN                 db 0
BUF_NUMBER              db 5

STYLE_SUGGESTIONS  db "Please, choose the number of a style:", 0dh, 0ah
                   db "1. Style 1", 0dh, 0ah
                   db "2. Style 2", 0dh, 0ah
                   db "3. Style 3", 0dh, 0ah, "$"

end Start
