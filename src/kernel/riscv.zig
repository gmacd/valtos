// which hart (core) is this?
pub fn r_mhartid() u64 {
    // Need to check - not sure about this inline asm, though it seems to work
    var x: u64 = 0;
    asm volatile("csrr %[in], mhartid" : : [in] "r" (x));
    return x;
}

// Machine Status Register, mstatus
pub const MSTATUS_MPP_MASK: u64 = (3 << 11); // previous mode.
pub const MSTATUS_MPP_M: u64 = (3 << 11);
pub const MSTATUS_MPP_S: u64 = (1 << 11);
pub const MSTATUS_MPP_U: u64 = (0 << 11);
pub const MSTATUS_MIE: u64 = (1 << 3);       // machine-mode interrupt enable.

pub fn r_mstatus() u64 {
    // Need to check - not sure about this inline asm, though it seems to work
    var x: u64 = 0;
    asm volatile("csrr %[in], mstatus" : : [in] "r" (x));
    return x;
}

pub fn w_mstatus(x: u64) void {
    asm volatile("csrw mstatus, %[in]" : : [in] "r" (x));
}

// Supervisor Interrupt Enable
pub const SIE_SEIE: u64 = (1 << 9); // external
pub const SIE_STIE: u64 = (1 << 5); // timer
pub const SIE_SSIE: u64 = (1 << 1); // software

pub fn r_sie() u64 {
    // Need to check - not sure about this inline asm, though it seems to work
    var x: u64 = 0;
    asm volatile("csrr %[in], sie" : : [in] "r" (x));
    return x;
}

pub fn w_sie(x: u64) void {
    asm volatile("csrw sie, %[in]" : : [in] "r" (x));
}

// Machine-mode Interrupt Enable
pub const MIE_MEIE: u64 = (1 << 11); // external
pub const MIE_MTIE: u64 = (1 << 7);  // timer
pub const MIE_MSIE: u64 = (1 << 3);  // software
pub fn r_mie() u64 {
    // Need to check - not sure about this inline asm, though it seems to work
    var x: u64 = 0;
    asm volatile("csrr %[in], mie" : : [in] "r" (x));
    return x;
}

pub fn w_mie(x: u64) void {
    asm volatile("csrw mie, %[in]" : : [in] "r" (x));
}

// machine exception program counter, holds the
// instruction address to which a return from
// exception will go.
pub fn w_mepc(x: u64) void {
    asm volatile("csrw mepc, %[in]" : : [in] "r" (x));
}

// supervisor address translation and protection;
// holds the address of the page table.
pub fn w_satp(x: u64) void {
    asm volatile("csrw satp, %[in]" : : [in] "r" (x));
}

pub fn w_medeleg(x: u64) void {
    asm volatile("csrw medeleg, %[in]" : : [in] "r" (x));
}

pub fn w_mideleg(x: u64) void {
    asm volatile("csrw mideleg, %[in]" : : [in] "r" (x));
}

// Supervisor Trap-Vector Base Address
// low two bits are mode.
pub fn w_stvec(x: u64) void {
    asm volatile("csrw stvec, %[in]" : : [in] "r" (x));
}

pub fn r_stvec() u64 {
    // Need to check - not sure about this inline asm, though it seems to work
    var x: u64 = 0;
    asm volatile("csrr %[in], stvec" : : [in] "r" (x));
    return x;
}

// Machine-mode interrupt vector
pub fn w_mtvec(x: u64) void {
    asm volatile("csrw mtvec, %[in]" : : [in] "r" (x));
}

pub fn w_pmpcfg0(x: u64) void {
    asm volatile("csrw pmpcfg0, %[in]" : : [in] "r" (x));
}

pub fn w_pmpaddr0(x: u64) void {
    asm volatile("csrw pmpaddr0, %[in]" : : [in] "r" (x));
}

// Supervisor Scratch register, for early trap handler in trampoline.S.
pub fn w_sscratch(x: u64) void {
    asm volatile("csrw sscratch, %[in]" : : [in] "r" (x));
}

pub fn w_mscratch(x: u64) void {
    asm volatile("csrw mscratch, %[in]" : : [in] "r" (x));
}

// read and write tp, the thread pointer, which holds
// this core's hartid (core number), the index into cpus[].
pub fn r_tp() u64 {
    // Need to check - not sure about this inline asm, though it seems to work
    var x: u64 = 0;
    asm volatile("mv %[in], tp" : : [in] "r" (x));
    return x;
}

pub fn w_tp(x: u64) void {
    asm volatile("mv tp, %[in]" : : [in] "r" (x));
}
