// kernel.ld places _entry at 0x80000000
.section .text
.global _entry
_entry:
    // Copied from xv6 for now.
    // stack0 points to an array of 4096 byte buffers - one per CPU.
    // We want to point sp to the end of the buffer for the CPU that
    // is running on startup (mhartid).
    la sp, stack0
    li a0, 1024*4
    csrr a1, mhartid
    addi a1, a1, 1
    mul a0, a0, a1
    add sp, sp, a0

    call start
spin:
    j spin
