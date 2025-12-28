KERNEL_VIRT_START = 0xffffffff80000000;
KERNEL_STACK_SIZE = 0x4000;

ENTRY(__boot_entry__)

SECTIONS {

    . = KERNEL_VIRT_START;
    
    __base__ = .;
    __kernel_start__ = .;

    .text : ALIGN(4K) {
        *(.text*)
    } : text

    .rodata : ALIGN(4K) {
        *(.rodata*)
        *(.lrodata*)
    } : rodata

    .data : ALIGN(4K) {
        *(.data*)
        *(.ldata*)
    } : data

    .bss : ALIGN(4K) {
        *(.bss*)
        *(.lbss*)
        *(COMMON)

        . = ALIGN(16);
        . += KERNEL_STACK_SIZE;
    } : bss

    .tbss : ALIGN(4K) {
        *(.tbss*)
    } : tbss

    .kernel_modules : ALIGN(8)
    {
        __kernel_modules_start__ = .;
        KEEP(*(.kernel_modules*))
        KEEP(*(.kernel_modules.*))
        __kernel_modules_end__ = .;
    }

    __kernel_end__ = .;
}
