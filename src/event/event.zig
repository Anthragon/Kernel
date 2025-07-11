const std = @import("std");
const root = @import("root");
const debug = root.debug;
const interop = root.interop;
const modules = root.modules;

const Module = modules.Module;
const Result = interop.Result;

const allocator = root.mem.heap.kernel_buddy_allocator;

var class_map: std.StringHashMapUnmanaged(EventClassEntry) = .empty;

pub fn init() void {
}

pub export fn register_event_class(
    module_uuid: u128,
    class_name: [*:0]const u8,
    signals: [*]const RegisterRequestSignalEntry,
) Result(void) {

    register_event_class_internal(
        module_uuid,
        std.mem.sliceTo(class_name, 0),
        signals
    ) catch |err| return switch (err) {
        else => .err(.unexpected)
    };

    return .retvoid();
}
pub fn register_event_class_internal(
    module_uuid: u128,
    class_name: []const u8,
    signals: [*]const RegisterRequestSignalEntry,
) !void {

    const mod = modules.get_module_by_uuid(@bitCast(module_uuid))
        orelse return error.ModuleNotFound;

    const classcopy = try allocator.dupeZ(u8, class_name);
    errdefer allocator.free(classcopy);

    try class_map.put(allocator, classcopy, .{
        .identifier = classcopy,
        .module = mod,
    });
    var new_class = class_map.getPtr(classcopy).?;
    errdefer _ = class_map.remove(classcopy);

    errdefer { // In case of the while fails TODO

    }

    var i: usize = 0;
    while (signals[i].name != null) : (i += 1) {

        const signame = try allocator.dupeZ(u8, std.mem.sliceTo(signals[i].name.?, 0));
        try new_class.signals.put(allocator, signame, .{
            .identifier = signame
        });

    }

    debug.err("Module {s} registred signal class {s} with {} signals\n", .{
        mod.name, class_name, new_class.signals.count() });
}


const EventClassEntry = struct {
    identifier: [:0]const u8,
    module: *Module,

    signals: std.StringHashMapUnmanaged(EventSignalEntry) = .empty
};
const EventSignalEntry = struct {
    identifier: [:0]const u8,
};

const RegisterRequestSignalEntry = extern struct {
    name: ?[*:0]const u8,
};
