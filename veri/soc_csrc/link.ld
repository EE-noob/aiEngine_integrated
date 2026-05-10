ENTRY(_start)

MEMORY
{
  ram (rwx) : ORIGIN = 0x00000000, LENGTH = 256K
}

SECTIONS
{
  .text : {
    KEEP(*(.text.start))
    *(.text*)
    *(.rodata*)
  } > ram

  .data : {
    *(.sdata*)
    *(.data*)
  } > ram

  .bss : {
    __bss_start = .;
    *(.sbss*)
    *(.bss*)
    *(COMMON)
    __bss_end = .;
  } > ram

  . = ALIGN(16);
  _stack_top = ORIGIN(ram) + LENGTH(ram);
}
