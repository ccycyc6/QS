/* ScreenSense scheduler - bare-metal startup (RV32IM) */
.section .text.start
.globl _start
_start:
    la      sp, _stack_top
    call    main
1:  j       1b

.section .bss
.align 4
.space 2048
_stack_top:
