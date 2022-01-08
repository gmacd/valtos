// Physical memory allocator, for user processes,
// kernel stacks, page-table pages,
// and pipe buffers. Allocates whole 4096-byte pages.

const memlayout = @import("memlayout.zig");
const printf = @import("printf.zig");
const spinlock = @import("spinlock.zig");
const string = @import("string.zig");
const riscv = @import("riscv.zig");

const PGSIZE = riscv.PGSIZE;
const PHYSTOP = memlayout.PHYSTOP;

// first address after kernel.
extern const end: u64;

const Run = struct {
    next: ?*Run,
};

const Kmem = struct {
    lock: spinlock.Spinlock = .{},
    freelist: ?*Run =null,
};
var kmem = Kmem{};

pub fn kinit() void {
    spinlock.initlock(&kmem.lock, "kmem");
    freerange(end, PHYSTOP);
}

fn freerange(pa_start: u64, pa_end: u64) void {
    var p = riscv.pgRoundUp(pa_start);
    while (p + PGSIZE <= pa_end): (p += PGSIZE) {
        kfree(p);
    }
}

// Free the page of physical memory pointed at by v,
// which normally should have been returned by a
// call to kalloc().  (The exception is when
// initializing the allocator; see kinit above.)
pub fn kfree(pa: u64) void {
    if (((pa % PGSIZE) != 0) or (pa < end) or (pa >= PHYSTOP)) {
        printf.panic("kfree");
    }

    // Fill with junk to catch dangling refs.
    _ = string.memset(@intToPtr([*]u8, pa), 1, PGSIZE);

    var r = @intToPtr(*Run, pa);

    spinlock.acquire(&kmem.lock);
    r.next = kmem.freelist;
    kmem.freelist = r;
    spinlock.release(&kmem.lock);
}

// Allocate one 4096-byte page of physical memory.
// Returns a pointer that the kernel can use.
// Returns 0 if the memory cannot be allocated.
pub fn kalloc() ?[*]u8 {
    spinlock.acquire(&kmem.lock);
    var page = kmem.freelist;
    if (page) |p| {
        kmem.freelist = p.next;
    }
    spinlock.release(&kmem.lock);

    if (page) |p| {
        var rawBuf: [*]u8 = @ptrCast([*]u8, p);
        _ = string.memset(rawBuf, 5, PGSIZE); // fill with junk
        return rawBuf;
    } else {
        return null;
    }
}
