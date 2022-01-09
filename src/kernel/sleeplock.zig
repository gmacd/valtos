// Sleeping locks

const proc = @import("proc.zig");
const spinlock = @import("spinlock.zig");

// Long-term locks for processes
pub const Sleeplock = struct {
    locked: bool = false,       // Is the lock held?
    lk: spinlock.Spinlock = .{}, // spinlock protecting this sleep lock

    // For debugging:
    name: []const u8 = &.{},   // Name of lock.
    pid: i32 = 0,           // Process holding lock
};

pub fn initsleeplock(lk: *Sleeplock, name: [] const u8) void {
    spinlock.initlock(&lk.lk, "sleep lock");
    lk.name = name;
    lk.locked = false;
    lk.pid = 0;
}

pub fn acquiresleep(lk: *Sleeplock) void {
    spinlock.acquire(&lk.lk);
    while (lk.locked) {
        proc.sleep(lk, &lk.lk);
    }
    lk.locked = true;
    lk.pid = proc.myproc().pid;
    spinlock.release(&lk.lk);
}

pub fn releasesleep(lk: *Sleeplock) void {
    spinlock.acquire(&lk.lk);
    lk.locked = 0;
    lk.pid = 0;
    proc.wakeup(lk);
    spinlock.release(&lk.lk);
}

pub fn holdingsleep(lk: *Sleeplock) i32 {
    spinlock.acquire(&lk.lk);
    var r = lk.locked and (lk.pid == proc.myproc().pid);
    spinlock.release(&lk.lk);
    return r;
}
