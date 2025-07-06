const std = @import("std");

pub var serial_base: usize = 0x09000000;

const SerialWriter = std.io.Writer(
    *anyopaque,
    error{},
    puts
);

pub fn init() !void {
    
}

pub inline fn writer() SerialWriter {
    return .{ .context = @ptrFromInt(std.math.maxInt(usize)) };
}

fn puts(_: *anyopaque, bytes: []const u8) !usize {
    
    for (bytes) |c| {
        while ((inb(0x18) & (1 << 5)) != 0) {}
        outb(0x00, c);
    }

    return bytes.len;
}


inline fn inb(comptime port: usize) u8 {
    return @as(*u8, @ptrFromInt(serial_base + port)).*;
}
inline fn outb(comptime port: usize, value: u8) void {
    @as(*u8, @ptrFromInt(serial_base + port)).* = value;
}