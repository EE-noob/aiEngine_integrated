OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
  ram (rwx) : ORIGIN = 0x00000000, LENGTH = 2048K
}

SECTIONS
{
  . = ORIGIN(ram);

  .text : {
    KEEP(*(.text.start))
    *(.text*)
    *(.rodata*)
  } > ram

  .preinit_array : {
    PROVIDE_HIDDEN(__preinit_array_start = .);
    KEEP(*(.preinit_array*))
    PROVIDE_HIDDEN(__preinit_array_end = .);
  } > ram

  .init_array : {
    PROVIDE_HIDDEN(__init_array_start = .);
    KEEP(*(SORT_BY_INIT_PRIORITY(.init_array.*) SORT_BY_INIT_PRIORITY(.ctors.*)))
    KEEP(*(.init_array .ctors))
    PROVIDE_HIDDEN(__init_array_end = .);
  } > ram

  .fini_array : {
    PROVIDE_HIDDEN(__fini_array_start = .);
    KEEP(*(SORT_BY_INIT_PRIORITY(.fini_array.*) SORT_BY_INIT_PRIORITY(.dtors.*)))
    KEEP(*(.fini_array .dtors))
    PROVIDE_HIDDEN(__fini_array_end = .);
  } > ram

  .data : {
    __global_pointer$ = . + 0x800;
    *(.sdata*)
    *(.data*)
  } > ram

  . = ALIGN(4);
  .bss : {
    __bss_start = .;
    *(.sbss*)
    *(.bss*)
    *(COMMON)
    . = ALIGN(4);
    __bss_end = .;
  } > ram

  . = ALIGN(16);
  .noinit (NOLOAD) : {
    *(.noinit*)
    . = ALIGN(16);
  } > ram

  . = ALIGN(16);
  _end = .;
  __heap_start = .;
  _stack_top = ORIGIN(ram) + LENGTH(ram);
}
