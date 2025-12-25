const root = @import("root.zig");
const Result = root.interop.Result;

pub const fs = .{
    .lsdir = *const fn (*root.common.FsNode) callconv(.c) void,
    .lsroot = *const fn () callconv(.c) void,
    .chroot = *const fn (*root.common.FsNode) callconv(.c) void,
    .append_file_system = *const fn (root.common.FileSystemEntry) callconv(.c) Result(void),
    .remove_file_system = *const fn (?[*:0]const u8) callconv(.c) void,
};

pub const device = .{
    .on_registered_callback = *const fn (usize) void,

    .mass_storage = .{
        .get_disk_by_identifier = *const fn ([*:0]const u8) callconv(.c) ?*anyopaque,
        .get_disk_by_identifier_part_by_identifier = *const fn ([*:0]const u8, [*:0]const u8) callconv(.c) ?*anyopaque,

        .DiskEntry__read = *const fn (*anyopaque, usize, [*]u8, usize) callconv(.c) bool,
        .PartEntry__read = *const fn (*anyopaque, usize, [*]u8, usize) callconv(.c) bool,
    },
};
