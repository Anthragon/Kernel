pub const Module = extern struct {
    name: [*:0]const u8,
    version: [*:0]const u8,
    author: [*:0]const u8,
    license: [*:0]const u8,
    uuid: u128,

    abi_ver: usize,
    flags: packed struct {
        needs_privilege: bool,
        _rsvd: u63 = 0,
    },

    init: *const fn () callconv(.c) bool,
    deinit: *const fn () callconv(.c) void,
};
