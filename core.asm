
; Простановка редиректов
; ----------------------------------------------------------------------

irq_init:

        ; Выполнение запросов
        mov     ecx, 10
        xor     edx, edx
        mov     esi, .data
@@:     lodsw
        mov     dl, al
        mov     al, ah
        out     dx, al
        jcxz    $+2
        jcxz    $+2
        loop    @b
        ret

.data:  ; Данные для отправки команд
        db      PIC1_COMMAND, ICW1_INIT + ICW1_ICW4
        db      PIC2_COMMAND, ICW1_INIT + ICW1_ICW4
        db      PIC1_DATA,    0x20
        db      PIC2_DATA,    0x28
        db      PIC1_DATA,    0x04
        db      PIC2_DATA,    0x02
        db      PIC1_DATA,    ICW4_8086
        db      PIC2_DATA,    ICW4_8086
        db      PIC1_DATA,    0xFF xor (IRQ_TIMER or IRQ_KEYB)
        db      PIC2_DATA,    0xFF

; Инициализация IVT
; Для IRQ используются "обертки" - устанавливаются ссылки в .irq_X
; ----------------------------------------------------------------------

ivt_init:

        ; Очистка IVT
        mov     eax, .null
        xor     edi, edi
        mov     ecx, 256
@@:     call    .make
        loop    @b

        ; Установка ссылок на обработчики IRQ #n
        mov     cx, 16
        mov     eax, .it0
        mov     edi, $20 shl 3
@@:     call    .make
        add     eax, .it1 - .it0
        loop    @b
        ret

.make:  ; eax - адрес прерывания, edi - адрес ivt
        mov     [edi+0], eax
        mov     [edi+4], eax
        mov     [edi+2], dword $8E000010
        add     edi, 8
        ret

; Ошибка вызова несуществующего прерывания. Ничегошеньки не делать.
.null:  iretd

; Обработчики IRQ #n
.it0:   IRQ_master .irq_0
.it1:   IRQ_master .irq_1
        IRQ_master .irq_2
        IRQ_master .irq_3
        IRQ_master .irq_4
        IRQ_master .irq_5
        IRQ_master .irq_6
        IRQ_master .irq_7
        IRQ_slave  .irq_8
        IRQ_slave  .irq_9
        IRQ_slave  .irq_A
        IRQ_slave  .irq_B
        IRQ_slave  .irq_C
        IRQ_slave  .irq_D
        IRQ_slave  .irq_E
        IRQ_slave  .irq_F

; Ссылки на обработчики IRQ
.irq_0: dd irq.timer
.irq_1: dd irq.keyb
.irq_2: dd irq.nil
.irq_3: dd irq.nil
.irq_4: dd irq.nil
.irq_5: dd irq.nil
.irq_6: dd irq.nil
.irq_7: dd irq.nil
.irq_8: dd irq.nil
.irq_9: dd irq.nil
.irq_A: dd irq.nil
.irq_B: dd irq.nil
.irq_C: dd irq.nil
.irq_D: dd irq.nil
.irq_E: dd irq.nil
.irq_F: dd irq.nil

; ----------------------------------------------------------------------
irq:

.timer:
        inc     [irq_timer]
        ret

.keyb:  
        in      al, $60
        ret

.nil:   ret        

; Два типа общих обработчиков
.master: IRQ_handler 0
.slave:  IRQ_handler 1

; Инициализация главной TSS
; ----------------------------------------------------------------------

tss_init:

        mov     [TSS.iobp], word 104
        mov     ax, 18h
        ltr     ax
        ret

; Инициализация важных устройств
; ----------------------------------------------------------------------

dev_init:

        mov     [irq_timer], 0

        ; Часы на 100 мгц
        mov     al, $34
        out     $43, al
        mov     al, $9b
        out     $40, al
        mov     al, $2e
        out     $40, al
        ret

; Поиск размера памяти и установка страниц -> TSS.cr3
; ----------------------------------------------------------------------

mem_init:

        ; Размер памяти
        mov     ecx, 32             ; Бинарный поиск на 2^32
        mov     esi, $00100000
        mov     edi, $dfffffff
.rept:  mov     ebx, esi            ; ebx = (esi + edi) >> 1
        add     ebx, edi
        rcr     ebx, 1
        mov     al, [ebx]           ; Тест изменений
        xor     [ebx], byte $55
        cmp     [ebx], al
        cmove   edi, ebx            ; Уменьшить верхнюю
        cmovne  esi, ebx            ; Увеличить нижнюю
        mov     [ebx], al
.next:  loop    .rept
        mov     [mem_size], edi     ; Тут будет верхняя граница

        ; Разметка PDBR
        mov     ecx, edi
        shr     ecx, 22             ; Кол-во 4-мб страниц
        mov     edi, $100000        ; Очистить PDBR
        push    edi ecx
        mov     ecx, 1024
        xor     eax, eax
        rep     stosd
        pop     ecx edi
        mov     eax, $101003        ; Каталоги c правами R/W=1, P=1
@@:     stosd
        add     eax, $1000
        loop    @b

        ; Разметка каталогов
        mov     ecx, [mem_size]
        shr     ecx, 12
        mov     edi, $101000
        mov     eax, $000003
@@:     stosd
        add     eax, $1000
        loop    @b

        ; Включение страничной организации
        mov     eax, $00100000
        mov     cr3, eax
        mov     [TSS.cr3], eax      ; Записать адрес PDBR
        mov     eax, cr0
        or      eax, $80000000
        mov     cr0, eax            ; Переключить на страницы
        jmp     $+2
   
        ; Локальная память для задач ядра
        mov     [dynamic], edi 
        ret

; Перенос GDT в другое место
; ----------------------------------------------------------------------

gdt_init:

        ret
