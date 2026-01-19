const std = @import("std");
const root = @import("root");
const lib = @import("lib");
const system = root.system;
const debug = root.debug;
const interop = root.interop;
const utils = root.utils;
const module_helpers = @import("module_helpers.zig");

const log = std.log.scoped(.modules);

const Result = interop.Result;
const Guid = utils.Guid;
const Module = @import("Module.zig");

const allocator = root.mem.heap.kernel_buddy_allocator;

var modules_map: std.AutoArrayHashMapUnmanaged(u128, Module) = .empty;
var unitialized_list: std.ArrayListUnmanaged(u128) = .empty;

pub fn init() void {
    log.debug(" ## Setting up modules service...", .{});
    module_helpers.register_helpers();
}

pub fn lsmodules() void {
    log.warn("lsmodules", .{});
    log.info("Listing active modules:", .{});
    for (modules_map.values()) |i| {
        log.info("{f} - {s} {s} by {s} ({s} liscence) - {s}", .{ i.uuid, i.name, i.version, i.author, i.license, @tagName(i.status) });
    }
}

pub inline fn get_module_by_uuid(uuid: Guid) ?*Module {
    return modules_map.getPtr(@bitCast(uuid));
}

pub fn register_module(descriptor: lib.common.Module) callconv(.c) Result(void) {
    register_module_internal(
        std.mem.sliceTo(descriptor.name, 0),
        std.mem.sliceTo(descriptor.version, 0),
        std.mem.sliceTo(descriptor.author, 0),
        std.mem.sliceTo(descriptor.license, 0),
        @bitCast(descriptor.uuid),
        @bitCast(descriptor.flags),
        descriptor.init,
        descriptor.deinit,
    ) catch |err| return switch (err) {
        error.ModuleAlreadyRegistered => .err(.nameAlreadyUsed),
        else => .err(.unexpected),
    };
    return .retvoid();
}
fn register_module_internal(
    name: [:0]const u8,
    version: [:0]const u8,
    author: [:0]const u8,
    license: [:0]const u8,
    uuid: lib.utils.Guid,
    flags: usize,
    init_func: *const fn () callconv(.c) bool,
    deinit_func: *const fn () callconv(.c) void,
) !void {

    // Check if the module is already registered
    if (modules_map.contains(@bitCast(uuid))) {
        log.debug("Module '{s}' ({f}) is already registered.", .{ name, uuid });
        return error.ModuleAlreadyRegistered;
    }

    const namecopy = try allocator.dupeZ(u8, name);
    errdefer allocator.free(namecopy);
    const vercopy = try allocator.dupeZ(u8, version);
    errdefer allocator.free(vercopy);
    const autcopy = try allocator.dupeZ(u8, author);
    errdefer allocator.free(autcopy);
    const liccopy = try allocator.dupeZ(u8, license);
    errdefer allocator.free(liccopy);

    modules_map.put(allocator, @bitCast(uuid), .{
        .name = namecopy,
        .version = vercopy,
        .author = autcopy,
        .license = liccopy,
        .uuid = uuid,

        .flags = @bitCast(flags),

        .init = init_func,
        .deinit = deinit_func,

        .allocator = undefined,
        .status = .Waiting,
    }) catch root.oom_panic();
    unitialized_list.append(allocator, @bitCast(uuid)) catch root.oom_panic();

    // TODO some logic to wake up adam
}

pub fn resolve_module(module: *Module) void {
    log.info("Resolving dependencies of module '{s}'", .{module.name});
    module.allocator = .init(allocator);
}

pub inline fn has_waiting_modules() bool {
    return unitialized_list.items.len > 0;
}
pub inline fn get_next_waiting_module() ?*Module {
    if (unitialized_list.items.len == 0) {
        log.debug("No waiting modules to pop.", .{});
        return null;
    }
    return modules_map.getPtr(unitialized_list.orderedRemove(0));
}
