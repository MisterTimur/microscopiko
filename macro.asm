
LOW_MEMORY       equ $00200000  ; Нижняя граница общей памяти
START_MEM        equ $01000000  ; 10 мб стартовая память
HI_STACK         equ $001A0000  ; Стек 0-го кольца

; ----------------------------------------------------------------------

PIC1             equ 0x20   ; IO базовый адрес для master PIC */
PIC2             equ 0xA0   ; IO базовый адрес для slave PIC */
PIC1_COMMAND     equ PIC1
PIC1_DATA        equ (PIC1+1)
PIC2_COMMAND     equ PIC2
PIC2_DATA        equ (PIC2+1)

PIC_EOI          equ 0x20   ; End-of-interrupt command code */

ICW1_ICW4        equ 0x01   ; ICW4 (not) needed */
ICW1_SINGLE      equ 0x02   ; Single (cascade) mode */
ICW1_INTERVAL4   equ 0x04   ; Call address interval 4 (8) */
ICW1_LEVEL       equ 0x08   ; Level triggered (edge) mode */
ICW1_INIT        equ 0x10   ; Initialization - required! */

ICW4_8086        equ 0x01   ; 8086/88 (MCS-80/85) mode */
ICW4_AUTO        equ 0x02   ; Auto (normal) EOI */
ICW4_BUF_SLAVE   equ 0x08   ; Buffered mode/slave */
ICW4_BUF_MASTER  equ 0x0C   ; Buffered mode/master */
ICW4_SFNM        equ 0x10   ; Special fully nested (not) */

; PIC1
IRQ_TIMER        equ 0x01
IRQ_KEYB         equ 0x02
IRQ_CASCADE      equ 0x04
IRQ_FDC          equ 0x40

; PIC2
IRQ_PS2MOUSE     equ 0x10

; ----------------------------------------------------------------------

macro brk { xchg bx, bx }

macro IRQ_master a {
    push    dword [a]
    jmp     near irq.master
}

macro IRQ_slave a {
    push    dword [a]
    jmp     near irq.slave
}

; Обработчик прерывания
macro IRQ_handler slave {

    pusha
    mov     ebp, esp
    call    dword [ebp + $20]
    mov     al, PIC_EOI
    out     PIC1, al
    if slave
    out     PIC2, al
    end if
    popa
    add     esp, 4
    iretd

}
