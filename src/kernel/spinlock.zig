// Mutual exclusion spin locks.

const printf = @import("printf.zig");
const proc = @import("proc.zig");
const riscv = @import("riscv.zig");

pub const Spinlock = struct {
    locked: bool = false,

    // TODO could detach this and manage it in a different structure?
    // For debugging:
    name: []const u8 = &.{},   // Name of lock.
    cpu: ?*proc.Cpu = null,     // The cpu holding the lock.
};

pub fn initlock(lk: *Spinlock, name: []const u8) void {
  lk.name = name;
  lk.locked = false;
  lk.cpu = null;
}

// Acquire the lock.
// Loops (spins) until the lock is acquired.
pub fn acquire(lk: *Spinlock) void {
    push_off(); // disable interrupts to avoid deadlock.
    if (holding(lk)) {
        printf.panic("acquire");
    }

    // On RISC-V, sync_lock_test_and_set turns into an atomic swap:
    //   a5 = 1
    //   s1 = &lk->locked
    //   amoswap.w.aq a5, a5, (s1)
    //while (__sync_lock_test_and_set(&lk.locked, 1) != 0) {
    //}

    // TODO verify
    while (@atomicRmw(bool, &lk.locked, .Xchg, true, .SeqCst)) {
    }

    // Tell the C compiler and the processor to not move loads or stores
    // past this point, to ensure that the critical section's memory
    // references happen strictly after the lock is acquired.
    // On RISC-V, this emits a fence instruction.
    //__sync_synchronize();

    // TODO verify
    @fence(.SeqCst);

    // Record info about lock acquisition for holding() and debugging.
    lk.cpu = proc.mycpu();
}

// Release the lock.
pub fn release(lk: *Spinlock) void {
    if (!holding(lk)) {
        printf.panic("release");
    }

    lk.cpu = null;

    // Tell the C compiler and the CPU to not move loads or stores
    // past this point, to ensure that all the stores in the critical
    // section are visible to other CPUs before the lock is released,
    // and that loads in the critical section occur strictly before
    // the lock is released.
    // On RISC-V, this emits a fence instruction.
    //__sync_synchronize();

    // TODO verify
    @fence(.SeqCst);

    // Release the lock, equivalent to lk->locked = 0.
    // This code doesn't use a C assignment, since the C standard
    // implies that an assignment might be implemented with
    // multiple store instructions.
    // On RISC-V, sync_lock_release turns into an atomic swap:
    //   s1 = &lk->locked
    //   amoswap.w zero, zero, (s1)
    //__sync_lock_release(&lk.locked);

    // TODO verify
    @atomicStore(bool, &lk.locked, false, .SeqCst);

    pop_off();
}

// Check whether this cpu is holding the lock.
// Interrupts must be off.
pub fn holding(lk: *Spinlock) bool {
    return (lk.locked and lk.cpu == proc.mycpu());
}

// push_off/pop_off are like intr_off()/intr_on() except that they are matched:
// it takes two pop_off()s to undo two push_off()s.  Also, if interrupts
// are initially off, then push_off, pop_off leaves them off.

pub fn push_off() void {
    var old = riscv.intr_get();

    riscv.intr_off();
    if (proc.mycpu().noff == 0) {
        proc.mycpu().intena = old;
    }
    proc.mycpu().noff += 1;
}

pub fn pop_off() void {
    var c = proc.mycpu();
    if (riscv.intr_get()) {
        printf.panic("pop_off - interruptible");
    }
    if (c.noff < 1) {
        printf.panic("pop_off");
    }
    c.noff -= 1;
    if (c.noff == 0 and c.intena) {
        riscv.intr_on();
    }
}
