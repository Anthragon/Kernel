const std = @import("std");
const root = @import("root");
const system = root.system;
const debug = root.debug;
const interop = root.interop;
const utils = root.utils;

const log = std.log.scoped(.devices);

const Device = @import("Device.zig");
const Result = interop.Result;
const Guid = utils.Guid;

var arena: std.heap.ArenaAllocator = undefined;
var allocator: std.mem.Allocator = undefined;

var devices_list: std.ArrayListUnmanaged(?*Device) = .empty;
var devices_res: *root.capabilities.Node = undefined;

const OnDeviceRegisterEntryCtx = extern struct {
    guid: Guid,
    subclass: usize,

    pub fn isNull(self: *@This()) bool {
        return self.guid.isZero();
    }
};
const OnDeviceRegisterEntry = struct {
    context: []const OnDeviceRegisterEntryCtx,
    callback: root.lib.callables.device.on_registered_callback,
};
var device_register_callbacks: std.ArrayListUnmanaged(OnDeviceRegisterEntry) = .empty;

pub fn init() void {
    log.debug(" ## Setting up devices service...", .{});

    arena = .init(root.mem.heap.kernel_buddy_allocator);
    allocator = arena.allocator();

    devices_res = root.capabilities.get_node("Devices").?;

    _ = root.capabilities.create_callable(devices_res, "lsdev", @ptrCast(&lsdev)) catch unreachable;
    _ = root.capabilities.create_callable(devices_res, "register_device", @ptrCast(&c__register_device)) catch unreachable;
    _ = root.capabilities.create_callable(devices_res, "remove_device", @ptrCast(&c__remove_device)) catch unreachable;
    _ = root.capabilities.create_callable(devices_res, "set_status", @ptrCast(&c__set_status)) catch unreachable;

    _ = root.capabilities.create_event(devices_res, "on_device_registered", on_device_registered_bind, on_pci_device_probe_unbind) catch unreachable;

}

fn c__register_device(
    devname: [*:0]const u8,
    identifier: u128,
    subclass: usize,
    canSee: usize,
    canRead: usize,
    canControl: usize,
) callconv(.c) Result(usize) {
    return .val(register_device(
        std.mem.sliceTo(devname, 0),
        @bitCast(identifier),
        subclass,
        @enumFromInt(@as(u1, @truncate(canSee))),
        @enumFromInt(@as(u1, @truncate(canRead))),
        @enumFromInt(@as(u1, @truncate(canControl))),
    ) catch |err| switch (err) {
        .DoesNotExist => return .err(.notFound),
        else => return .err(.unexpected),
    });
}
fn c__remove_device(dev: usize) callconv(.c) Result(void) {
    remove_device(dev) catch |err| switch (err) {
        error.DoesNotExist => return .err(.notFound),
    };

    return .retvoid();
}
fn c__set_status(dev: usize, status: usize) callconv(.c) Result(void) {
    return .val(set_status(dev, @enumFromInt(status)) catch |err| switch (err) {
        error.DoesNotExist => return .err(.notFound),
    });
}

fn register_device(
    devname: []const u8,
    identifier: Guid,
    subclass: usize,
    canSee: root.lib.Privilege,
    canRead: root.lib.Privilege,
    canControl: root.lib.Privilege,
) !usize {
    const nameclone = allocator.dupeZ(u8, devname) catch root.oom_panic();
    errdefer allocator.free(nameclone);

    const dev = allocator.create(Device) catch root.oom_panic();
    errdefer allocator.free(dev);

    dev.* = .{
        .name = nameclone,
        .identifier = identifier,
        .subclass = subclass,
        .status = .unbinded,
        .canSee = canSee,
        .canRead = canRead,
        .canControl = canControl,
    };

    const index = devices_list.items.len;
    devices_list.append(allocator, dev) catch root.oom_panic();
    run_device_registered_all_callbacks(index, dev);
    return index;
}
fn remove_device(dev: usize) !void {
    const d = devices_list.items[dev];
    if (d != null) return error.DoesNotExist;

    allocator.destroy(d.?);
    devices_list.items[dev] = null;
}
fn set_status(dev: usize, status: Device.DeviceStatus) !void {
    const d = devices_list.items[dev];
    if (d == null) return error.DoesNotExist;

    d.?.status = status;
}

fn on_device_registered_bind(callback: *const anyopaque, ctx: ?*anyopaque) callconv(.c) bool {
    const devidlist = brk: {
        if (ctx == null) return false;
        const devlist: [*]OnDeviceRegisterEntryCtx = @ptrCast(@alignCast(ctx.?));
        var i: usize = 0;
        while (!devlist[i].isNull()) i += 1;
        break :brk devlist[0..i];
    };

    const entry = OnDeviceRegisterEntry{
        .callback = @ptrCast(@alignCast(callback)),
        .context = devidlist,
    };
    device_register_callbacks.append(allocator, entry) catch root.oom_panic();

    run_all_devices_registered_callback(entry);
    return true;
}
fn on_pci_device_probe_unbind(callback: *const anyopaque) callconv(.c) void {
    for (device_register_callbacks.items, 0..) |i, idx| {
        if (@intFromPtr(i.callback) == @intFromPtr(callback)) {
            _ = device_register_callbacks.swapRemove(idx);
            break;
        }
    }
}

fn run_device_registered_all_callbacks(i: usize, dev: *Device) void {
    for (device_register_callbacks.items) |e| {
        const ctx = e.context;

        for (ctx) |ii| {
            if (ii.guid != dev.identifier) continue;
            if (ii.subclass != 0 and dev.subclass != ii.subclass) continue;

            e.callback(i);
            break;
        }
    }
}
fn run_all_devices_registered_callback(entry: OnDeviceRegisterEntry) void {
    for (devices_list.items, 0..) |dev, i| {
        if (dev == null) continue;
        for (entry.context) |contexts| {
            if (contexts.guid != dev.?.identifier) continue;
            if (contexts.subclass != 0 and dev.?.subclass != contexts.subclass) continue;

            entry.callback(i);
        }
    }
}

fn lsdev() callconv(.c) void {
    log.warn("lsdev", .{});
    log.info("Listing active devices:", .{});

    for (devices_list.items, 0..) |dev, i| {
        if (dev == null) continue;
        log.info(
            "{} - {f}",
            .{ i, dev.? },
        );
    }
}
