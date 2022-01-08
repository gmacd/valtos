//
// formatted console output -- printf, panic.
//

const console = @import("console.zig");
const spinlock = @import("spinlock.zig");

pub var panicked: bool = false;

// lock to avoid interleaving concurrent printf's.
const Pr = struct {
  lock: spinlock.Spinlock = spinlock.Spinlock{},
  locking: bool = false,
};
var pr = Pr{};


const digits = "0123456789abcdef";

pub fn printint(xx: i32, base: i32, sign: bool) void {
    var buf: [16]u8 = [_]u8{0}**16;
    var x : i32 = xx;
    var printminus = sign;

    if (base < 2) {
        return;
    }

    if (printminus) {
        printminus = xx < 0;
        if (printminus) {
            x = -xx;
        }
    }

    buf[0] = digits[@intCast(usize, @mod(x, base))];
    var i: i32 = 1;
    x = @divTrunc(x, base);
    while (x != 0): ({ i += 1; x = @divTrunc(x, base); }) {
        buf[@intCast(usize, i)] = digits[@intCast(usize, @mod(x, base))];
    }

    if (printminus) {
        buf[@intCast(usize, i)] = '-';
        i += 1;
    }

    i -= 1;
    while (i >= 0) : (i -= 1) {
        console.consputc(buf[@intCast(usize, i)]);
    }
}

pub fn printptr(x: u64) void {
    var i: i32 = 0;
    var xx = x;
    while (i < (@sizeOf(u64) * 2)) : ({ i+=1; xx <<= 4; }) {
        console.consputc(digits[xx >> (@sizeOf(u64) * 8 - 4)]);
    }
}

// Print to the console. only understands %d, %x, %p, %s.
// TODO support more interesting verbs.  E.g. %llu.
// TODO @compileError if arg length unexpected, etc.
pub fn printf(comptime fmt: []const u8, args: anytype) void {
    var locking = pr.locking;
    if (locking) {
        spinlock.acquire(&pr.lock);
    }

    comptime var i: usize = 0;
    comptime var argi: usize = 0;
    inline while (i < fmt.len) : (i += 1) {
        comptime var c = fmt[i];

        if (c != '%') {
            console.consputc(c);
            continue;
        }

        i += 1;
        if (i >= fmt.len) {
            break;
        }
        c = fmt[i];

        switch (c) {
            'd' => {
                printint(@as(i32, args[argi]), 10, true);
            },
            'x' => {
                printint(@as(i32, args[argi]), 16, true);
            },
            'p' => {
                printptr(args[argi]);
            },
            's' => {
                var s = args[argi];
                for (s) |cs| {
                    console.consputc(cs);
                }
            },
            '%' => {
                console.consputc('%');
            },
            else => {
                // Print unknown % sequence to draw attention.
                console.consputc('%');
                console.consputc(c);
            },
        }
        argi += 1;
    }

    if (locking) {
        spinlock.release(&pr.lock);
    }
}

pub fn panic(comptime s: []const u8) noreturn {
    pr.locking = false;
    printf("panic: ", .{});
    printf(s, .{});
    printf("\n", .{});
    @atomicStore(bool, &panicked, true, .SeqCst); // freeze uart output from other CPUs
    while (true) {
    }
}

pub fn printfinit() void {
  spinlock.initlock(&pr.lock, "pr");
  pr.locking = true;
}
