const riscv = @import("riscv.zig");

// Must be called with interrupts disabled,
// to prevent race with process being moved
// to a different CPU.
pub fn cpuid() u64 {
    return riscv.r_tp();
}
