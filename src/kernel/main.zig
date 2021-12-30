const proc = @import("proc.zig");

const uart = @intToPtr(*volatile u8, 0x10000000);

// TODO remove
fn putchar(c: u8) void {
    uart.* = c;
}

fn print(str: []const u8) void {
    for (str) |c| {
        putchar(c);
    }
}

// TODO could this be a spinlock?
var started: bool = false;

// start() jumps here in supervisor mode on all CPUs.
pub export fn main() void {
    if (proc.cpuid() == 0) {
        // TODO
        @atomicStore(bool, &started, true, .SeqCst);
        started = true;
    } else {
        while (!@atomicLoad(bool, &started, .SeqCst)) {
        }
    }

    // TODO remove
    print("valtos\n");
}
