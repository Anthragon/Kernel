const root = @import("root.zig");
const Result = root.interop.Result;

pub const fs = .{
    .append_file_system = *const fn(root.FileSystemEntry) callconv(.c) Result(void),
    .remove_file_system = *const fn(?[*:0]const u8) callconv(.c) void,
};

pub const device = .{

    .mass_storage = .{
        .get_disk_by_identifier = *const fn([*:0]const u8) callconv(.c) ?*anyopaque,
        .get_disk_by_identifier_part_by_identifier = *const fn([*:0]const u8, [*:0]const u8) callconv(.c) ?*anyopaque,
    
        .DiskEntry__read = *const fn(*anyopaque, usize, [*]u8, usize) callconv(.c) bool,
        .PartEntry__read = *const fn(*anyopaque, usize, [*]u8, usize) callconv(.c) bool,
    },

};
