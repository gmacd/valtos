const bio = @import("bio.zig");
const console = @import("console.zig");
const kalloc = @import("kalloc.zig");
const plic = @import("plic.zig");
const proc = @import("proc.zig");
const printf = @import("printf.zig");
const trap = @import("trap.zig");
const vm = @import("vm.zig");

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
        vm.kvminit();       // create kernel page table
        vm.kvminithart();   // turn on paging
        proc.procinit();      // process table
        trap.trapinit();      // trap vectors
        trap.trapinithart();  // install kernel trap vector
        plic.plicinit();      // set up interrupt controller
        plic.plicinithart();  // ask PLIC for device interrupts
        bio.binit();         // buffer cache
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
        vm.kvminithart();    // turn on paging
        trap.trapinithart();   // install kernel trap vector
        plic.plicinithart();   // ask PLIC for device interrupts
    }

    // scheduler();
}
