
        org     8000h

        include "macro.asm"

; Вход в защищенный режим
; ----------------------------------------------------------------------

        cli
        cld
        mov     ax, $0003
        int     10h                 ; Текстовый видеорежим
        lgdt    [GDTR]              ; Глобальная дескрипторная таблица
        lidt    [IDTR]              ; Таблица прерываний
        mov     eax, cr0
        or      al,  1
        mov     cr0, eax
        jmp     10h : pm            ; Переход в PM

; ----------------------------------------------------------------------
GDTR:   dw 4*8 - 1                  ; Лимит GDT (размер - 1)
        dq GDT                      ; Линейный адрес GDT
IDTR:   dw 256*8 - 1                ; Лимит GDT (размер - 1)
        dq 0                        ; Линейный адрес GDT
; ----------------------------------------------------------------------
GDT:    dw 0,      0,    0,     0   ; 00 NULL-дескриптор
        dw 0FFFFh, 0, 9200h, 00CFh  ; 08 32-битный дескриптор данных
        dw 0FFFFh, 0, 9A00h, 00CFh  ; 10 32-bit код
        dw 103,  TSS, 8900h, 0040h  ; 18 Свободный TSS
; ----------------------------------------------------------------------

        use32

        include "core.asm"
        include "device/fdc.asm"
        include "device/ata.asm"

        ; Установка сегментов данных
pm:     mov     ax, $0008
        mov     ds, ax
        mov     es, ax
        mov     ss, ax
        
        mov     esp, $8000        
        call    irq_init            ; Средиректить IRQ
        call    ivt_init            ; Инициализировать IVT
        call    tss_init            ; Запустить TSS
        call    dev_init            ; Устройства
        call    mem_init            ; Страничная память
        call    gdt_init            ; Новое место GDT
        call    fdc_init            ; Создать кеш fd-диска
        mov     esp, HI_STACK       ; Новый стек

        mov     [$b8000], word $1F50

        sti
        mov     ax, 0
        call    fdc_read

        jmp     $

        ; Обращения к FDC
        ; Загрузка задачи в память
        ; Мультизадачное выполнение

; ----------------------------------------------------------------------

        include "var.asm"
