const std = @import("std");
const mem = std.mem;

const file = @import("file.zig");
const proc = @import("proc.zig");
const spinlock = @import("spinlock.zig");
const uart = @import("uart.zig");

// #define C(x)  ((x)-'@')  // Control-x

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

pub const Console = struct {
    lock: spinlock.Spinlock = .{},

    // input
    buf: [128]u8 = [_]u8{0} ** 128,
    r: u32 = 0, // Read index
    w: u32 = 0, // Write index
    e: u32 = 0, // Edit index
};
var cons = Console{
    //    .lock = spinlock.Spinlock{},
    //    .buf = [_]u8{0}**128,
};

//
// user write()s to the console go here.
//
pub fn consolewrite(user_src: i32, src: u64, n: i32) i32 {
    var i: i32 = 0;

    while (i < n) : (i += 1) {
        var c: u8 = 0;
        if (proc.either_copyin(&c, user_src, src + @intCast(u64, i), 1) == -1) {
            break;
        }
        uart.uartputc(c);
    }

    return i;
}

//
// user read()s from the console go here.
// copy (up to) a whole input line to dst.
// user_dist indicates whether dst is a user
// or kernel address.
//
// pub fn consoleread(user_dst: i32, dst: u64, n: i32) i32 {
//   uint target;
//   int c;
//   char cbuf;

//   target = n;
//   acquire(&cons.lock);
//   while(n > 0){
//     // wait until interrupt handler has put some
//     // input into cons.buffer.
//     while(cons.r == cons.w){
//       if(myproc()->killed){
//         release(&cons.lock);
//         return -1;
//       }
//       sleep(&cons.r, &cons.lock);
//     }

//     c = cons.buf[cons.r++ % INPUT_BUF];

//     if(c == C('D')){  // end-of-file
//       if(n < target){
//         // Save ^D for next time, to make sure
//         // caller gets a 0-byte result.
//         cons.r--;
//       }
//       break;
//     }

//     // copy the input byte to the user-space buffer.
//     cbuf = c;
//     if(either_copyout(user_dst, dst, &cbuf, 1) == -1)
//       break;

//     dst++;
//     --n;

//     if(c == '\n'){
//       // a whole line has arrived, return to
//       // the user-level read().
//       break;
//     }
//   }
//   release(&cons.lock);

//   return target - n;
// }

// //
// // the console input interrupt handler.
// // uartintr() calls this for input character.
// // do erase/kill processing, append to cons.buf,
// // wake up consoleread() if a whole line has arrived.
// //
// void
// consoleintr(int c)
// {
//   acquire(&cons.lock);

//   switch(c){
//   case C('P'):  // Print process list.
//     procdump();
//     break;
//   case C('U'):  // Kill line.
//     while(cons.e != cons.w &&
//           cons.buf[(cons.e-1) % INPUT_BUF] != '\n'){
//       cons.e--;
//       consputbackspace();
//     }
//     break;
//   case C('H'): // Backspace
//   case '\x7f':
//     if(cons.e != cons.w){
//       cons.e--;
//       consputbackspace();
//     }
//     break;
//   default:
//     if(c != 0 && cons.e-cons.r < INPUT_BUF){
//       c = (c == '\r') ? '\n' : c;

//       // echo back to the user.
//       consputc(c);

//       // store for consumption by consoleread().
//       cons.buf[cons.e++ % INPUT_BUF] = c;

//       if(c == '\n' || c == C('D') || cons.e == cons.r+INPUT_BUF){
//         // wake up consoleread() if a whole line (or end-of-file)
//         // has arrived.
//         cons.w = cons.e;
//         wakeup(&cons.r);
//       }
//     }
//     break;
//   }

//   release(&cons.lock);
// }

pub fn consoleinit() void {
    spinlock.initlock(&cons.lock, "cons");

    uart.uartinit();

    // connect read and write system calls
    // to consoleread and consolewrite.
    //file.devsw[file.CONSOLE].read = consoleread;
    file.devsw[file.CONSOLE].write = consolewrite;
}
