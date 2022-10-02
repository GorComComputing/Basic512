; Интерпретатор BASIC
%TITLE 			"BASIC"
				IDEAL
				MODEL	TINY	; Модель памяти для COM-файлов. 64К, все сегменты в одном
				DATASEG
vars			EQU 7E00h	; Переменные (a-z)
running			EQU 7E7Eh	; Указатель на строчку, которая сейчас выполняется
line			EQU 7E80h	; Строчка программы, которую напечатал программист
program			EQU 7F00h	; Указатель на буфер для исходника программы
;stack			EQU 0FF00h	; Адрес стека
max_line		EQU 1000	; Максимальное количество строчек в программе
max_length		EQU 20		; Максимальная длина строчки программы
max_size		EQU max_line*max_length

statements		DB 3,"new"
				DW start_bas
				DB 4,"list"
				DW list_handler
				DB 3,"run"
				DW run_handler
				DB 5,"print"
				DW print_handler
				DB 5,"input"
				DW input_handler
				DB 2,"if"
				DW if_handler
				DB 4,"goto"
				DW goto_handler
				DB 0

;basic1			DB "BASIC v.1.0 (c) 2022 Gor.Com",0

				CODESEG
				ORG 100h		; Начало выполнения ядра здесь
Start:			; Вывод рамки

; BASIC #############################################################################
;PROC			doBasic
				; Вывод строки
				;lea		si,[basic1]
				;call	WriteLn
start_bas:				
				cld
				mov		di,program
				mov		al,0Dh
				mov		cx,max_size
				rep		stosb
main_loop_bas:	
				xor		ax,ax
				mov		[running],ax	; Обнуляем счетчик команд
				mov		al,'>'			; Рисуем приглашение ввода ">"
				call	input_line		; Ждем команду от пользователя
				call	dec_str_to_number
				or		ax,ax			; Строчка начинается с числа?
				je		no_save
				call	find_address	; Вычисляем адрес, куда сохранить строчку
				xchg	ax,di
				mov		cx,max_length
				rep		movsb			; Сохраняем введенную строчку в программу
				jmp		main_loop_bas
				
no_save:								; Интерактивная обработка
				call	execute_statement
				jmp		main_loop_bas
				
if_handler:	
				call	process_expr
				or		ax,ax
				je		to_ret
execute_statement:
				call	skip_spaces
				cmp		[Byte Ptr si],0Dh
				je		to_ret
				
				lea		di,[statements]
next_entry:
				mov		cl,[di]
				mov		ch,0
				test	cx,cx
				je		to_get_var
				
				push	si
				
				inc		di
				rep		cmpsb
				jne		no_equal
				
				pop		ax
				call	skip_spaces
				
				jmp		[Word Ptr di]
no_equal:
				add		di,cx
				inc		di
				inc		di
				pop		si
				jmp		next_entry

to_get_var:
				call	get_var
				push	ax
				lodsb
				cmp		al,'='
				je		assign

output_error:
				lea		si,[error_message]
				call	print_2
				jmp		main_loop_bas
				
error_message	DB "Error!",0Dh

list_handler:
				xor		ax,ax
next_line:
				push	ax
				call	find_address
				xchg	ax,si
				cmp		[Byte Ptr si],0Dh
				je		empty_line
				pop		ax
				push	ax
				call	output_number
next_char:
				lodsb
				call	output_char
				cmp		al,0Dh
				jne		next_char
empty_line:
				pop		ax
				inc		ax
				cmp		ax,max_line
				jne		next_line
to_ret:
				ret
				
input_handler:
				call	get_var
				push	ax
				mov		al,'?'
				call	input_line
				
assign:
				call	process_expr
				pop		di
				stosw
				ret
				
process_expr:
				call	expr2_left
next_sub_add:
				cmp		[Byte Ptr si],'-'
				je		to_op_sub
				cmp		[Byte Ptr si],'+'
				jne		to_ret
				push	ax
				call	expr2_right
				
				pop		cx
				add		ax,cx
				jmp		next_sub_add
to_op_sub:
				push	ax
				call	expr2_right
				pop		cx
				xchg	ax,cx
				sub		ax,cx
				jmp		next_sub_add
				
expr2_right:
				inc		si
expr2_left:
				call	expr3_left
next_div_mul:
				cmp		[Byte Ptr si],'/'
				je		to_op_div
				cmp		[Byte Ptr si],'*'
				jne		to_ret
				
				push	ax
				call	expr3_right
				
				pop		cx
				imul	cx
				jmp		next_div_mul
to_op_div:
				push	ax
				call	expr3_right
				pop		cx
				imul	cx
				jmp		next_div_mul
;to_op_div:
				push	ax
				call	expr3_right
				pop		cx
				xchg	ax,cx
				cwd
				idiv	cx
				jmp		next_div_mul
				
expr3_right:
				inc		si
expr3_left:	
				call	skip_spaces
				lodsb
				cmp		al,'('
				jne		not_par
				call	process_expr
				cmp		[Byte Ptr si],')'
				jne		output_error_2
				jmp		skip_spaces_2
				
output_error_2:
				lea		si,[error_message]
				call	print_2
				jmp		main_loop_bas
				
not_par:
				cmp		al,40h
				jnc		yes_var
				dec		si
				
				call	dec_str_to_number
				jmp		skip_spaces
yes_var:
				call	get_var_2
				xchg	ax,bx
				mov		ax,[bx]
				ret
				
get_var:
				lodsb
get_var_2:
				and		al,1Fh
				add		al,al
				mov		ah,7Eh
				
skip_spaces:
				cmp		[Byte Ptr si],' '
				jne		skip_complete
skip_spaces_2:
				inc		si
				jmp		skip_spaces
				
output_number:
				xor		dx,dx
				mov		cx,10
				div		cx
				or		ax,ax
				push	dx
				je		to_output_char
				call	output_number
to_output_char:
				pop		ax
				add		al,'0'
				jmp		output_char
				
dec_str_to_number:
				xor		bx,bx
to_next_digit:
				lodsb
				sub		al,'0'
				cmp		al,10
				cbw
				xchg	ax,bx
				jnc		not_digit
				mov		cx,10
				mul		cx
				add		bx,ax
				jmp		to_next_digit

not_digit:
				dec		si
skip_complete:
				ret
				
run_handler:
				xor		ax,ax
				jmp		to_goto
goto_handler:
				call	process_expr
to_goto:
				call	find_address
				cmp		[Word Ptr running],0
				je		to_next_line
				mov		[running],ax
				ret
to_next_line:
				push	ax
				pop		si
				add		ax,max_length
				mov		[running],ax
				call	execute_statement
				mov		ax,[running]
				cmp		ax,program+max_size
				jne		to_next_line
				ret
				
find_address:
				mov		cx,max_length
				mul		cx
				add		ax,program
				ret

input_line:
				call	output_char
				mov		si,line
				push	si
				pop		di
another_key:
				call	input_key
				cmp		al,08h
				jne		no_back
				dec		di
				jmp		another_key
				
no_back:
				stosb
				cmp		al,0Dh
				jne		another_key
				ret
				
print_handler:
				lodsb
				cmp		al,0Dh
				je		new_line
				cmp		al,'"'
				jne		no_quote
print_2:
next_char1:
				lodsb
				cmp		al,'"'
				je		to_semicolon
				call	output_char
				cmp		al,0Dh
				jne		next_char1
				ret
				
no_quote:
				dec		si
				call	process_expr
				call	output_number
to_semicolon:
				lodsb
				cmp		al,';'
				jne		new_line
				ret

input_key:
				mov		ah,00h
				int		16h
				
output_char:
				cmp		al,0Dh
				jne		to_show
new_line:
				mov		al,0Ah
				call	to_show
				mov		al,0Dh
to_show:
				mov		ah,0Eh
				int		10h
				ret
				

				END Start
				
				
				
				;lea	si,[program]
				;call	WriteLn
				;ret
;ENDP			doBasic