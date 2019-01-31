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

; Чтение регистра в память
macro FDCREAD m {

    call    fdc_read_reg
    mov     [m], al
}

macro FDCWRI m {

    mov     al, m
    call    fdc_write_reg
}

; Ожидать готовность IRQ
macro FDCREADY {

@@:     cmp     [fdc.ready], 0
        je      @b
}

; Кеш флоппи-диска в памяти
; Инициализация каналов DMA для FDC
; ----------------------------------------------------------------------

fdc_init:

        ; Выделение памяти
        mov     edi, [dynamic]
        mov     [fdcache_mask], edi
        add     edi, 360
        mov     [fdcache_data], edi
        add     edi, 1474560
        mov     [dynamic], edi

        ; Очистка 360 байт x 8 = 2880 секторов
        mov     edi, [fdcache_mask]
        mov     ecx, 360 shr 2
        xor     eax, eax
        rep     stosd

        ; Установка DMA
        mov     al, $06
        out     $0A, al ; Маскирование DMA channel 2 и 0

        ; Адрес
        mov     al, $FF
        out     $0C, al ; Сброс master flip-flop
        mov     al, $00
        out     $04, al ; [7:0]
        mov     al, $10
        out     $04, al ; [15:8]

        ; Размер
        mov     al, $FF
        out     $0C, al ; Сброс master flip-flop
        mov     al, $FF
        out     $05, al ; [7:0]
        mov     al, $3F
        out     $05, al ; [15:8]

        ; Адрес
        mov     al, $00
        out     $81, al ; [23:16]
        mov     al, $02
        out     $0A, al ; Размаскировать DMA channel 2

        ; Инициализация
        mov     [fdc.motor], 0
        mov     [fdc.ready], 0
        ret

; ----------------------------------------------------------------------

; Подготовить диск на чтение
fdc_dma_read:

        mov     al, $06 ; mask DMA channel 2 and 0 (assuming 0 is already masked)
        out     $0A, al
        mov     al, $56
        out     $0B, al ; 01010110 single transfer, address increment, autoinit, read, channel2)
        mov     al, $02
        out     $0A, al ; unmask DMA channel 2
        ret

; Подготовить диск на запись
fdc_dma_write:

        mov     al, $06
        out     $0A, al
        mov     al, $5A
        out     $0B, al ; 01011010 single transfer, address increment, autoinit, write, channel2
        mov     al, $02
        out     $0A, al
        ret

; Ожидать завершения (проверочный параметр AH)
fdc_wait:

        push    eax
        mov     dx, MAIN_STATUS_REGISTER
@@:     in      al, dx
        and     al, ah
        cmp     al, ah
        jne     @b
        pop     eax
        ret

; Запись данных (al) в FIFO
fdc_write_reg:

        mov     ah, $80
        call    fdc_wait            ; Ожидать OK
        mov     dx, DATA_FIFO
        out     dx, al              ; Записать AL в FIFO
        ret

; Чтение данных (al) из FIFO
fdc_read_reg:

        mov     ah, $c0
        call    fdc_wait            ; Ожидать OK
        mov     dx, DATA_FIFO
        in      al, dx              ; Прочесть AL из FIFO
        ret

; Включить мотор
fdc_motor_on:

        cli
        mov     [fdc.motor], 1              ; Включение
        sti
        mov     eax, [irq_timer]
        mov     [fdc.motor_time], eax       ; Запись таймера
        mov     dx, DIGITAL_OUTPUT_REGISTER ; Регистр DOR = $1C (On)
        mov     al, 0x1C
        out     dx, al
        ret

; Выключить мотор
fdc_motor_off:

        cli
        mov     [fdc.motor], 0
        sti
        xor     eax, eax
        mov     dx, DIGITAL_OUTPUT_REGISTER ; Отключить
        out     dx, al
        ret

; Проверить IRQ-статус после SEEK, CALIBRATE, etc.
fdc_sensei:

        FDCWRI  SENSE_INTERRUPT     ; Отправка запроса
        mov     ah, 0xd0
        call    fdc_wait
        mov     dx, DATA_FIFO       ; Получение результата
        in      al, dx
        mov     [fdc.st0], al
        mov     ah, 0xd0
        call    fdc_wait
        mov     dx, DATA_FIFO       ; Номер цилиндра
        in      al, dx
        mov     [fdc.cyl], al
        ret

; Конфигурирование
fdc_configure:

        FDCWRI  SPECIFY
        FDCWRI  0                   ; steprate_headunload
        FDCWRI  0                   ; headload_ndma
        ret

; Калибрация драйва
fdc_calibrate:

        call    fdc_motor_on
        mov     [fdc.func],  FDC_STATUS_SENSEI
        mov     [fdc.ready], 0
        FDCWRI  RECALIBRATE         ; Команда, Drive = A:
        FDCWRI  0
        FDCREADY                    ; Ожидать ответа IRQ
        ret

; Сбросить контроллер перед работой с диском
fdc_reset:

        mov     [fdc.func],  FDC_STATUS_SENSEI
        mov     [fdc.ready], 0

        ; Отключить и включить контроллер
        mov     dx, DIGITAL_OUTPUT_REGISTER
        mov     al, $00
        out     dx, al
        mov     al, $0C
        out     dx, al
                FDCREADY

        ; Конфигурирование
        mov     dx, CONFIGURATION_CONTROL_REGISTER
        mov     al, 0
        out     dx, al
        call    fdc_configure
        call    fdc_calibrate
        ret

; Сбор результирующих данных: если > 0, то ошибка
fdc_get_result:

        FDCREAD fdc.st0
        FDCREAD fdc.st1
        FDCREAD fdc.st2
        FDCREAD fdc.cyl
        FDCREAD fdc.head_end
        FDCREAD fdc.head_start
        call    fdc_read_reg
        and     al, $c0
        ret

; Преобразовать ax=LBA -> CHS
fdc_lba2chs:

        xor     dx, dx
        mov     bx, 18
        div     bx
        inc     dl
        mov     [fdc.r_sec], dl
        mov     dl, al
        and     dl, 1
        mov     [fdc.r_hd], dl
        shr     ax, 1
        mov     [fdc.r_cyl], al
        ret

; Чтение и запись в DMA => IRQ #6
; ----------------------------------------------------------------------
; bl = 0 READ; 1 WRITE
; ax = lba

; (byte write, byte head, byte cyl, byte sector)
fdc_rw:

        mov     [fdc.ready], 0
        mov     [fdc.func],  FDC_STATUS_RW
        mov     ax, $4546
        and     bl, bl
        je      @f
        mov     al, ah
@@:     call    fdc_write_reg       ; 0 MFM_bit = 0x40 | (W=0x45 | R=0x46)
        mov     al, [fdc.r_hd]
        shl     al, 2
        call    fdc_write_reg       ; 1
        FDCWRI  [fdc.r_cyl]
        FDCWRI  [fdc.r_hd]
        FDCWRI  [fdc.r_sec]
        FDCWRI  2                   ; 5 Размер сектора (2 ~> 512 bytes)
        FDCWRI  18                  ; 6 Последний сектор в цилиндре
        FDCWRI  $1B                 ; 7 Длина GAP3
        FDCWRI  $FF                 ; 8 Длина данных, игнорируется
        ret

; Поиск дорожки => IRQ #6
fdc_seek:

        mov     [fdc.ready], 0
        mov     [fdc.func],  FDC_STATUS_SEEK
        FDCWRI  SEEK                    ; Команда
        mov     al, [fdc.r_hd]
        shl     al, 2
        call    fdc_write_reg           ; head<<2
        FDCWRI  [fdc.r_cyl]             ; Цилиндр
        ret

; Подготовить диск для чтения/записи (AX = LBA)
fdc_prepare:

        call    fdc_lba2chs             ; Вычислить LBA
        mov     [fdc.error], 0          ; Отметить, что ошибок пока нет
        mov     eax, [irq_timer]
        mov     [fdc.motor_time], eax
        cmp     [fdc.motor], 0          ; Включить мотор, если нужно
        jne     @f
        call    fdc_reset
@@:     call    fdc_seek
                FDCREADY
        ret

; На вход: ax - сектор, ebx - адрес маски, cl - смещение бита (0-7)
fdc_cache_calc:

        push    eax
        xchg    eax, ecx
        and     ecx, $0FFF
        mov     ebx, ecx
        shr     ebx, 3
        and     cl, $07
        add     ebx, [fdcache_mask]
        pop     eax
        ret

; Проверка на наличие в кеше
; Если ZF=1, то в кеше нет, иначе есть
fdc_cache_test:

        call    fdc_cache_calc
        mov     bx, [ebx]
        shr     bx, cl
        and     bl, 1
        ret

; Загрузка сектора (AX) в кеш в $1000
fdc_cache_save:

        push    eax
        mov     ax, [fdc.lba]
        call    fdc_cache_calc
        mov     dl, 1
        shl     dl, cl
        or      [ebx], dl           ; Отметить, что страница в кеше
        shl     eax, 9              ; 1 сектор = 512 байт
        add     eax, [fdcache_data] ; Позиция записи
        xchg    eax, edi
        mov     esi, $1000          ; Откуда читать
        mov     ecx, 512 shr 2
        rep     movsd               ; Запись в кеш
        pop     eax
        ret

; Загрузка сектора (AX) из кеша в $1000
fdc_cache_load:

        mov     ax, [fdc.lba]
        shl     eax, 9
        add     eax, [fdcache_data]
        xchg    eax, esi
        mov     edi, $1000          ; Куда писать
        mov     ecx, 512 shr 2
        rep     movsd               ; Чтение из кеша
        ret

; ----------------------------------------------------------------------

; Чтение сектора (AX) в $1000 -> IRQ #6
fdc_read:

        mov     [fdc.lba], ax       ; Запрошенный LBA
        call    fdc_cache_test      ; Проверка наличия в кеше
        jz      @f
        call    fdc_cache_load      ; Загрузка из кеша (если есть)
        ret
@@:     call    fdc_prepare
        call    fdc_dma_read
        mov     bl, 0
        call    fdc_rw
        ret

; Запись сектора (AX) из $1000 -> IRQ #6
fdc_write:

        mov     [fdc.lba], ax
        call    fdc_prepare
        call    fdc_dma_write
        mov     bl, 1
        call    fdc_rw
        call    fdc_cache_save
        ret

; Обработчик прерываний
; ----------------------------------------------------------------------

fdc_irq:

        cmp     [fdc.func], byte FDC_STATUS_RW
        je      .rw
        call    fdc_sensei              ; Выполнить считывание рез-та
        jmp     .exit
.rw:    call    fdc_get_result          ; Забрать результат при R/W
        call    fdc_cache_save          ; Сохранение данных в кеш
        and     al, al
        jne     .exit
        mov     [fdc.error], byte 1     ; Ошибка чтения при al > 0
.exit:  mov     [fdc.ready], byte 1     ; Завершено
        ret

; Вычисление таймаута и выключение FDC из прерывания IRQ #0
; ----------------------------------------------------------------------

fdc_timeout:

        cmp     [fdc.motor], 0          ; Мотор включен?
        je      @f
        mov     eax, [irq_timer]        ; Если > 5с крутится, выключить
        sub     eax, [fdc.motor_time]
        cmp     eax, 500
        jb      @f
        call    fdc_motor_off
@@:     ret
