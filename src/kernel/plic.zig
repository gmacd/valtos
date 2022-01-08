//
// the riscv Platform Level Interrupt Controller (PLIC).
//

const memlayout = @import("memlayout.zig");
const proc = @import("proc.zig");

pub fn plicinit() void {
    // set desired IRQ priorities non-zero (otherwise disabled).
    @intToPtr(*volatile u32, memlayout.PLIC + memlayout.UART0_IRQ * 4).* = 1;
    @intToPtr(*volatile u32, memlayout.PLIC + memlayout.VIRTIO0_IRQ * 4).* = 1;
}

pub fn plicinithart() void {
    var hart = proc.cpuid();

    // set uart's enable bit for this hart's S-mode.
    @intToPtr(*volatile u32, memlayout.plicsenable(hart)).* = (1 << memlayout.UART0_IRQ) | (1 << memlayout.VIRTIO0_IRQ);

    // set this hart's S-mode priority threshold to 0.
    @intToPtr(*volatile u32, memlayout.plicspriority(hart)).* = 0;
}

// ask the PLIC what interrupt we should serve.
pub fn plic_claim() i32 {
    var hart = proc.cpuid();
    var irq = @intToPtr(*volatile u32, memlayout.plicsclaim(hart)).*;
    return irq;
}

// tell the PLIC we've served this IRQ.
pub fn plic_complete(irq: i32) void {
    var hart = proc.cpuid();
    @intToPtr(*volatile u32, memlayout.plicsclaim(hart)).* = irq;
}
