// Physical memory layout

// qemu -machine virt is set up like this,
// based on qemu's hw/riscv/virt.c:
//
// 00001000 -- boot ROM, provided by qemu
// 02000000 -- CLINT
// 0C000000 -- PLIC
// 10000000 -- uart0 
// 10001000 -- virtio disk 
// 80000000 -- boot ROM jumps here in machine mode
//             -kernel loads the kernel here
// unused RAM after 80000000.

// the kernel uses physical memory thus:
// 80000000 -- entry.S, then kernel text and data
// end -- start of kernel page allocation area
// PHYSTOP -- end RAM used by the kernel

// qemu puts UART registers here in physical memory.
pub const UART0 = 0x10000000;
const UART0_IRQ = 10;

// virtio mmio interface
const VIRTIO0 = 0x10001000;
const VIRTIO0_IRQ = 1;

// core local interruptor (CLINT), which contains the timer.
const CLINT_OFFSET = 0x2000000;
pub const CLINT = @intToPtr(*volatile u64, CLINT_OFFSET);
pub const CLINT_MTIME = @intToPtr(*volatile u64, CLINT_OFFSET + 0xBFF8);
pub fn clintmtimecmp(hartid: u64) *volatile u64 {
    return @intToPtr(*volatile u64, CLINT_OFFSET + 0x4000 + 8*(hartid));
}

// qemu puts platform-level interrupt controller (PLIC) here.
const PLIC = 0x0c000000;
const PLIC_PRIORITY = (PLIC + 0x0);
const PLIC_PENDING = (PLIC + 0x1000);
pub fn plicmenable(hart: u64) u64 { return PLIC + 0x2000 + (hart)*0x100; }
pub fn plicsenable(hart: u64) u64 { return PLIC + 0x2080 + (hart)*0x100; }
pub fn plicmpriority(hart: u64) u64 { return PLIC + 0x200000 + (hart)*0x2000; }
pub fn plicspriority(hart: u64) u64 { return PLIC + 0x201000 + (hart)*0x2000; }
pub fn plicmclaim(hart: u64) u64 { return PLIC + 0x200004 + (hart)*0x2000; }
pub fn plicsclaim(hart: u64) u64 { return PLIC + 0x201004 + (hart)*0x2000; }

// the kernel expects there to be RAM
// for use by the kernel and user pages
// from physical address 0x80000000 to PHYSTOP.
pub const KERNBASE = 0x80000000;
pub const PHYSTOP = (KERNBASE + 128*1024*1024);

// map the trampoline page to the highest address,
// in both user and kernel space.
//const TRAMPOLINE = (MAXVA - PGSIZE);

// map kernel stacks beneath the trampoline,
// each surrounded by invalid guard pages.
//pub fn kstack(p: u64) u64 { return TRAMPOLINE - ((p)+1)* 2*PGSIZE; }

// User memory layout.
// Address zero first:
//   text
//   original data and bss
//   fixed-size stack
//   expandable heap
//   ...
//   TRAPFRAME (p->trapframe, used by the trampoline)
//   TRAMPOLINE (the same page as in the kernel)
//const TRAPFRAME = (TRAMPOLINE - PGSIZE);
