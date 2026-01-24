const std = @import("std");
const root = @import("root");
const interop = root.interop;

const Guid = root.utils.Guid;
const Result = interop.Result;

const kernel_allocator = root.mem.heap.kernel_buddy_allocator;

pub const Callable = *const anyopaque;
pub const Event = extern struct {
    pub const EventOnBindCallback = *const fn (*const anyopaque, ?*anyopaque) callconv(.c) bool;
    pub const EventOnUnbindCallback = *const fn (*const anyopaque) callconv(.c) void;

    bind_callback: EventOnBindCallback,
    unbind_callback: EventOnUnbindCallback,

    pub fn bind(s: @This(), func: *const anyopaque, ctx: ?*anyopaque) callconv(.c) bool {
        return s.bind_callback(func, ctx);
    }
    pub fn unbind(s: @This(), func: *const anyopaque) callconv(.c) void {
        s.unbind_callback(func);
    }
};
pub const Property = struct {
    pub const PropertyGetterCallback = *const fn (?*const anyopaque) callconv(.c) usize;
    pub const PropertySetterCallback = *const fn (?*const anyopaque, usize) callconv(.c) void;

    getter_callback: PropertyGetterCallback,
    setter_callback: PropertySetterCallback,
};

pub const CapKind = enum { callable, property, event };
const CapData = struct {
    module_guid: Guid,

    full_identifier: [:0]const u8,
    namespace: []const u8,
    symbol: []const u8,

    data: union(CapKind) {
        callable: Callable,
        property: Property,
        event: Event,
    },
};

var arena: std.heap.ArenaAllocator = undefined;
var allocator: std.mem.Allocator = undefined;

const log = std.log.scoped(.capabilities);

var capabilities_map: std.StringArrayHashMapUnmanaged(CapData) = .empty;

pub fn init() void {
    arena = .init(kernel_allocator);
    allocator = arena.allocator();

    { // Internal memory related
        register_callable(
            Guid.zero(),
            "Memory",
            "lsmemtable",
            root.mem.lsmemtable,
        ) catch |err| std.debug.panic("{s}", .{@errorName(err)});
    }
}

pub fn lscaps() void {
    log.warn("lscaps", .{});
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(allocator);

    var writer = buf.writer(allocator);

    for (capabilities_map.values()) |v| {
        switch (v.data) {
            .callable => |c| writer.print(
                "[{f}] C {s: <50} -> 0x{x:0>16}\n",
                .{ v.module_guid, v.full_identifier, @intFromPtr(c) },
            ) catch root.oom_panic(),
            .property => |c| writer.print(
                "[{f}] P {s: <50} -> {{ get = 0x{x:0>16}, set = 0x{x:0>16} }}\n",
                .{ v.module_guid, v.full_identifier, @intFromPtr(c.getter_callback), @intFromPtr(c.setter_callback) },
            ) catch root.oom_panic(),
            .event => |c| writer.print(
                "[{f}] E {s: <50} -> {{ bind = 0x{x:0>16}, unbind = 0x{x:0>16} }}\n",
                .{ v.module_guid, v.full_identifier, @intFromPtr(c.bind_callback), @intFromPtr(c.unbind_callback) },
            ) catch root.oom_panic(),
        }
    }

    log.info("{s}", .{buf.items});
}

pub fn c__register_callable(
    module_uuid: Guid,
    namespace: [*:0]const u8,
    symbol: [*:0]const u8,
    callback: *const anyopaque,
) callconv(.c) Result(void) {
    return .frombuiltin(register_callable(
        module_uuid,
        std.mem.sliceTo(namespace, 0),
        std.mem.sliceTo(symbol, 0),
        callback,
    ));
}
/// Provides a zig interface for creating a new callable in the capabilities tree
pub fn register_callable(
    module_uuid: Guid,
    namespace: []const u8,
    symbol: []const u8,
    callback: *const anyopaque,
) !void {
    const full_name_dup = try std.fmt.allocPrintSentinel(
        allocator,
        "{s}::{s}",
        .{ namespace, symbol },
        0,
    );
    errdefer allocator.free(full_name_dup);
    const nmsp_dup = full_name_dup[0..namespace.len];
    const symb_dup = full_name_dup[namespace.len + 2 .. full_name_dup.len];

    if (capabilities_map.contains(full_name_dup)) return error.alreadyExists;

    try capabilities_map.put(allocator, full_name_dup, .{
        .module_guid = module_uuid,
        .full_identifier = full_name_dup,
        .namespace = nmsp_dup,
        .symbol = symb_dup,
        .data = .{ .callable = callback },
    });
}

pub fn comptime_register_callable(
    comptime module_uuid: Guid,
    comptime namespace: []const u8,
    comptime symbol: []const u8,
    comptime callback: *const anyopaque,
) !void {
    comptime {
        const comptime_symbol = std.fmt.comptimePrint(
            "cap privileged_callable [{f}]{s}::{s}",
            .{ module_uuid, namespace, symbol },
        );
        const exportOptions: std.builtin.ExportOptions = .{ .name = comptime_symbol };
        @export(callback, exportOptions);
    }
    try register_callable(module_uuid, namespace, symbol, callback);
}

pub fn c__register_property(
    module_uuid: Guid,
    namespace: [*:0]const u8,
    symbol: [*:0]const u8,
    getter: Property.PropertyGetterCallback,
    setter: Property.PropertySetterCallback,
) callconv(.c) Result(void) {
    return .frombuiltin(register_property(
        module_uuid,
        std.mem.sliceTo(namespace, 0),
        std.mem.sliceTo(symbol, 0),
        getter,
        setter,
    ));
}
/// Provides a zig interface for creating a new field pointer in the capabilities tree
pub fn register_property(
    module_uuid: Guid,
    namespace: []const u8,
    symbol: []const u8,
    getter: Property.PropertyGetterCallback,
    setter: Property.PropertySetterCallback,
) !void {
    const full_name_dup = try std.fmt.allocPrintSentinel(
        allocator,
        "{s}::{s}",
        .{ namespace, symbol },
        0,
    );
    errdefer allocator.free(full_name_dup);
    const nmsp_dup = full_name_dup[0..namespace.len];
    const symb_dup = full_name_dup[namespace.len + 2 .. full_name_dup.len];

    if (capabilities_map.contains(full_name_dup)) return error.AlreadyExists;

    try capabilities_map.put(allocator, full_name_dup, .{
        .module_guid = module_uuid,
        .full_identifier = full_name_dup,
        .namespace = nmsp_dup,
        .symbol = symb_dup,
        .data = .{ .property = .{
            .getter_callback = getter,
            .setter_callback = setter,
        } },
    });
}

pub fn c__register_event(
    module_uuid: Guid,
    namespace: [*:0]const u8,
    symbol: [*:0]const u8,
    bind: Event.EventOnBindCallback,
    unbind: Event.EventOnUnbindCallback,
) callconv(.c) Result(void) {
    return .frombuiltin(register_event(
        module_uuid,
        std.mem.sliceTo(namespace, 0),
        std.mem.sliceTo(symbol, 0),
        bind,
        unbind,
    ));
}
// Provides a zig interface for creating a new event in the capabilities tree
pub fn register_event(
    module_uuid: Guid,
    namespace: []const u8,
    symbol: []const u8,
    bind: Event.EventOnBindCallback,
    unbind: Event.EventOnUnbindCallback,
) !void {
    const full_name_dup = try std.fmt.allocPrintSentinel(
        allocator,
        "{s}::{s}",
        .{ namespace, symbol },
        0,
    );
    errdefer allocator.free(full_name_dup);
    const nmsp_dup = full_name_dup[0..namespace.len];
    const symb_dup = full_name_dup[namespace.len + 2 .. full_name_dup.len];

    if (capabilities_map.contains(full_name_dup)) return error.AlreadyExists;

    try capabilities_map.put(allocator, full_name_dup, .{
        .module_guid = module_uuid,
        .full_identifier = full_name_dup,
        .namespace = nmsp_dup,
        .symbol = symb_dup,
        .data = .{ .event = .{
            .bind_callback = bind,
            .unbind_callback = unbind,
        } },
    });
}

pub fn get_callable(full_name: []const u8) !?Callable {
    const a = capabilities_map.get(full_name) orelse return null;
    if (a.data != .callable) return error.wrongType;
    return a.data.callable;
}
pub fn get_property(full_name: []const u8) ?Property {
    const a = capabilities_map.get(full_name) orelse return null;
    if (a.data != .property) return error.wrongType;
    return a.data.property;
}
pub fn get_event(full_name: []const u8) ?Event {
    const a = capabilities_map.get(full_name) orelse return null;
    if (a.data != .event) return error.wrongType;
    return a.data.event;
}
