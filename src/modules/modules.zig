const std = @import("std");
const root = @import("root");
const system = root.system;
const debug = root.debug;
const interop = root.interop;
const utils = root.utils;

const log = std.log.scoped(.modules);

const Result = interop.Result;
const Guid = utils.Guid;

const allocator = root.mem.heap.kernel_buddy_allocator;

var modules_map: std.AutoArrayHashMapUnmanaged(u128, Module) = .empty;
var unitialized_list: std.ArrayListUnmanaged(u128) = .empty;

pub fn init() void {
    log.debug(" ## Setting up modules service...", .{});
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

pub export fn register_module(
    name: [*:0]const u8,
    version: [*:0]const u8,
    author: [*:0]const u8,
    license: [*:0]const u8,
    uuid: u128,
    init_func: *const fn () callconv(.c) bool,
    deinit_func: *const fn () callconv(.c) void,
) Result(void) {
    register_module_internal(
        std.mem.sliceTo(name, 0),
        std.mem.sliceTo(version, 0),
        std.mem.sliceTo(author, 0),
        std.mem.sliceTo(license, 0),
        uuid,

        init_func,
        deinit_func,
    ) catch |err| return switch (err) {
        error.ModuleAlreadyRegistered => .err(.nameAlreadyUsed),
        else => .err(.unexpected),
    };
    return .retvoid();
}
fn register_module_internal(
    name: []const u8,
    version: []const u8,
    author: []const u8,
    license: []const u8,
    uuid: u128,
    init_func: *const fn () callconv(.c) bool,
    deinit_func: *const fn () callconv(.c) void,
) !void {

    // Check if the module is already registered
    if (modules_map.contains(uuid)) {
        log.debug("Module '{s}' is already registered.", .{name});
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
        .uuid = root.utils.Guid.fromInt(uuid),

        .init = init_func,
        .deinit = deinit_func,

        .status = ModuleStatus.Waiting,
        .permissions = undefined,
    }) catch @panic("OOM");
    unitialized_list.append(allocator, uuid) catch @panic("OOM");

    // TODO some logic to wake up adam

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

pub const Module = struct {
    name: []const u8,
    version: []const u8,
    author: []const u8,
    license: []const u8,
    uuid: root.utils.Guid,

    init: *const fn () callconv(.c) bool,
    deinit: *const fn () callconv(.c) void,

    status: ModuleStatus,
    permissions: ModulePermissions,
};

pub const ModuleStatus = enum { Waiting, Ready, Failed, Active };

pub const ModulePermissions = packed struct(u64) { pci_devices: bool = false, acpi_devices: bool = false, usb_devices: bool = false, _: u61 = 0 };
