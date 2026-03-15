const root = @import("../root.zig");
const Guid = root.utils.Guid;
const Result = root.interop.Result;

pub const Status = enum(usize) {
    failed = 0,
    unset,

    unbinded,
    working,
};

pub const RegisterInfo = extern struct {
    id: usize = 0,
    name: [*:0]const u8,

    identifier: Guid,
    specifier: usize,
    interface: Guid,

    flags: packed struct(u8) {
        canSee: root.Privilege,
        canReed: root.Privilege,
        canWrite: root.Privilege,

        _rsvd: u5 = 0,
    },

    status: Status = .unset,
    implPointer: *anyopaque,
    implVtable: *const VTable,
};

pub const VTable = extern struct {
    control: *const fn (devicePtr: *anyopaque, ctlValue: [*]usize, ctlLen: usize) callconv(.c) Result(usize),
};
