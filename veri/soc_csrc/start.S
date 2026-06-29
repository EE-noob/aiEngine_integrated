    .section .text.start
    .globl _start
    .weak __libc_init_array
_start:
    .option push
    .option norelax
    la gp, __global_pointer$
    .option pop

    la sp, _stack_top
    li t0, 0x2000000c
    li t1, 0x5a000001
    sw t1, 0(t0)

    la t0, __bss_start
    la t1, __bss_end
1:
    bgeu t0, t1, 2f
    sw zero, 0(t0)
    addi t0, t0, 4
    j 1b

2:
    li t0, 0x2000000c
    li t1, 0x5a000002
    sw t1, 0(t0)
    la t0, __libc_init_array
    beqz t0, 3f
    jalr t0

3:
    li t0, 0x2000000c
    li t1, 0x5a000003
    sw t1, 0(t0)
    call main
    li t0, 0x20000000
    sw a0, 0(t0)
4:
    j 4b
