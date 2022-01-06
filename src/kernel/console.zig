const std = @import("std");
const mem = std.mem;

const file = @import("file.zig");
const printf = @import("printf.zig");
const proc = @import("proc.zig");
const spinlock = @import("spinlock.zig");
const uart = @import("uart.zig");

// Control-x
fn ctrl(x: u8) u8 {
    return x - '@';
}

//
// send one character to the uart.
// called by printf, and to echo input characters,
// but not from write().
//
pub fn consputc(c: u8) void {
    uart.uartputc_sync(c);
}

fn consputbackspace() void {
    // the user typed backspace, so overwrite with a space.
    uart.uartputc_sync('\x08');
    uart.uartputc_sync(' ');
    uart.uartputc_sync('\x08');
}

const INPUT_BUF = 128;
pub const Console = struct {
    lock: spinlock.Spinlock = .{},

    // input
    buf: [INPUT_BUF]u8 = [_]u8{0} ** INPUT_BUF,
    r: u32 = 0, // Read index
    w: u32 = 0, // Write index
    e: u32 = 0, // Edit index
};
var cons = Console{};

//
// user write()s to the console go here.
//
pub fn consolewrite(user_src: i32, src: u64, n: i32) i32 {
    var i: i32 = 0;

    while (i < n) : (i += 1) {
        var c: [1]u8 = [1]u8{0};
        if (proc.either_copyin(&c, user_src, src + @intCast(u64, i), 1) == -1) {
            break;
        }
        uart.uartputc(c[0]);
    }

    return i;
}

//
// user read()s from the console go here.
// copy (up to) a whole input line to dst.
// user_dist indicates whether dst is a user
// or kernel address.
//
pub fn consoleread(user_dst: i32, dst: u64, n: i32) i32 {
    var target = n;
    var currn = n;
    var currdst = dst;
    spinlock.acquire(&cons.lock);
    while (currn > 0) {
        // wait until interrupt handler has put some
        // input into cons.buffer.
        while (cons.r == cons.w) {
            var p = proc.myproc() orelse {
                printf.panic("no proc");
                return -1;
            };
            if (p.killed) {
                spinlock.release(&cons.lock);
                return -1;
            }
            proc.sleep(&cons.r, &cons.lock);
        }

        var c = cons.buf[(cons.r % INPUT_BUF)..];
        cons.r += 1;

        if (c[0] == ctrl('D')) { // end-of-file
            if (currn < target) {
                // Save ^D for next time, to make sure
                // caller gets a 0-byte result.
                cons.r -= 1;
            }
            break;
        }

        // copy the input byte to the user-space buffer.
        var cbuf = c;
        if (proc.either_copyout(user_dst, currdst, cbuf.ptr, 1) == -1) {
            break;
        }

        currdst += 1;
        currn -= 1;

        if (c[0] == '\n') {
            // a whole line has arrived, return to
            // the user-level read().
            break;
        }
    }
    spinlock.release(&cons.lock);

    return target - currn;
}

//
// the console input interrupt handler.
// uartintr() calls this for input character.
// do erase/kill processing, append to cons.buf,
// wake up consoleread() if a whole line has arrived.
//
pub fn consoleintr(c: u8) void {
    spinlock.acquire(&cons.lock);

    switch (c) {
        ctrl('P') => {
            // Print process list.
            proc.procdump();
        },
        ctrl('U') => {
            // Kill line.
            while ((cons.e != cons.w) and (cons.buf[(cons.e - 1) % INPUT_BUF] != '\n')) {
                cons.e -= 1;
                consputbackspace();
            }
        },
        ctrl('H') | '\x7f' => {
            // Backspace
            if (cons.e != cons.w) {
                cons.e -= 1;
                consputbackspace();
            }
        },
        else => {
            if ((c != 0) and (cons.e - cons.r < INPUT_BUF)) {
                c = if (c == '\r') '\n' else c;

                // echo back to the user.
                consputc(c);

                // store for consumption by consoleread().
                cons.buf[cons.e % INPUT_BUF] = c;
                cons.e += 1;

                if ((c == '\n') or (c == ctrl('D')) or (cons.e == cons.r + INPUT_BUF)) {
                    // wake up consoleread() if a whole line (or end-of-file)
                    // has arrived.
                    cons.w = cons.e;
                    proc.wakeup(&cons.r);
                }
            }
        },
    }

    spinlock.release(&cons.lock);
}

pub fn consoleinit() void {
    spinlock.initlock(&cons.lock, "cons");

    uart.uartinit();

    // connect read and write system calls
    // to consoleread and consolewrite.
    file.devsw[file.CONSOLE].read = consoleread;
    file.devsw[file.CONSOLE].write = consolewrite;
}
