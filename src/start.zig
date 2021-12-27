const std = @import("std");

// pub fn main() anyerror!void {
//     std.log.info("All your codebase are belong to us.", .{});
// }

// unsigned char * uart = (unsigned char *)0x10000000;
// void putchar(char c) {
// 	while(*(uart+))
// 	*uart = c;
// 	return;
// }

// void print(const char * str) {
// 	while(*str != '\0') {
// 		putchar(*str);
// 		str++;
// 	}
// 	return;
// }

// One stack per CPU
const NCPU = 16;
const STACK_SIZE = 4096;
export const stack0 = std.mem.zeroes([NCPU][STACK_SIZE]u8);

const uart = @intToPtr(*volatile u8, 0x10000000);

fn putchar(c: u8) void {
    uart.* = c;
}

fn print(str: []const u8) void {
    for (str) |c| {
        putchar(c);
    }
}

export fn start() void {
    print("Hello world!\r\n");
    // while(1) {
    // 	// Read input from the UART
    // 	putchar(*uart);
    // }
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
