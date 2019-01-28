
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
        db      PIC1_DATA,    0xFF ; xor (IRQ_TIMER)
        db      PIC2_DATA,    0xFF

; Инициализация IVT
; ----------------------------------------------------------------------

ivt_init:

        mov     eax, .null
        xor     edi, edi
        mov     ecx, 256
@@:     call    .make
        loop    @b

        ; ...

        ret

.make:  ; eax - адрес прерывания, edi - адрес ivt
        mov     [edi+0], eax
        mov     [edi+4], eax
        mov     [edi+2], dword $8E000010
        add     edi, 8
        ret

; Ошибка вызова несуществующего прерывания. Ничегошеньки не делать.
.null:  iretd

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

        mov     al, $34
        out     $43, al
        mov     al, $9b
        out     $40, al
        mov     al, $2e
        out     $40, al
        ret
