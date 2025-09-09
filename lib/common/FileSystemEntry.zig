const root = @import("../root.zig");

pub const FileSystemEntry = extern struct {

    name: ?[*:0]const u8,
    vtable: *const VTable,

    pub const VTable = extern struct {
        scan:  *const fn (part: *root.common.PartEntry) callconv(.c) bool,
        mount: *const fn (part: *root.common.PartEntry) callconv(.c) root.common.FsNode,
    };
};
