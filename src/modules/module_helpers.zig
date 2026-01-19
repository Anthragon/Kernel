const std = @import("std");
const root = @import("root");
const modules = @import("modules.zig");

const Guid = root.utils.Guid;

const log = std.log.scoped(.@"Module Helper");
const module_log = std.log.scoped(.Module);

const allocator = root.mem.heap.kernel_buddy_allocator;
const Alignment = std.mem.Alignment;

comptime {
    @export(&root.capabilities.c__register_callable, .{ .name = "Anthragon:buildin_register_capability_callable" });
    @export(&root.capabilities.c__register_property, .{ .name = "Anthragon:buildin_register_capability_property" });
    @export(&root.capabilities.c__register_event, .{ .name = "Anthragon:buildin_register_capability_event" });

    @export(&m_panic, .{ .name = "cap privileged_callable [00000000-0000-0000-0000-000000000000]System.ModuleHelper::panic" });

    @export(&m_log_info, .{ .name = "cap privileged_callable [00000000-0000-0000-0000-000000000000]System.ModuleHelper::log_info" });
    @export(&m_log_debug, .{ .name = "cap privileged_callable [00000000-0000-0000-0000-000000000000]System.ModuleHelper::log_debug" });
    @export(&m_log_warn, .{ .name = "cap privileged_callable [00000000-0000-0000-0000-000000000000]System.ModuleHelper::log_warn" });
    @export(&m_log_err, .{ .name = "cap privileged_callable [00000000-0000-0000-0000-000000000000]System.ModuleHelper::log_err" });

    @export(&m_malloc, .{ .name = "cap privileged_callable [00000000-0000-0000-0000-000000000000]System.ModuleHelper::malloc" });
    @export(&m_mresize, .{ .name = "cap privileged_callable [00000000-0000-0000-0000-000000000000]System.ModuleHelper::mresize" });
    @export(&m_mremap, .{ .name = "cap privileged_callable [00000000-0000-0000-0000-000000000000]System.ModuleHelper::mremap" });
    @export(&m_mfree, .{ .name = "cap privileged_callable [00000000-0000-0000-0000-000000000000]System.ModuleHelper::mfree" });
}

pub fn register_helpers() void {}

fn m_panic(module_uuid: Guid, message: [*:0]const u8) callconv(.c) noreturn {
    std.debug.panic("Module {f} panic: {s}", .{ module_uuid, message });
}

fn m_log_info(module_uuid: Guid, scope: [*:0]const u8, message: [*:0]const u8) callconv(.c) void {
    const module = modules.get_module_by_uuid(module_uuid).?;
    module_log.info("[{f} {s} {s}] {s}", .{ module_uuid, module.name, scope, message });
}
fn m_log_debug(module_uuid: Guid, scope: [*:0]const u8, message: [*:0]const u8) callconv(.c) void {
    const module = modules.get_module_by_uuid(module_uuid).?;
    module_log.debug("[{f} {s} {s}] {s}", .{ module_uuid, module.name, scope, message });
}
fn m_log_warn(module_uuid: Guid, scope: [*:0]const u8, message: [*:0]const u8) callconv(.c) void {
    const module = modules.get_module_by_uuid(module_uuid).?;
    module_log.warn("[{f} {s} {s}] {s}", .{ module_uuid, module.name, scope, message });
}
fn m_log_err(module_uuid: Guid, scope: [*:0]const u8, message: [*:0]const u8) callconv(.c) void {
    const module = modules.get_module_by_uuid(module_uuid).?;
    module_log.err("[{f} {s} {s}] {s}", .{ module_uuid, module.name, scope, message });
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
