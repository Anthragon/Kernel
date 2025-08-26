pub const FileSystemEntry = extern struct {

    name: ?[*:0]const u8,
    vtable: *const VTable,

    pub const VTable = extern struct {
        scan: *const fn (part: *anyopaque) callconv(.c) bool,
        mount: *const fn (part: *anyopaque) callconv(.c) void,
    };
};
