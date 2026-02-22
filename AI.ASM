.model tiny
.code
org 100h

Start:
    call GetArgs

    call CheckParams
    
    call CalculateStartPoz
  
    call ConfigureVideoMemory

    call CleanWindow

    mov si, dx
    call DisplayFrame
    call PrintText 
    
    call MoveCursorDown

    jmp  Exit


;***********************************************************************************************
; Function for getting the string's length from PSP:80h
; Pointer adjusts to the beginning of the line.
;
; Returns: 
;        CL : string's length without initial spaces (if length = 0 the program is ending)
;        DX : the pointer to the begining of the string
;        BX : frame's width
;        AX : frame's height
;***********************************************************************************************

GetArgs proc

    ; 1. Getting length
    mov bx, 80h
    mov cl, [bx]
    cmp cl, 0
    je StopProgram          ; Exit, if there are no arguments
    
    ; 2. Skip initial spaces and adjust the pointer on the begining of the text
    mov si, 81h        

    call SkipSpaces 
    mov dx, si ; DX points to the begining of the string
    mov TEXT_BEGIN, dx

find_digits:
    lodsb
    cmp al, 0Dh     ; Конец строки в PSP
    je SetDefault 
    cmp al, '0'
    jb find_digits
    cmp al, '9'
    ja find_digits
    
    ; Found the first digit 
    dec si

    mov ax, si 
    sub ax, dx 
    dec ax
    mov cl, al 

    call ReadNumber ; width
    mov bx, ax
    
    call SkipSpaces
    cmp byte ptr [si], 0Dh  ; Если высоты нет в строке
    je SetDefaultHeight
    call ReadNumber         ; Читаем высоту
    ret

SetDefault:
    push bx
    mov bx, 80h
    mov cl, byte ptr ds:[bx]
    pop bx
    dec cl
SetDefaultHeight:
    mov bx, 40
    mov ax, 10
    ret
GetArgs endp
StopProgram:
    mov ax, 4c00h   
    int 21h 

;***********************************************************************************************
; Function for reading the number: a parameter of the frame
;
; Expects:
;        SI : the pointer to the first digit of the number
; Returns: 
;        AX : frame's parameter
;***********************************************************************************************

ReadNumber proc near
    push cx
    push dx
    push bx

    xor bx, bx          ; for result
    xor cx, cx          ; for working with a digit
    xor ax, ax

next_digit:
    lodsb            
    
    cmp al, '0'
    jb done            
    cmp al, '9'
    ja done             

    ; symbol -> number
    sub al, '0'        
    mov cl, al          

    mov ax, bx          
    mov dx, 10
    mul dx              ; AX = AX * 10 
    add ax, cx          
    
    mov bx, ax          
    jmp next_digit      

done:
    mov ax, bx
    pop bx
    pop dx
    pop cx
    ret
ReadNumber endp

;***********************************************************************************************
; Function for skiping spaces in input string between arguments
;
; Expects:
;        SI : the pointer to the string
; Returns: 
;        SI : the pointer to the begining of the argument
;***********************************************************************************************

SkipSpaces proc

b:
    lodsb
    cmp al, ' '
    je b ; @b = Jump Backward
    dec si
    ret

SkipSpaces endp

;***********************************************************************************************
; Function for configuring videomemory
;
; Returns: 
;        SI : the pointer to the begining of the videomemory
;***********************************************************************************************

ConfigureVideoMemory proc
    push ax
    mov ax, 0B800h
    mov es, ax
    pop ax

    ret
ConfigureVideoMemory endp 

;***********************************************************************************************
; Function for displaying frame with text inside
;
; Expects:
;        SI : the pointer to the string
;        CL : string's length without initial spaces
; Returns: 
;        SI : the pointer to the begining of the argument
;***********************************************************************************************

DisplayFrame proc
    mov di, START_POZ
    cld
    
    ; Сохраним длину в BX для расчетов, а CX подготовим для циклов
    xor ch, ch          ; Теперь CX = точная длина текста
    mov bx, cx          ; BX = длина текста
    mov STR_LEN, bx

    ; --- РИСУЕМ ВЕРХНЮЮ ГРАНИЦУ ---
    mov al, 0DAh        ; Символ '┌'
    mov ah, 1Fh         ; Атрибут: белый на черном
    stosw               ; Рисуем угол
    
    mov cx, WID
    mov al, 0C4h        ; Символ '─'
    rep stosw           ; Рисуем линию длиной CX
    
    mov al, 0BFh        ; Символ '┐'
    stosw
    
    mov cx, FRAME_HEIGHT
    sub cx, 2

draw_side_walls:
    push cx

    call NextLine

    mov ah, 1Fh         ; Атрибут: белый на черном
    mov al, 0B3h        ; Символ '│'
    stosw               ; Левая стенка

    mov cx, WID          

    mov al, 219d        ; Закрашенный прямоугольник    
    mov ah, 03h         ; Цвет
    rep stosw           ; Пишем в видеопамять закрашенные прямоугольники
    
    mov ah, 1Fh         ; Атрибут: белый на черном
    mov al, 0B3h        ; Символ '│'
    stosw               ; Правая стенка
    pop cx
    loop draw_side_walls

    call NextLine

    ; --- РИСУЕМ НИЖНЮЮ ГРАНИЦУ ---
    mov ah, 1Fh         ; Атрибут: белый на черном
    mov al, 0C0h        ; Символ '└'
    stosw
    
    mov cx, WID
    mov al, 0C4h        ; Символ '─'
    rep stosw
    
    mov al, 0D9h        ; Символ '┘'
    stosw

    ret
DisplayFrame endp

;***********************************************************************************************
; Function for printing text in the center of the frame
;
; Expects:
;        SI : the pointer on the begining of the text
;        BX : string's length
; Returns: 
;        SI : the pointer on the symbol after string
;        DI : the cell number of the symbol from SI
;***********************************************************************************************

PrintText proc

    push ax 
    push bx 
    push dx 

    mov ax, FRAME_HEIGHT
    shr ax, 1       

    mov bx, 160      
    mul bx 
    mov di, START_POZ
    add di, ax
    add di, FRAME_WIDTH
    sub di, STR_LEN

    pop dx 
    pop bx
    pop ax

    mov si, TEXT_BEGIN
    push si             
    mov cx, bx          
    jcxz skip_t
draw_text:
    lodsb               ; Берем символ из DS:SI
    mov ah, 0Fh         ; Цвет
    stosw               ; Пишем в видеопамять
    loop draw_text
skip_t:
    pop si              

    ret 
PrintText endp

;***********************************************************************************************
; Function for checking frame's parameters
;
; Expects:
;        BX : frame's width
;        AX : frame's height
;        CX : string's length
; Returns: 
;        BX : correct width  (>= 3)
;        AX : correct height (>= 3)
;        CX : correct length (<= frame's width - 2)
;***********************************************************************************************

CheckParams proc 
    cmp bx, 3 
    ja store_width
    mov bx, 3
store_width:
    cmp ax, 3 
    ja store_height
    mov ax, 3
store_height:
    mov FRAME_WIDTH, bx
    mov FRAME_HEIGHT, ax
    sub bx, 2
    sub ax, 2

    mov WID, bx 
    mov HEI, ax
    
    cmp cx, WID
    jbe store_len
    mov cx, WID
store_len:
    ret
CheckParams endp

;***********************************************************************************************
; Function for switching to a new line 
;
; Expects:
;        DI : the pointer on the current position
; Returns: 
;        DI : the pointer to a new line directly below the previous position
;***********************************************************************************************

CalculateStartPoz proc 
    push ax
    mov ax, 25
    sub ax, FRAME_HEIGHT    
    shr ax, 1               
    mov bx, 80
    mul bx                  
    
    mov bx, 80
    sub bx, FRAME_WIDTH     
    shr bx, 1
    add ax, bx
    
    shl ax, 1               
    mov START_POZ, ax
    pop ax

    ret
CalculateStartPoz endp
;***********************************************************************************************
; Function for switching to a new line 
;
; Expects:
;        DI : the pointer on the current position
; Returns: 
;        DI : the pointer to a new line directly below the previous position
;***********************************************************************************************

NextLine proc 
    add di, 160
    push ax
    mov ax, WID
    add ax, 2
    shl ax, 1
    sub di, ax
    pop ax
    ret 
NextLine endp

;***********************************************************************************************
; Function for cleaning the window for beaty output
;
; Expects:
;        -
; Returns: 
;        -
;***********************************************************************************************

CleanWindow proc
    push ax
    mov ax, 0003h
    int 10h
    pop ax
    ret
CleanWindow endp


;***********************************************************************************************
; Function for moving cursor under the frame
;
; Expects:
;        -
; Returns: 
;        -
; Spoils :
;        AH, BH, DX
;***********************************************************************************************

MoveCursorDown proc
    mov ah, 02h 
    mov bh, 0 
    mov dh, 22
    mov dl, 22
    int 10h
    ret 
MoveCursorDown endp

;***********************************************************************************************
; Completion of the program
;***********************************************************************************************

Exit:
    mov ax, 4c00h   
    int 21h

;***********************************************************************************************
; Variables
;***********************************************************************************************

FRAME_WIDTH  dw 3
FRAME_HEIGHT dw 3
WID          dw 1
HEI          dw 1
NUM_OF_CELLS dw 1
START_POZ    dw 0
TEXT_BEGIN   dw 0
STR_LEN      dw 0

end Start
