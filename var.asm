
; Некоторые системные глобальные переменные
; ----------------------------------------------------------------------

irq_timer           dd ?            ; Значение системного таймера
mem_size            dd ?            ; Объем памяти в байтах
dynamic             dd ?            ; Курсор динамической памяти для ядра
appsmem             dd ?            ; Память для загрузки приложений
ummp                dd ?            ; Битовая карта памяти
fdcache_mask        dd ?            ; Битовые маски занятости кеша
fdcache_data        dd ?            ; Кеш диска FD

tss:
; ----------------------------------------------------------------------
; Task Segment Stage: главная таблица

.link   dd ?
.esp0   dd ?
.ss0    dd ?
.esp1   dd ?
.ss1    dd ?
.esp2   dd ?
.ss2    dd ?
.cr3    dd ?            ; Указатель на PDBR
.eip    dd ?
.eflags dd ?
.eax    dd ?   
.ecx    dd ?   
.edx    dd ?   
.ebx    dd ?   
.esp    dd ?   
.ebp    dd ?   
.esi    dd ?   
.edi    dd ?   
.es     dd ?   
.cs     dd ?   
.ss     dd ?   
.ds     dd ?   
.fs     dd ?
.gs     dd ?   
.ldtr   dd ?
.iobp   dw ?, ?


fdc:
; ----------------------------------------------------------------------

; результат
.st0            db ?        ; Статусный регистр 0
.st1            db ?
.st2            db ?
.cyl            db ?
.head_end       db ?
.head_start     db ?

; функционирование
.motor          db ?        ; Включен ли мотор
.motor_time     dd ?        ; Время включения мотора
.func           db ?        ; Функция запроса на IRQ
.ready          db ?        ; IRQ обработан
.error          db ?        ; Ошибка исполнения

; запрос
.lba            dw ?
.r_hd           db ?        ; * головка
.r_cyl          db ?        ; * цилиндр
.r_sec          db ?        ; * сектор


ps2:            ; Интерфейс PS/2 для мыши
; ----------------------------------------------------------------------

.cmd            db ?        ; принятая команда от мыши
.dat_x          db ?        ; x = -128..127
.dat_y          db ?        ; y = -128..127


ata:
; ----------------------------------------------------------------------
.base           dw ?            ; pri=1F0, sec=170 
.slave          db ?            ; master=0, slave=1
.lba            dd ?            ; запрошенный lba
.count          dw ?            ; запрошенный count
.error          db ?            ; =0 ошибок нет
.types          db ?, ?, ?, ?   ; ata[4] типы
.identify       dd ?, ?, ?, ?   ; ссылки на identify
