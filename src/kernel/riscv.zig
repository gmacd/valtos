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

// #define MAKE_SATP(pagetable) (SATP_SV39 | (((uint64)pagetable) >> 12))

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

// #define PGSIZE 4096 // bytes per page
// #define PGSHIFT 12  // bits of offset within a page

// #define PGROUNDUP(sz)  (((sz)+PGSIZE-1) & ~(PGSIZE-1))
// #define PGROUNDDOWN(a) (((a)) & ~(PGSIZE-1))

// #define PTE_V (1L << 0) // valid
// #define PTE_R (1L << 1)
// #define PTE_W (1L << 2)
// #define PTE_X (1L << 3)
// #define PTE_U (1L << 4) // 1 -> user can access

// // shift a physical address to the right place for a PTE.
// #define PA2PTE(pa) ((((uint64)pa) >> 12) << 10)

// #define PTE2PA(pte) (((pte) >> 10) << 12)

// #define PTE_FLAGS(pte) ((pte) & 0x3FF)

// // extract the three 9-bit page table indices from a virtual address.
// #define PXMASK          0x1FF // 9 bits
// #define PXSHIFT(level)  (PGSHIFT+(9*(level)))
// #define PX(level, va) ((((uint64) (va)) >> PXSHIFT(level)) & PXMASK)

// // one beyond the highest possible virtual address.
// // MAXVA is actually one bit less than the max allowed by
// // Sv39, to avoid having to sign-extend virtual addresses
// // that have the high bit set.
// #define MAXVA (1L << (9 + 9 + 9 + 12 - 1))

// typedef uint64 pte_t;
// typedef uint64 *pagetable_t; // 512 PTEs
