
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
        IRQ_master .irq_8
        IRQ_master .irq_9
        IRQ_master .irq_A
        IRQ_master .irq_B
        IRQ_master .irq_C
        IRQ_master .irq_D
        IRQ_master .irq_E
        IRQ_master .irq_F

; Ссылки на обработчики IRQ
.irq_0: dd irq.timer
.irq_1: dd irq.master
.irq_2: dd irq.master
.irq_3: dd irq.master
.irq_4: dd irq.master
.irq_5: dd irq.master
.irq_6: dd irq.master
.irq_7: dd irq.master
.irq_8: dd irq.slave
.irq_9: dd irq.slave
.irq_A: dd irq.slave
.irq_B: dd irq.slave
.irq_C: dd irq.slave
.irq_D: dd irq.slave
.irq_E: dd irq.slave
.irq_F: dd irq.slave

; ----------------------------------------------------------------------
irq:

.timer: inc     [irq_timer]
        ret

.keyb:  in      al, $60
        ret

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

        brk

        ; Топ памяти ядра находится тут
        mov     [dynamic], $100000

        ret
