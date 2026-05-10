    .section .text.start
    .globl _start
_start:
    la sp, _stack_top
    call main
    li t0, 0x20000000
    sw a0, 0(t0)
1:
    j 1b
