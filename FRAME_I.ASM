.286
.model tiny
.code
org 100h

Start: 	    mov ax, 3509h
            int 21h
            mov Old09Ofs, bx 
            mov bx, es 
            mov Old09Seg, bx 

        	push 0 ; указание на самое начало оперативки: отсюда начинается таблица прерываний
		    pop es

            ; запрещаем аппаратные прерывания IF = 0
            cli

            mov bx, 09h * 4 ; 4 - размер ячейки
            mov es: [bx], offset New09 ; записали в таблицу прерываний смещение
            mov ax, cs 
            mov es: [bx + 2], ax ; младшие разряды - es: [bx], старшие - сегментная часть es: [bx + 2]

            sti ; IF = 1

            mov ax, 3100h
            mov dx, offset EndOfProgram
            mov cl, 4
            shr dx, cl 
            inc dx ; +16 byte 
            int 21h ; теперь прога будет выполняться только если её вызовет обработчик прерываний 

New09       proc 
            pusha                 ; push ax cx dx bx sp bp si di
            push es ds

            in al, 60h

            cmp al, 3Bh 
            jne CheckCurrent

            mov cs: [HotKeyActive], 1
            jmp DisplayNewKey

CheckCurrent:
            cmp al, 0BBh        ; 3Bh + 80h = BBh
            jne CheckOthers
            mov cs: [HotKeyActive], 0
            jmp DisplayNewKey

CheckOthers:
            cmp cs: [HotKeyActive], 1
            jne Skip

DisplayNewKey:
            call CalculateStartPoz
            call ConfigureVideoMemory
            ; call CleanWindow

            call DisplayFrame

            mov  bp, sp
            mov  cx, 12          
            mov  bx, 22          

            call PrintRegisters
            
            ; call MoveCursorDown

		    call BlinkHighBit
            
            call CompleteProcForIController
            
            pop ds es 
            popa               ; pop di si bp sp ds bx dx cx ax 
            iret

Skip:
            pop ds es
            popa               ; pop di si bp sp ds bx dx cx ax 
            db 0eah             ; JMP FAR 
Old09Ofs    dw 0 
Old09Seg    dw 0 
            
;***********************************************************************************************
; Function for printing all registers
;
; Expects:
;        BP : stack pointer
;        CX : number of registers without ss
;        BX : the initial stack offset for the ip register 
; Returns: 
;        -
;***********************************************************************************************

PrintRegisters proc   
            push cs
            pop  ds             ; Чтобы lodsb видел RegNames
            mov  si, offset RegNames

            push 0b800h
            pop  es
            call CalculateStartPoz
            add  di, 164        ; Первая строка внутри рамки, отступ 2 знака
NextRegCycle:
            push cx
            

            ; ... (вывод имени) ...
            mov  ah, 3Fh        ; Цвет текста
            lodsb               
            stosw
            lodsb               
            stosw
            
            ; --- Печатаем ": " ---
            mov  ax, 3F3Ah      ; ':'
            stosw
            mov  ax, 3F20h      ; ' '
            stosw

            push si 
            mov si, bx
            mov  dx, ss:[bp + si] ; Берем значение
            pop si 
            call PrintDX_Hex
            
            ; --- ПЕРЕХОД НА НОВУЮ СТРОКУ ---
            add  di, 160
            sub  di, 16

            
            sub  bx, 2           ; Спускаемся
            
            pop  cx
            loop NextRegCycle

            ; Вывод ss
            mov  ah, 3Fh
            mov  al, 's'
            stosw
            stosw               
            
            mov  ax, 3F3Ah      ; ':'
            stosw
            mov  ax, 3F20h      ; ' '
            stosw

            mov  dx, ss         
            call PrintDX_Hex    

            ret
PrintRegisters endp

;***********************************************************************************************
; Function for configuring videomemory
;
; Returns: 
;        ES : the pointer to the begining of the videomemory
;***********************************************************************************************

ConfigureVideoMemory proc
    push ax
    mov ax, 0B800h
    mov es, ax
    pop ax

    ret
ConfigureVideoMemory endp 

;***********************************************************************************************
; Function for displaying frame without text inside
;
; Expects:
;        SI : the pointer to the string
;        CL : string's length without initial spaces
;        DI : the cell of the upper-left corner of the frame 
; Returns: 
;        SI : the pointer to the begining of the argument
;***********************************************************************************************

DisplayFrame proc
    cld
    
    ; --- РИСУЕМ ВЕРХНЮЮ ГРАНИЦУ ---
    mov al, 0DAh        ; Символ '┌'
    mov ah, 1Fh         ; Атрибут: белый на черном
    stosw               ; Рисуем угол
    
    mov cx, 12
    mov al, 0C4h        ; Символ '─'
    rep stosw           ; Рисуем линию длиной CX
    
    mov al, 0BFh        ; Символ '┐'
    stosw
    
    mov cx, 15
    sub cx, 2

draw_side_walls:
    push cx

    call NextLine

    mov ah, 1Fh         ; Атрибут: белый на черном
    mov al, 0B3h        ; Символ '│'
    stosw               ; Левая стенка

    mov cx, 12          

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
    
    mov cx, 12
    mov al, 0C4h        ; Символ '─'
    rep stosw
    
    mov al, 0D9h        ; Символ '┘'
    stosw

    ret
DisplayFrame endp

;***********************************************************************************************
; Function for representing a 16-digit number as a string and printing in videomemory
;
; Expects:
;        DX : register's value
; Returns: 
;        -
;***********************************************************************************************

PrintDX_Hex proc
    push cx ax bx
    mov cx, 4          ; 4 знака в 16-битном числе
@@loop:
    rol dx, 4          ; Крутим DX: верхние 4 бита уходят вниз
    mov al, dl
    and al, 0Fh        ; Оставляем только эти 4 бита в AL
    
    add al, '0'        ; Пробуем сделать цифру (0-9)
    cmp al, '9'
    jbe @@is_digit
    add al, 7          ; Коррекция для букв A-F
@@is_digit:
    mov ah, 3Fh        ; Цвет (желтый на синем)
    stosw              ; ПЕЧАТАЕМ В ВИДЕОПАМЯТЬ
    loop @@loop
    
    pop bx ax cx
    ret
PrintDX_Hex endp

;***********************************************************************************************
; Function for calculating start pozition 
;
; Expects:
;        -
; Returns: 
;        DI : the cell of the upper-left corner of the frame 
;***********************************************************************************************

CalculateStartPoz proc 
    push ax
    mov ax, 25
    sub ax, 12     ; FRAME_HEIGHT    
    shr ax, 1               
    mov bx, 80
    mul bx                  
    
    mov bx, 80
    sub bx, 8      ; FRAME_WIDTH     
    shr bx, 1
    add ax, bx
    
    shl ax, 1               
    mov di, ax
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
    mov ax, 12
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
; Function for confirming the processing of a scanned code for the Keyboard Controller
;
; Expects:
;        -
; Returns: 
;        -
; Spoils :
;        AL
;***********************************************************************************************

BlinkHighBit proc
    in al, 61h 
    or al, 80h
    out 61h, al 
    and al, not 80h ; стираем старший бит
    out 61h, al 

    ret 
BlinkHighBit endp

;***********************************************************************************************
; Function for sending a signal EOI to Interrupt Controller
;
; Expects:
;        -
; Returns: 
;        -
; Spoils :
;        AL
;***********************************************************************************************

CompleteProcForIController proc
    mov al, 20h
    out 20h, al

    ret 
CompleteProcForIController endp

;***********************************************************************************************
; Variables
;***********************************************************************************************

RegNames db 'ipcsaxcxdxbxspbpsididses'
HotKeyActive db 0
         
New09       endp


EndOfProgram:
end		Start
