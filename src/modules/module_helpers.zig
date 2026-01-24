const std = @import("std");
const root = @import("root");
const modules = @import("modules.zig");
const capabilities = root.capabilities;

const Guid = root.utils.Guid;

const module_log = std.log.scoped(.Module);

const allocator = root.mem.heap.kernel_buddy_allocator;
const Alignment = std.mem.Alignment;

comptime {
    @export(&root.capabilities.c__register_callable, .{ .name = "Anthragon:buildin_register_capability_callable" });
    @export(&root.capabilities.c__register_property, .{ .name = "Anthragon:buildin_register_capability_property" });
    @export(&root.capabilities.c__register_event, .{ .name = "Anthragon:buildin_register_capability_event" });
}

pub fn register_helpers() void {
    capabilities.comptime_register_callable(.zero(), "System.ModuleHelper", "panic", m_panic) catch @panic("Not able to register system capability");
    capabilities.comptime_register_callable(.zero(), "System.ModuleHelper", "log_info", m_log_info) catch @panic("Not able to register system capability");
    capabilities.comptime_register_callable(.zero(), "System.ModuleHelper", "log_debug", m_log_debug) catch @panic("Not able to register system capability");
    capabilities.comptime_register_callable(.zero(), "System.ModuleHelper", "log_warn", m_log_warn) catch @panic("Not able to register system capability");
    capabilities.comptime_register_callable(.zero(), "System.ModuleHelper", "log_err", m_log_err) catch @panic("Not able to register system capability");
    capabilities.comptime_register_callable(.zero(), "System.ModuleHelper", "malloc", m_malloc) catch @panic("Not able to register system capability");
    capabilities.comptime_register_callable(.zero(), "System.ModuleHelper", "mresize", m_mresize) catch @panic("Not able to register system capability");
    capabilities.comptime_register_callable(.zero(), "System.ModuleHelper", "mremap", m_mremap) catch @panic("Not able to register system capability");
    capabilities.comptime_register_callable(.zero(), "System.ModuleHelper", "mfree", m_mfree) catch @panic("Not able to register system capability");
}

fn m_panic(module_uuid: Guid, message: [*:0]const u8) callconv(.c) noreturn {
    std.debug.panic("Module {f} panic: {s}", .{ module_uuid, message });
}

fn m_log_info(module_uuid: Guid, scope: [*:0]const u8, message: [*:0]const u8) callconv(.c) void {
    const module = modules.get_module_by_uuid(module_uuid).?;
    root.debug.print(
        .info,
        .@"Module Helper",
        "[ {s: <8} {s: <7} info  ] {s}",
        true,
        .{ module.name, scope, message },
    );
}
fn m_log_debug(module_uuid: Guid, scope: [*:0]const u8, message: [*:0]const u8) callconv(.c) void {
    const module = modules.get_module_by_uuid(module_uuid).?;
    root.debug.print(
        .debug,
        .@"Module Helper",
        "[ {s: <8} {s: <7} debug ] {s}",
        true,
        .{ module.name, scope, message },
    );
}
fn m_log_warn(module_uuid: Guid, scope: [*:0]const u8, message: [*:0]const u8) callconv(.c) void {
    const module = modules.get_module_by_uuid(module_uuid).?;
    root.debug.print(
        .warn,
        .@"Module Helper",
        "[ {s: <8} {s: <7} warn  ] {s}",
        true,
        .{ module.name, scope, message },
    );
}
fn m_log_err(module_uuid: Guid, scope: [*:0]const u8, message: [*:0]const u8) callconv(.c) void {
    const module = modules.get_module_by_uuid(module_uuid).?;
    root.debug.print(
        .err,
        .@"Module Helper",
        "[ {s: <8} {s: <7} err   ] {s}",
        true,
        .{ module.name, scope, message },
    );
}

fn m_malloc(module_uuid: Guid, length: usize, alignment: usize) callconv(.c) ?[*]u8 {
    const m = modules.get_module_by_uuid(module_uuid).?;
    const a = m.allocator.allocator();
    return a.vtable.alloc(
        a.ptr,
        length,
        .fromByteUnits(alignment),
        @returnAddress(),
    );
}
fn m_mresize(module_uuid: Guid, old_mem: [*]u8, old_len: usize, new_len: usize, alignment: usize) callconv(.c) bool {
    const m = modules.get_module_by_uuid(module_uuid).?;
    const a = m.allocator.allocator();
    return a.vtable.resize(
        a.ptr,
        old_mem[0..old_len],
        .fromByteUnits(alignment),
        new_len,
        @returnAddress(),
    );
}
fn m_mremap(module_uuid: Guid, old_mem: [*]u8, old_len: usize, new_len: usize, alignment: usize) callconv(.c) ?[*]u8 {
    const m = modules.get_module_by_uuid(module_uuid).?;
    const a = m.allocator.allocator();
    return a.vtable.remap(
        a.ptr,
        old_mem[0..old_len],
        .fromByteUnits(alignment),
        new_len,
        @returnAddress(),
    );
}
fn m_mfree(module_uuid: Guid, mem: [*]u8, len: usize, alignment: usize) callconv(.c) void {
    const m = modules.get_module_by_uuid(module_uuid).?;
    const a = m.allocator.allocator();
    a.vtable.free(
        a.ptr,
        mem[0..len],
        .fromByteUnits(alignment),
        @returnAddress(),
    );
}
