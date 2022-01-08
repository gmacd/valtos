pub const Register = enum {
    mcounteren, // machine-mode counter-enable
    medeleg,
    mepc,
    mhartid,
    mideleg,
    mie,
    mscratch,
    mstatus,
    mtvec, // machine-mode interrupt vector
    pmpaddr0,
    pmpcfg0,
    satp, // supervisor address translation and protection, holds the address of the page table
    scause, // supervisor trap cause
    sepc, // supervisor exception program counter, holds the exception return instruction
    sie,
    sip,
    sscratch, // supervisor scratch register, for early trap handler in trampoline.S
    sstatus,
    stval, // supervisor trap value
    stvec, // supervisor trap-vector base address
    time, // machine-mode cycle counter
};

pub inline fn readReg(comptime r: Register) u64 {
    return asm volatile ("csrr %[ret], " ++ @tagName(r)
        : [ret] "=r" (-> u64),
    );
}

pub inline fn writeReg(comptime r: Register, value: u64) void {
    asm volatile ("csrw " ++ @tagName(r) ++ ", %[value]"
        :
        : [value] "r" (value),
        : "memory"
    );
}

// reg = oldreg | value
pub inline fn orReg(comptime r: Register, value: u64) void {
    asm volatile ("csrs " ++ @tagName(r) ++ ", %[value]"
        :
        : [value] "r" (value),
        : "memory"
    );
}

// reg = oldreg & ~value
pub inline fn clearReg(comptime r: Register, value: u64) void {
    asm volatile ("csrc " ++ @tagName(r) ++ ", %[value]"
        :
        : [value] "r" (value),
        : "memory"
    );
}

// Machine Status Register, mstatus
pub const MSTATUS_MPP_MASK: u64 = (3 << 11); // previous mode.
pub const MSTATUS_MPP_M: u64 = (3 << 11);
pub const MSTATUS_MPP_S: u64 = (1 << 11);
pub const MSTATUS_MPP_U: u64 = (0 << 11);
pub const MSTATUS_MIE: u64 = (1 << 3); // machine-mode interrupt enable.

// Supervisor Status Register, sstatus
pub const SSTATUS_SPP: u64 = (1 << 8); // Previous mode, 1=Supervisor, 0=User
pub const SSTATUS_SPIE: u64 = (1 << 5); // Supervisor Previous Interrupt Enable
pub const SSTATUS_UPIE: u64 = (1 << 4); // User Previous Interrupt Enable
pub const SSTATUS_SIE: u64 = (1 << 1); // Supervisor Interrupt Enable
pub const SSTATUS_UIE: u64 = (1 << 0); // User Interrupt Enable

// Supervisor Interrupt Enable
pub const SIE_SEIE: u64 = (1 << 9); // external
pub const SIE_STIE: u64 = (1 << 5); // timer
pub const SIE_SSIE: u64 = (1 << 1); // software

// Machine-mode Interrupt Enable
pub const MIE_MEIE: u64 = (1 << 11); // external
pub const MIE_MTIE: u64 = (1 << 7); // timer
pub const MIE_MSIE: u64 = (1 << 3); // software

// use riscv's sv39 page table scheme.
const SATP_SV39: u64 = (8 << 60);

pub fn makeSatp(pagetable: u64) u64 {
    return SATP_SV39 | (pagetable >> 12);
}

// enable device interrupts
pub inline fn intr_on() void {
    orReg(.sstatus, SSTATUS_SIE);
}

// disable device interrupts
pub inline fn intr_off() void {
    clearReg(.sstatus, SSTATUS_SIE);
}

// are device interrupts enabled?
pub inline fn intr_get() bool {
    var x = readReg(.sstatus);
    return (x & SSTATUS_SIE) != 0;
}

pub inline fn readSp() u64 {
    return asm volatile ("mv %[ret], sp"
        : [ret] "=r" (-> u64),
    );
}

pub inline fn writeSp(value: u64) void {
    asm volatile ("mv sp, %[value]"
        :
        : [value] "r" (value),
        : "memory"
    );
}

// read and write tp, the thread pointer, which holds
// this core's hartid (core number), the index into cpus[].
pub inline fn readTp() u64 {
    return asm volatile ("mv %[ret], tp"
        : [ret] "=r" (-> u64),
    );
}

pub inline fn writeTp(value: u64) void {
    asm volatile ("mv tp, %[value]"
        :
        : [value] "r" (value),
        : "memory"
    );
}

pub inline fn readRa() u64 {
    return asm volatile ("mv %[ret], ra"
        : [ret] "=r" (-> u64),
    );
}

// flush the TLB.
pub inline fn sfenceVma() void {
    // the zero, zero means flush all TLB entries.
    asm volatile ("sfence.vma zero, zero");
}

pub const PGSIZE: u64 = 4096; // bytes per page
pub const PGSHIFT = 12; // bits of offset within a page

pub inline fn pgRoundUp(sz: u64) u64 {
    return (((sz) + PGSIZE - 1) & ~(PGSIZE - 1));
}

pub inline fn pgRoundDown(a: u64) u64 {
    return (((a)) & ~(PGSIZE - 1));
}

pub const PTE_V: u64 = (1 << 0); // valid
pub const PTE_R: u64 = (1 << 1);
pub const PTE_W: u64 = (1 << 2);
pub const PTE_X: u64 = (1 << 3);
pub const PTE_U: u64 = (1 << 4); // 1 -> user can access

// shift a physical address to the right place for a PTE.
pub fn PA2PTE(pa: u64) u64 {
    return (pa >> 12) << 10;
}

pub fn PTE2PA(pte: u64) u64 {
    return (pte >> 10) << 12;
}

pub fn PTE_FLAGS(pte: u64) u64 {
    return pte & 0x3FF;
}

// extract the three 9-bit page table indices from a virtual address.
const PXMASK: u64 = 0x1FF; // 9 bits
fn PXSHIFT(level: u6) u6 {
    return PGSHIFT + (9 * (level));
}
pub fn PX(level: u6, va: u64) u64 {
    return (va >> PXSHIFT(level)) & PXMASK;
}

// one beyond the highest possible virtual address.
// MAXVA is actually one bit less than the max allowed by
// Sv39, to avoid having to sign-extend virtual addresses
// that have the high bit set.
pub const MAXVA: u64 = (1 << (9 + 9 + 9 + 12 - 1));

pub const pte_t = u64;
pub const pagetable_t = [512]u64; // 512 PTEs
