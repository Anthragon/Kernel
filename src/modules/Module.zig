const std = @import("std");
const root = @import("root");

name: [:0]const u8,
version: [:0]const u8,
author: [:0]const u8,
license: [:0]const u8,
uuid: root.utils.Guid,

abi_version: usize,
flags: packed struct {
    needs_privilege: bool,
    _rsvd: u63 = 0,
},

init: *const fn () callconv(.c) bool,
deinit: *const fn () callconv(.c) void,

allocator: root.mem.vmm.BuddyAllocator,
status: ModuleStatus,

pub const ModuleStatus = enum {
    Waiting,
    Ready,
    Failed,
    Active,
};

pub fn initialize(self: *@This()) bool {
    // initializes vtable and allocator
    root.modules.resolve_module(self);
    return self.init();
}
