.model tiny
.code
org 100h
start:

    call RequestAPassword 
    call GoToTheNewLine 

    call EnterAPassword
    call GoToTheNewLine

    cmp ax, 0
    je access_den 
    call AccessGranted 
    jmp Exit
    
access_den:
    call AccessDenied  
Exit:
    mov ax, 4c00h
	int 21h

;***********************************************************************************************
; Function for displaying a password prompt
;
; Expects:
;        -
; Returns: 
;        -
; Spoils :
;        AH
;        DX
;***********************************************************************************************
RequestAPassword proc 
    mov ah, 09h
    mov dx, offset REQUEST
    int 21h

    ret
RequestAPassword endp

;***********************************************************************************************
; Function for comparing entering password with correct
;
; Expects:
;        -
; Returns: 
;        -
; Spoils :
;        DL
;***********************************************************************************************
GoToTheNewLine proc 
    push ax
    mov ah, 02h
    mov dl, 0Dh
    int 21h
    mov ah, 02h
    mov dl, 0Ah
    int 21h
    pop ax

    ret
GoToTheNewLine endp 

;***********************************************************************************************
; Function for comparing entering password with correct
;
; Expects:
;        -
; Returns: 
;        DI - the address of the beginning of the password buffer
; Spoils :
;        SI
;        AL
;        SP
;***********************************************************************************************
EnterAPassword proc 
    push bp          
    mov  bp, sp
    sub  sp, 10 

    lea si, [bp-10] 
    mov bx, si      ; Сохраним начало пароля в BX, чтобы не потерять

cont_input:
    mov ah, 01h     
    int 21h
    cmp al, 0Dh     
    je end_input
    mov [si], al    
    inc si          
    jmp cont_input

end_input:
    mov byte ptr [si], '$'

    ; 1. Вывод того, что ввели
    call GoToTheNewLine
    mov di, offset RECEIVING
    mov si, bx               ; Передаем адрес из стека
    call OutputReceivedPassword 

    ; 2. Сравнение
    mov di, bx               ; Адрес в стеке
    mov si, offset CORRECT_PASSWORD
    call CheckCorrectness
    
    mov sp, bp          
    pop bp              
    ret
EnterAPassword endp 

;***********************************************************************************************
; Function for displaying the entered password
;
; Expects:
;        DI - introduction
;        SI - the address of the password
; Returns: 
;        -
; Spoils :
;        DX
;        AH
;***********************************************************************************************
OutputReceivedPassword proc
    mov ah, 09h
    mov dx, di
    int 21h

    mov ah, 09h 
    mov dx, si
    int 21h

    ret
OutputReceivedPassword endp

;***********************************************************************************************
; Function for comparing entering password with correct
;
; Expects:
;        DI - the address of the entering password
;        SI - the address of the correct  password
; Returns: 
;        AX - failure (0) or success (1)
; Spoils :
;        DI
;        SI
;        CX
;        BL
;***********************************************************************************************
CheckCorrectness proc
compare:
    mov al, [di]
    mov bl, [si]
    cmp al, bl
    jne access_denied_ 
    cmp al, '$'
    je access_granted_ 
    inc di 
    inc si 
    jmp compare

access_denied_:
    mov ax, 0
    ret
access_granted_:
    mov ax, 1

    ret
CheckCorrectness endp 

;***********************************************************************************************
; Function for comparing entering password with correct
;
; Expects:
;        ;DX - the address of the string "Access denied$"
; Returns: 
;        -
; Spoils :
;        DX
;        AH
;***********************************************************************************************
AccessDenied proc 
    mov ah, 09h 
    mov dx, offset ACCESS_DENIED 
    int 21h 
    mov ax, 4c00h
	int 21h

    ret
AccessDenied endp 

;***********************************************************************************************
; Function for reporting the denial of access
;
; Expects:
;        ;DX - the address of the string "Access granted$"
; Returns: 
;        -
; Spoils :
;        DX
;        AH
;***********************************************************************************************
AccessGranted proc
    mov ah, 09h 
    mov dx, offset ACCESS_GRANTED 
    int 21h 
    mov ax, 4c00h
	int 21h

    ret
AccessGranted endp 

REQUEST db "Please, enter the password to grant access$"
RECEIVING db "You have entered the following password: $"
PASSWORD dw 0
CORRECT_PASSWORD db 'plumplum$'
ACCESS_DENIED db "Access denied$"
ACCESS_GRANTED db "Access granted$"
end start