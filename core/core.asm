
; Простановка редиректов
; ----------------------------------------------------------------------

irq_redirect:

        ; Выполнение запросов
        mov     ecx, 10
        xor     edx, edx
        mov     esi, irq_redirect.data
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
        db      PIC1_DATA,    0xFF xor (IRQ_TIMER)
        db      PIC2_DATA,    0xFF

; Инициализация IVT
; ----------------------------------------------------------------------

ivt_init:

        ; Очистка IVT
        mov     eax, .null
        xor     edi, edi
        mov     ecx, 256
@@:     call    .make
        loop    @b

        ; Установка обработчиков IRQ
        mov     cx, 1
        mov     esi, .irq
@@:     movzx   edi, byte [esi]
        inc     esi
        lodsd
        shl     edi, 3
        call    .make
        loop    @b
        ret

.make:  ; eax - адрес прерывания, edi - адрес ivt
        mov     [edi+0], eax
        mov     [edi+4], eax
        mov     [edi+2], dword $8E000010
        add     edi, 8
        ret

.irq:   IRQitem $20, irq.timer

; Ошибка вызова несуществующего прерывания. Ничегошеньки не делать.
.null:  iretd

; Важные системные прерывания
; ----------------------------------------------------------------------

irq:

.timer: pusha
        inc     [irq_timer]
        mov     al, $20
        out     $20, al
        popa
        iretd

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
