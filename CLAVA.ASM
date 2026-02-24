.286
.model tiny
.code
org 100h

Start: 		
		push 0b800h
		pop es

		mov bx, (5*80d + 40d) * 2
		mov ah, 4ch

		in al, 60h ; polling
		mov cl, al 
Next:
		in al, 60h ; polling
		cmp cl, al 
		je Continue
		mov cl, al
		inc ah
		add bx, 2 
Continue: 
		mov es: [bx], ax
		
		cmp al, 1
		jne Next

		mov ax, 4c00h
		int 21h

end		Start
