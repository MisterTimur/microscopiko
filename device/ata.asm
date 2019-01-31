
; Порты
ATA_REG_DATA        equ 0
ATA_REG_ERR         equ 1
ATA_REG_COUNT       equ 2
ATA_REG_SEC_NUM     equ 3
ATA_REG_LBA_LO      equ 3
ATA_REG_LBA_MID     equ 4
ATA_REG_LBA_HI      equ 5
ATA_REG_DEVSEL      equ 6
ATA_REG_CMD         equ 7

; Типы устройств
DISK_DEV_UNKNOWN    equ 0
DISK_DEV_PATAPI     equ 1
DISK_DEV_SATAPI     equ 2
DISK_DEV_PATA       equ 3
DISK_DEV_SATA       equ 4
DISK_DEV_FLOPPY     equ 5

; Шины
ATA_PRIMARY         equ $1F0
ATA_SECONDARY       equ $170

macro ata_iowait {

    repeat 4
    in      al, dx          ; iowait
    end repeat
}

; Ответ: ZF=0 ошибка, ZF=1 ошибок нет
; ----------------------------------------------------------------------

ata_soft_reset:

        mov     al, 4
        mov     bx, [ata.base]        
        lea     dx, [bx + ATA_REG_DEVSEL + $200]
        out     dx, al          ; do a "software reset" on the bus
        mov     al, 0
        out     dx, al          ; reset the bus to normal operation
        ata_iowait
        mov     ecx, 4096
@@:     in      al, dx
        and     al, $c0
        cmp     al, $40         ; если BSY=0, RDY=1 - все ОК
        loopnz  @b              ; ждать, пока не будет $40
@@:     ret

; Выбор устройства для работы
; BX = (1F0, 170)
; BX = 3F0 (primary), BX=slave)
; ----------------------------------------------------------------------

ata_drive_select:

        ; Выбор устройства
        mov     al, [ata.slave]
        and     al, 1
        shl     al, 4
        or      al, $A0 or $40  ; 0x40=Set LBA Bit
        lea     dx, [bx + ATA_REG_DEVSEL + $200]
        out     dx, al
        lea     dx, [bx + ATA_REG_DEVSEL + $200]
        ata_iowait
        ret

; Определение типа устройства на шине
; dx - тип устройства
; ----------------------------------------------------------------------

ata_detect_devtype:

        ; Сброс контроллера
        call    ata_soft_reset
        mov     dx, DISK_DEV_UNKNOWN
        jne     @f

        ; Получение данных
        call    ata_drive_select
        mov     bx, [ata.base]
        lea     dx, [bx + ATA_REG_LBA_MID]
        in      al, dx
        mov     ah, al
        inc     dx
        in      al, dx

        ; Определение типов
        mov     dx, DISK_DEV_PATAPI
        cmp     ax, $145B
        je      @f
        mov     dx, DISK_DEV_SATAPI
        cmp     ax, $6996
        je      @f
        mov     dx, DISK_DEV_PATA
        and     ax, ax
        je      @f
        mov     dx, DISK_DEV_SATA
        cmp     ax, $3cc3
        je      @f
        mov     dx, DISK_DEV_UNKNOWN

        ; Получение ответа
@@:     ret        

