; https://wiki.osdev.org/ATA_PIO_Mode

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

; Инициализация 4 типов устройств
; ----------------------------------------------------------------------
ata_init:

        mov     esi, .drives
        mov     edi, ata.types
        mov     ecx, 4
.rept:  push    ecx
        lodsw
        mov     [ata.base], ax
        lodsw
        mov     [ata.slave], al
        call    ata_detect_devtype
        stosb
        and     al, al
        je      .next

        ; Если AL != Unknown
        push    edi
        call    ata_drive_select
brk
        ; Отправка команды IDENTIFY
        mov     bx, [ata.base]
        lea     dx, [bx + ATA_REG_COUNT]
        xor     eax, eax
        repeat 4            ; ATA_REG_COUNT
        out     dx, al      ; ATA_REG_LBA_LO
        inc     dx          ; ATA_REG_LBA_MID
        end repeat          ; ATA_REG_LBA_HI
        inc     dx
        mov     al, 0xEC
        out     dx, al      ; ATA_REG_CMD
        in      al, dx      ; Если тут AL = 0, это ошибка
        and     al, al
        je      .next

        mov     ecx, 32768  ; Ожидание готовности
@@:     in      al, dx
        and     al, $80
        loopnz  @b

        ; Выделить новую память
        mov     edi, [dynamic]          ; верх
        mov     ebx, [.idptr]
        mov     [ebx], edi              ; запись указателя
        lea     eax, [edi + 512]
        mov     [dynamic], eax          ; новая позиция верха

        ; Запись данных в память
        mov     dx, [ata.base]
        mov     ecx, 256
        rep     insw
        pop     edi

        ; Следующий identify
.next:  add     [.idptr], 4
        pop     ecx
        dec     ecx
        jne    .rept
        ret

.drives:

        dw      $1F0, 0         ; Pri/Master
        dw      $1F0, 1         ; Pri/Slave
        dw      $170, 0         ; Sec/Master
        dw      $170, 1         ; Sec/Slave
.idptr  dd      ata.identify

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
        shl     al, 4
        or      al, $A0 or $40  ; 0x40=Set LBA Bit
        lea     dx, [bx + ATA_REG_DEVSEL]
        out     dx, al
        or      dx, $200
        ata_iowait
        ret

; Определение типа устройства на шине => AL
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
        cmp     ax, 0x145B
        je      @f
        mov     dx, DISK_DEV_SATAPI
        cmp     ax, 0x6996
        je      @f
        mov     dx, DISK_DEV_PATA
        and     ax, ax
        je      @f
        mov     dx, DISK_DEV_SATA
        cmp     ax, 0x3CC3
        je      @f
        mov     dx, DISK_DEV_UNKNOWN
@@:     movzx   eax, dx
        ret


; Ждать ответа от диска
; ZF=1 Успех, ZF=0 Ошибка
; ----------------------------------------------------------------------

ata_wait_response:

        mov     bx, [ata.base]
        lea     dx, [bx + ATA_REG_CMD]
        mov     ecx, 32768
@@:     in      al, dx
        and     al, $EF
        cmp     al, $48     ; DRQ=1, ERR=0, CORR=0, IDX=0, RDY=1, DF=0
        loopnz  @b
        ret

; Подготовка устройства к запросу на чтение или запись
; ----------------------------------------------------------------------

; Задано param:  data.lba, ata.count
; al - 0x24 READ | 0x34 WRITE

ata_prepare_lba:

        push    ax

        ; AL = 0xA0 | 0x40 | (device_id & 1) << 4 | ((lba >> 24) & 0xF)
        mov     al, [ata.slave]
        shl     al, 4
        or      al, $A0 or $40
        mov     ah, byte [ata.lba + 3]
        and     ah, 0x0F
        or      al, ah
        mov     bx, [ata.base]
        lea     dx, [bx + ATA_REG_DEVSEL]
        out     dx, al
        or      dx, $200
        ata_iowait

        ; Первая часть
        lea     dx, [bx + ATA_REG_COUNT]
        mov     al, byte [ata.count + 1]
        out     dx, al  ; (count >> 8)
        inc     dx
        mov     al, byte [ata.lba + 3]
        out     dx, al  ; ATA_REG_LBA_LO  (lba>>24)
        inc     dx
        mov     al, 0
        out     dx, al  ; ATA_REG_LBA_MID
        inc     dx
        out     dx, al  ; ATA_REG_LBA_HI

        ; Вторая часть
        lea     dx, [bx + ATA_REG_COUNT]
        mov     al, byte [ata.count]
        out     dx, al
        inc     dx
        mov     al, byte [ata.lba + 0]
        out     dx, al  ; ATA_REG_LBA_LO  (lba >> 8)
        inc     dx
        mov     al, byte [ata.lba + 1]
        out     dx, al  ; ATA_REG_LBA_MID (lba >> 8)
        inc     dx
        mov     al, byte [ata.lba + 2]
        out     dx, al  ; ATA_REG_LBA_HI  (lba >> 16)
        inc     dx
        pop     ax

        ; Отправка команды
        lea     dx, [bx + ATA_REG_CMD]
        out     dx, al

        ; Ждать ответа
        call    ata_wait_response
        je      @f
        mov     [ata.error], al
@@:     ret

; Читать сектор EAX в $1000
; ----------------------------------------------------------------------

; Чтение
ata_pio_read:

        mov     [ata.error], 0
        mov     [ata.lba], eax
        mov     [ata.count], 1
        mov     al, $24
        call    ata_prepare_lba
        jnz     @f
        mov     dx, [ata.base]
        mov     ecx, 256
        mov     edi, $1000
        rep     insw
@@:     ret


; Запись сектора EAX в $1000
; ----------------------------------------------------------------------

ata_pio_write:

        mov     [ata.error], 0
        mov     [ata.lba], eax
        mov     [ata.count], 1
        mov     al, $24
        call    ata_prepare_lba
        jnz     @f
        mov     dx, [ata.base]
        mov     ecx, 256
        mov     esi, $1000
        rep     outsw
@@:     ret
