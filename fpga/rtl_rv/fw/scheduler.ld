/* ScreenSense scheduler - minimal linker script (RV32IM, 4 KiB data RAM) */
OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY {
  irom (RX) : ORIGIN = 0x80000000, LENGTH = 32K
  dram (RW) : ORIGIN = 0x80100000, LENGTH = 4K
}

SECTIONS {
  .text : {
    *(.text.start)
    *(.text*)
    *(.rodata*)
  } > irom

  .data : { *(.data*) *(.sdata*) } > dram
  .bss  : { *(.bss*) *(.sbss*) *(COMMON) } > dram
}
