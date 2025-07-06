const std = @import("std");
const root = @import("root");
const ports = @import("ports.zig");

pub const options: std.Options = .{
    .page_size_min = 4096,
    .page_size_max = 4096,

    .enable_segfault_handler = false,

    .logFn = logFn,
    .cryptoRandomSeed = criptoRandomSeed,
    .crypto_always_getrandom = true,
};

fn logFn(comptime message_level: std.log.Level, comptime scope: @TypeOf(.enum_literal), comptime format: []const u8, args: anytype) void {
    _ = message_level;
    _ = scope;

    root.debug.print(format, args);
}

fn criptoRandomSeed(buffer: []u8) void {

    const timestamp = root.system.time.timestamp();
    const io_entropy = ports.inb(0x40);

    var seed = timestamp ^ (@as(u64, io_entropy) << 56);

    for (buffer, 0..) |*b, i| {
        seed ^= seed >> 12;
        seed ^= seed << 25;
        seed ^= seed >> 27;
        seed = seed *% 0x2545F4914F6CDD1D;

        b.* = @truncate(std.math.shr(usize, seed, (i & 7)));
    }
}
