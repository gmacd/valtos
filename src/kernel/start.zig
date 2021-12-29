const std = @import("std");
const riscv = @import("riscv.zig");
const main = @import("main.zig").main;
const memlayout = @import("memlayout.zig");

// Force linking of trapzig
// TODO remove when it's referenced by something else
usingnamespace @import("trap.zig");

// entry.s needs one stack per CPU.
const NCPU = 16;
const STACK_SIZE = 4096;
export const stack0: [NCPU][STACK_SIZE]u8 align(16) = std.mem.zeroes([NCPU][STACK_SIZE]u8);

// a scratch area per CPU for machine-mode timer interrupts.
var timer_scratch: [NCPU][5]u64 align(16) = std.mem.zeroes([NCPU][5]u64);

// assembly code in kernelvec.S for machine-mode timer interrupt.
extern fn timervec() void;

// entry.s jumps here in machine mode on stack0.
export fn start() void {
    // set M Previous Privilege mode to Supervisor, for mret.
    var x = riscv.r_mstatus();
    x &= ~riscv.MSTATUS_MPP_MASK;
    x |= riscv.MSTATUS_MPP_S;
    riscv.w_mstatus(x);

    // set M Exception Program Counter to main, for mret.
    // requires gcc -mcmodel=medany
    riscv.w_mepc(@ptrToInt(main));

    // disable paging for now.
    riscv.w_satp(0);

    // delegate all interrupts and exceptions to supervisor mode.
    riscv.w_medeleg(0xffff);
    riscv.w_mideleg(0xffff);
    riscv.w_sie(riscv.r_sie() | riscv.SIE_SEIE | riscv.SIE_STIE | riscv.SIE_SSIE);

    // configure Physical Memory Protection to give supervisor mode
    // access to all of physical memory.
    riscv.w_pmpaddr0(0x3fffffffffffff);
    riscv.w_pmpcfg0(0xf);

    // ask for clock interrupts.
    timerinit();

    // keep each CPU's hartid in its tp register, for cpuid().
    const id = riscv.r_mhartid();
    riscv.w_tp(id);

    // switch to supervisor mode and jump to main().
    asm volatile("mret");
}

// set up to receive timer interrupts in machine mode,
// which arrive at timervec in kernelvec.S,
// which turns them into software interrupts for
// devintr() in trap.c.
fn timerinit() void {
    // each CPU has a separate source of timer interrupts.
    const id = riscv.r_mhartid();

    // ask the CLINT for a timer interrupt.
    const interval = 1000000; // cycles; about 1/10th second in qemu.
    memlayout.clintmtimecmp(id).* = memlayout.CLINT_MTIME.* + interval;

    // prepare information in scratch[] for timervec.
    // scratch[0..2] : space for timervec to save registers.
    // scratch[3] : address of CLINT MTIMECMP register.
    // scratch[4] : desired interval (in cycles) between timer interrupts.
    //uint64 *scratch = &timer_scratch[id][0];
    var scratch = &timer_scratch[id];
    //scratch[3] = CLINT_MTIMECMP(id);
    scratch[3] = @ptrToInt(memlayout.clintmtimecmp(id));
    //scratch[4] = interval;
    scratch[4] = interval;
    riscv.w_mscratch(@ptrToInt(scratch));

    // set the machine-mode trap handler.
    riscv.w_mtvec(@ptrToInt(timervec));

    // enable machine-mode interrupts.
    riscv.w_mstatus(riscv.r_mstatus() | riscv.MSTATUS_MIE);

    // enable machine-mode timer interrupts.
    riscv.w_mie(riscv.r_mie() | riscv.MIE_MTIE);
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
