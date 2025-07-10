const std = @import("std");
const root = @import("root");
const interop = root.interop;
const Module = root.modules.Module;

const allocator = root.mem.heap.kernel_buddy_allocator;

var class_map: std.StringHashMapUnmanaged(EventClassEntry) = .empty;

pub fn init() void {
}

pub export fn register_event_class(
    module_name: [*:0]const u8,
    class_name: [*:0]const u8,
    signals: [*]RegisterRequestSignalEntry,
) void {

    _ = module_name;
    _ = class_name;
    _ = signals;

}
pub fn register_event_class_internal(
    module_name: []const u8,
    class_name: []const u8,
    signals: [*]RegisterRequestSignalEntry,
) void {

    _ = module_name;
    _ = class_name;
    _ = signals;

}


const EventClassEntry = struct {
    identifier: [:0]const u8,
    module: Module,

    signals: std.StringHashMapUnmanaged(EventSignalEntry) = .empty
};
const EventSignalEntry = struct {
    identifier: [:0]const u8,
};

const RegisterRequestSignalEntry = extern struct {
    name: ?[*:0]const u8,
};
