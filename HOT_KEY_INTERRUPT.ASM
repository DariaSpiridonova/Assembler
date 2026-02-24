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
            push ax bx es ds

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
            push 0b800h
			pop es

		    mov bx, (5*80d + 40d) * 2
		    mov ah, 4eh
            
            mov es: [bx], ax

    		in al, 61h 
		    or al, 80h
            out 61h, al 
            and al, not 80h ; стираем старший бит
            out 61h, al 

            mov al, 20h
            out 20h, al 

            pop ds es bx ax 
            iret

HotKeyActive  db 0
Skip:
            pop ds es bx ax 
            db 0eah             ; JMP FAR 
Old09Ofs    dw 0 
Old09Seg    dw 0 
            
New09       endp


EndOfProgram:
end		Start
