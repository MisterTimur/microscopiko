macro brk { xchg bx, bx }
macro IRQitem a, b {
    db a
    dd b
}
