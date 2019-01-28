
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

        ; Установка прерываний... нужно ли?
        ;not     ebx
        ;in      al, PIC1_DATA
        ;and     al, bl
        ;out     PIC1_DATA, al
        ;in      al, PIC2_DATA
        ;and     al, bh
        ;out     PIC2_DATA, al

        ret

.data:

    db  PIC1_COMMAND, ICW1_INIT + ICW1_ICW4
    db  PIC2_COMMAND, ICW1_INIT + ICW1_ICW4
    db  PIC1_DATA,    0x20
    db  PIC2_DATA,    0x28
    db  PIC1_DATA,    0x04
    db  PIC2_DATA,    0x02
    db  PIC1_DATA,    ICW4_8086
    db  PIC2_DATA,    ICW4_8086
    db  PIC1_DATA,    0xFF ; xor (IRQ_TIMER)
    db  PIC2_DATA,    0xFF

; Инициализация IVT
; ----------------------------------------------------------------------
ivt_init:

    ret
