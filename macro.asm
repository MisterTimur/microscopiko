
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
; FDC
; ----------------------------------------------------------------------

; Порты
STATUS_REGISTER_A                equ 0x3F0  ; read-only
STATUS_REGISTER_B                equ 0x3F1  ; read-only
DIGITAL_OUTPUT_REGISTER          equ 0x3F2
TAPE_DRIVE_REGISTER              equ 0x3F3
MAIN_STATUS_REGISTER             equ 0x3F4  ; read-only
DATARATE_SELECT_REGISTER         equ 0x3F4  ; write-only
DATA_FIFO                        equ 0x3F5
DIGITAL_INPUT_REGISTER           equ 0x3F7  ; read-only
CONFIGURATION_CONTROL_REGISTER   equ 0x3F7  ; write-only

; Команды
READ_TRACK                      equ 2  ; generates IRQ6
SPECIFY                         equ 3  ; * set drive parameters
SENSE_DRIVE_STATUS              equ 4
WRITE_DATA                      equ 5  ; * write to the disk
READ_DATA                       equ 6  ; * read from the disk
RECALIBRATE                     equ 7  ; * seek to cylinder 0
SENSE_INTERRUPT                 equ 8  ; * ack IRQ6, get status of last command
WRITE_DELETED_DATA              equ 9
READ_ID                         equ 10 ; generates IRQ6
READ_DELETED_DATA               equ 12
FORMAT_TRACK                    equ 13
DUMPREG                         equ 14
SEEK                            equ 15 ; * seek both heads to cylinder X
VERSION                         equ 16 ; * used during initialization, once
SCAN_EQUAL                      equ 17
PERPENDICULAR_MODE              equ 18 ; * used during initialization, once, maybe
CONFIGURE                       equ 19 ; * set controller parameters
LOCK                            equ 20 ; * protect controller params from a reset
VERIFY                          equ 22
SCAN_LOW_OR_EQUAL               equ 25
SCAN_HIGH_OR_EQUAL              equ 29

; Статусы
FDC_STATUS_NONE                 equ 0x0
FDC_STATUS_SEEK                 equ 0x1
FDC_STATUS_RW                   equ 0x2
FDC_STATUS_SENSEI               equ 0x3

; ----------------------------------------------------------------------

macro brk {
    xchg bx, bx
}

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

; Чтение регистра в память
macro FDCREAD m {

    call    fdc_read_reg
    mov     [m], al
}
