const std = @import("std");
const root = @import("root");

name: [:0]const u8,
version: [:0]const u8,
author: [:0]const u8,
license: [:0]const u8,
uuid: root.utils.Guid,

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
