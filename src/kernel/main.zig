const uart = @intToPtr(*volatile u8, 0x10000000);

fn putchar(c: u8) void {
    uart.* = c;
}

fn print(str: []const u8) void {
    for (str) |c| {
        putchar(c);
    }
}

pub export fn main() void {
    print("valtos\n");
}
