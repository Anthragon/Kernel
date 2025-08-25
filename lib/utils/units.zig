pub const data = [_]struct { name: []const u8, size: u128 } {
    .{ .name = "PiB", .size = 1024 * 1024 * 1024 * 1024 * 1024 },
    .{ .name = "TiB", .size = 1024 * 1024 * 1024 * 1024 },
    .{ .name = "GiB", .size = 1024 * 1024 * 1024 },
    .{ .name = "MiB", .size = 1024 * 1024 },
    .{ .name = "KiB", .size = 1024 },
    .{ .name = "B",   .size = 0 },
};