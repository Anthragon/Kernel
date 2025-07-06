const std = @import("std");
const root = @import("root");
const system = root.system;
const debug = root.debug;
const allocator = root.mem.heap.kernel_buddy_allocator;

const ModulesList = std.ArrayList(*Module);
var modules_list: ModulesList = undefined;
var unitialized_modules_list: ModulesList = undefined;

pub fn init() void {
    debug.err("Initializing modules service...\n", .{});

    modules_list = ModulesList.init(allocator);
    unitialized_modules_list = ModulesList.init(allocator);
}

pub fn lsmodules() void {
    debug.print("Listing active modules:\n", .{});
    for (modules_list.items) |i| {
        debug.print("{s} {s} by {s} ({s} liscence) - {s}\n", .{ i.name, i.version, i.author, i.license, @tagName(i.status) });
    }
}


pub export fn register_module(
    name: [*:0]const u8,
    version: [*:0]const u8,
    author: [*:0]const u8,
    license: [*:0]const u8,

    init_func:   *const fn () callconv(.c) bool,
    deinit_func: *const fn () callconv(.c) void,
) bool {
    register_module_internal(
        name,
        version,
        author,
        license,

        init_func,
        deinit_func,
    ) catch |err| {
        debug.err("Error registering module '{s}': {s}\n", .{name, @errorName(err)});
        return false;
    };
    return true;
}
fn register_module_internal(
    name: [*:0]const u8,
    version: [*:0]const u8,
    author: [*:0]const u8,
    license: [*:0]const u8,

    init_func:   *const fn () callconv(.c) bool,
    deinit_func: *const fn () callconv(.c) void,
) !void {

    const name_slice = std.mem.sliceTo(name, 0);
    const version_slice = std.mem.sliceTo(version, 0);
    const author_slice = std.mem.sliceTo(author, 0);
    const license_slice = std.mem.sliceTo(license, 0);

    const module = try allocator.create(Module);
    errdefer allocator.destroy(module);

    module.* = .{
        .name = name_slice,
        .version = version_slice,
        .author = author_slice,
        .license = license_slice,
        .guid = root.utils.Guid.new(),

        .init = init_func,
        .deinit = deinit_func,

        .status = ModuleStatus.Waiting,
        .permissions = undefined,
    };

    // Check if the module is already registered
    for (modules_list.items) |existing_module| {
        if (std.mem.eql(u8, existing_module.name, module.name)) {
            debug.err("Module '{s}' ver. {s} is already registered.\n", .{module.name, module.version});
            return error.ModuleAlreadyRegistered;
        }
    }

    // Add the module to the lists
    try modules_list.append(module);
    errdefer _ = modules_list.pop();
    try unitialized_modules_list.append(module);

    // TODO some logic to wake up adam

}

pub inline fn has_waiting_modules() bool {
    return unitialized_modules_list.items.len > 0;
}
pub inline fn get_next_waiting_module() ?*Module {
    return unitialized_modules_list.pop() orelse {
        debug.err("No waiting modules to pop.\n", .{});
        return null;
    };
}

pub const Module = struct {
    name: []const u8,
    version: []const u8,
    author: []const u8,
    license: []const u8,
    guid: root.utils.Guid,

    init:   *const fn () callconv(.c) bool,
    deinit: *const fn () callconv(.c) void,

    status: ModuleStatus,
    permissions: ModulePermissions,
};

pub const ModuleStatus = enum {
    Waiting,
    Ready,
    Failed,
    Active
};

pub const ModulePermissions = packed struct(u64) {
    pci_devices: bool = false,
    acpi_devices: bool = false,
    usb_devices: bool = false,
    _: u61 = 0
};
