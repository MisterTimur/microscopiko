
; Некоторые системные глобальные переменные
; ----------------------------------------------------------------------

irq_timer           dd ?            ; Значение системного таймера
mem_size            dd ?            ; Объем памяти в байтах
dynamic             dd ?            ; Динамическая память ядра

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
