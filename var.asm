
; Некоторые системные глобальные переменные
; ----------------------------------------------------------------------

irq_timer           dd ?            ; Значение системного таймера
mem_size            dd ?            ; Объем памяти в байтах
dynamic             dd ?            ; Динамическая память ядра
appsmem             dd ?            ; Общая память для загрузки приложений
ummp                dd ?            ; Битовая карта
fdcache_mask        dd ?            ; Битовые маски занятости
fdcache_data        dd ?            ; Кеш диска

; Task Segment Stage: главная таблица
; ----------------------------------------------------------------------

TSS:

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

