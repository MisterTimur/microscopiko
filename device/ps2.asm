
; Инициализация
ps2_init:

        mov     ah, $A8
        call    kb_cmd
        call    kb_read
        mov     ah, $20
        call    kb_read
        push    ax
        mov     ah, $60
        call    kb_cmd
        pop     ax
        or      al, 3
        call    kb_write        
        mov     ah, $D4         ; Отослать команду для PS/2 разрешение
        call    kb_cmd
        mov     al, $F4
        call    kb_write
        call    kb_read
        ret

; Ожидание ответа с порта $64, параметр AH - маска
; Если AL=0, все в порядке, иначе ошибка
; ----------------------------------------------------------------------
kb_wait:

        mov     ecx, 65536
@@:     in      al, $64
        and     al, ah
        loopnz  @b
        ret

; Ожидание установки бита 1 в $64
; Если AL > 0, все в порядке, иначе ошибка
; ----------------------------------------------------------------------

kb_wait_not:

        mov     ecx, 8*65536
@@:     in      al, $64
        and     al, 1
        loopz   @b
        ret

; Отправить команду AH=comm
; ----------------------------------------------------------------------

kb_cmd: xchg    ah, bh
        mov     ah, 2
        call    kb_wait
        mov     al, bh
        out     $64, al
        mov     ah, 2
        call    kb_wait
        ret

; Запись команды AL
; ----------------------------------------------------------------------

kb_write:

        mov     bl, al
        mov     ah, 0x20
        call    kb_wait         ; Ожидание готовности
        in      al, $60         ; Чтение данных из порта (не имеет значения)
        mov     ah, $02
        call    kb_wait         ; Ждать для записи
        mov     al, bl
        out     $60, al         ; Записать данные
        mov     ah, $02
        call    kb_wait         ; Ждать для записи
        call    kb_wait_not     ; Подождать, пока будет =1 на чтение
        ret

; Прочитать данные
; ----------------------------------------------------------------------

kb_read:

        call    kb_wait_not
@@:     mov     ecx, 65536
        loop    @b
        in      al, $60
        ret