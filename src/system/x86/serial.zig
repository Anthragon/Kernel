const std = @import("std");

const SerialWriter = std.io.Writer(
    *anyopaque,
    error{},
    serial_out
);

pub fn init() !void {
    
}

pub inline fn writer() SerialWriter {
    return .{ .context = null };
}

fn serial_out(_: *anyopaque, bytes: []const u8) !usize {
    _ = bytes;
    return 0;
}
