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

// machine exception program counter, holds the
// instruction address to which a return from
// exception will go.
pub fn w_mepc(x: u64) void {
    asm volatile("csrw mepc, %[in]" : : [in] "r" (x));
}

// Supervisor Status Register, sstatus

pub const SSTATUS_SPP: u64 = (1 << 8);  // Previous mode, 1=Supervisor, 0=User
pub const SSTATUS_SPIE: u64 = (1 << 5); // Supervisor Previous Interrupt Enable
pub const SSTATUS_UPIE: u64 = (1 << 4); // User Previous Interrupt Enable
pub const SSTATUS_SIE: u64 = (1 << 1);  // Supervisor Interrupt Enable
pub const SSTATUS_UIE: u64 = (1 << 0);  // User Interrupt Enable

pub fn r_sstatus() u64 {
    // Need to check - not sure about this inline asm, though it seems to work
    var x: u64 = 0;
    asm volatile("csrr %[in], sstatus" : : [in] "r" (x));
    return x;
}

pub fn w_sstatus(x: u64) void {
    asm volatile("csrw sstatus, %[in]" : : [in] "r" (x));
}

pub fn w_sip(x: u64) void {
    asm volatile("csrw sip, %[in]" : : [in] "r" (x));
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

// supervisor exception program counter, holds the
// instruction address to which a return from
// exception will go.
pub fn w_sepc(x: u64) void {
    asm volatile("csrw sepc, %[in]" : : [in] "r" (x));
}

pub fn r_sepc() u64 {
    // Need to check - not sure about this inline asm, though it seems to work
    var x: u64 = 0;
    asm volatile("csrr %[in], sepc" : : [in] "r" (x));
    return x;
}

// // Machine Exception Delegation
// static inline uint64
// r_medeleg()
// {
//   uint64 x;
//   asm volatile("csrr %0, medeleg" : "=r" (x) );
//   return x;
// }

pub fn w_medeleg(x: u64) void {
    asm volatile("csrw medeleg, %[in]" : : [in] "r" (x));
}

// // Machine Interrupt Delegation
// static inline uint64
// r_mideleg()
// {
//   uint64 x;
//   asm volatile("csrr %0, mideleg" : "=r" (x) );
//   return x;
// }

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

// // use riscv's sv39 page table scheme.
// #define SATP_SV39 (8L << 60)

// #define MAKE_SATP(pagetable) (SATP_SV39 | (((uint64)pagetable) >> 12))

// supervisor address translation and protection;
// holds the address of the page table.
pub fn w_satp(x: u64) void {
    asm volatile("csrw satp, %[in]" : : [in] "r" (x));
}

// static inline uint64
// r_satp()
// {
//   uint64 x;
//   asm volatile("csrr %0, satp" : "=r" (x) );
//   return x;
// }

// Supervisor Scratch register, for early trap handler in trampoline.S.
pub fn w_sscratch(x: u64) void {
    asm volatile("csrw sscratch, %[in]" : : [in] "r" (x));
}

pub fn w_mscratch(x: u64) void {
    asm volatile("csrw mscratch, %[in]" : : [in] "r" (x));
}

// Supervisor Trap Cause
pub fn r_scause() u64 {
    // Need to check - not sure about this inline asm, though it seems to work
    var x: u64 = 0;
    asm volatile("csrr %[in], scause" : : [in] "r" (x));
    return x;
}

// // Supervisor Trap Value
pub fn r_stval() u64 {
    // Need to check - not sure about this inline asm, though it seems to work
    var x: u64 = 0;
    asm volatile("csrr %[in], stval" : : [in] "r" (x));
    return x;
}

// // Machine-mode Counter-Enable
// static inline void 
// w_mcounteren(uint64 x)
// {
//   asm volatile("csrw mcounteren, %0" : : "r" (x));
// }

// static inline uint64
// r_mcounteren()
// {
//   uint64 x;
//   asm volatile("csrr %0, mcounteren" : "=r" (x) );
//   return x;
// }

// // machine-mode cycle counter
// static inline uint64
// r_time()
// {
//   uint64 x;
//   asm volatile("csrr %0, time" : "=r" (x) );
//   return x;
// }

// enable device interrupts
pub fn intr_on() void {
    w_sstatus(r_sstatus() | SSTATUS_SIE);
}

// disable device interrupts
pub fn intr_off() void {
    w_sstatus(r_sstatus() & ~SSTATUS_SIE);
}

// are device interrupts enabled?
pub fn intr_get() bool {
    var x = r_sstatus();
    return (x & SSTATUS_SIE) != 0;
}

// static inline uint64
// r_sp()
// {
//   uint64 x;
//   asm volatile("mv %0, sp" : "=r" (x) );
//   return x;
// }

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

// static inline uint64
// r_ra()
// {
//   uint64 x;
//   asm volatile("mv %0, ra" : "=r" (x) );
//   return x;
// }

// // flush the TLB.
// static inline void
// sfence_vma()
// {
//   // the zero, zero means flush all TLB entries.
//   asm volatile("sfence.vma zero, zero");
// }


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
