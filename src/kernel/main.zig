const console = @import("console.zig");
const kalloc = @import("kalloc.zig");
const proc = @import("proc.zig");
const printf = @import("printf.zig");

var started: bool = false;

// start() jumps here in supervisor mode on all CPUs.
pub export fn main() void {
    if (proc.cpuid() == 0) {
        console.consoleinit();
        printf.printfinit();
        printf.printf("\n", .{});
        printf.printf("xv6 kernel is booting\n", .{});
        printf.printf("\n", .{});
        kalloc.kinit();         // physical page allocator
        // kvminit();       // create kernel page table
        // kvminithart();   // turn on paging
        // procinit();      // process table
        // trapinit();      // trap vectors
        // trapinithart();  // install kernel trap vector
        // plicinit();      // set up interrupt controller
        // plicinithart();  // ask PLIC for device interrupts
        // binit();         // buffer cache
        // iinit();         // inode table
        // fileinit();      // file table
        // virtio_disk_init(); // emulated hard disk
        // userinit();      // first user process

        @atomicStore(bool, &started, true, .SeqCst);
        started = true;
    } else {
        while (!@atomicLoad(bool, &started, .SeqCst)) {
        }
        // TODO print should support %llu
        printf.printf("hart %d starting\n", .{@intCast(i32, proc.cpuid())});
        // kvminithart();    // turn on paging
        // trapinithart();   // install kernel trap vector
        // plicinithart();   // ask PLIC for device interrupts
    }

    // scheduler();
}
