const std = @import("std");
const root = @import("root");
const system = root.system;
const debug = root.debug;
const interop = root.interop;
const utils = root.utils;
const capabilities = root.capabilities;

const log = std.log.scoped(.devices);

const Device = @import("Device.zig");
const Result = interop.Result;
const Guid = utils.Guid;

var arena: std.heap.ArenaAllocator = undefined;
var allocator: std.mem.Allocator = undefined;

var devices_map: std.AutoHashMapUnmanaged(usize, *Device) = .empty;
var devices_count: usize = 0;
var last_assigned_id: usize = 0;

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

    capabilities.comptime_register_callable(Guid.zero(), "Devices", "list", @ptrCast(&lsdev)) catch unreachable;
    capabilities.comptime_register_callable(Guid.zero(), "Devices", "register", @ptrCast(&c__register_devices)) catch unreachable;
    capabilities.comptime_register_callable(Guid.zero(), "Devices", "remove", @ptrCast(&c__remove_device)) catch unreachable;
    capabilities.comptime_register_callable(Guid.zero(), "Devices", "set_status", @ptrCast(&c__set_status)) catch unreachable;

    //_ = root.capabilities.create_event(devices_res, "on_device_registered", on_device_registered_bind, on_pci_device_probe_unbind) catch unreachable;
}

fn register_device(
    devname: []const u8,
    identifier: Guid,
    specifier: usize,
    interface: Guid,
    canSee: root.lib.Privilege,
    canRead: root.lib.Privilege,
    canControl: root.lib.Privilege,
    status: Device.DeviceStatus,
) !struct { id: usize, status: Device.DeviceStatus } {
    const nameclone = allocator.dupeZ(u8, devname) catch root.oom_panic();
    errdefer allocator.free(nameclone);

    const dev = allocator.create(Device) catch root.oom_panic();
    errdefer allocator.free(dev);

    dev.* = .{
        .name = nameclone,
        .identifier = identifier,
        .specifier = specifier,
        .interface = interface,
        .status = .unbinded,
        .canSee = canSee,
        .canRead = canRead,
        .canControl = canControl,
    };

    const index = brk: {
        var idx: usize = last_assigned_id +% 1;
        while (devices_map.contains(idx) or idx == 0) idx = idx +% 1;
        break :brk idx;
    };
    devices_map.put(allocator, index, dev) catch root.oom_panic();
    devices_count += 1;
    run_device_registered_all_callbacks(index, dev);

    log.debug("Registered device {s} in slot {}", .{ dev.name, index });

    return .{
        .id = index,
        .status = if (status == .unset) Device.DeviceStatus.unbinded else status,
    };
}
fn remove_device(dev: usize) !void {
    if (dev == 0) return error.DoesNotExist;
    const d = devices_map.get(dev);
    if (d == null) return error.DoesNotExist;

    allocator.destroy(d.?);
    _ = devices_map.remove(dev);
    devices_count -= 1;
}
fn set_status(dev: usize, status: Device.DeviceStatus) !void {
    if (dev == 0) return error.DoesNotExist;
    const d = devices_map.get(dev);
    if (d == null) return error.DoesNotExist;

    d.?.status = status;
}

const RegisterDeviceInfo = extern struct {
    id: usize,
    name: [*:0]const u8,
    identifier: Guid,
    specifier: usize,
    interface: Guid,
    flags: packed struct(u8) {
        canSee: u1,
        canReed: u1,
        canWrite: u1,

        _rsvd: u5 = 0,
    },
    status: Device.DeviceStatus,
};
fn c__register_devices(devInfoPtr: [*]RegisterDeviceInfo, devInfoCount: usize) callconv(.c) Result(void) {
    const devInfo = devInfoPtr[0..devInfoCount];

    var i: usize = 0;
    var lastError: ?anyerror = null;

    while (lastError == null and i < devInfoCount) {
        var dev = &devInfo[i];
        const result = register_device(
            std.mem.sliceTo(dev.name, 0),
            dev.identifier,
            dev.specifier,
            dev.interface,
            @enumFromInt(dev.flags.canSee),
            @enumFromInt(dev.flags.canReed),
            @enumFromInt(dev.flags.canWrite),
            dev.status,
        ) catch |err| {
            lastError = err;
            break;
        };

        dev.id = result.id;
        dev.status = result.status;

        i += 1;
    }

    if (lastError) |lerr| {
        for (0..i) |j| {
            var dev: *RegisterDeviceInfo = &devInfo[j];
            remove_device(dev.id) catch unreachable;
            dev.id = 0;
            dev.status = .failed;
        }
        return .frombuiltin(lerr);
    }

    return .retvoid();
}
fn c__remove_device(dev: usize) callconv(.c) Result(void) {
    return .frombuiltin(remove_device(dev));
}
fn c__set_status(dev: usize, status: Device.DeviceStatus) callconv(.c) Result(void) {
    return .frombuiltin(set_status(dev, status));
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
        _ = ctx;
        _ = i;
        _ = dev;

        //for (ctx) |ii| {
        //    if (ii.guid != dev.identifier) continue;
        //    if (ii.subclass != 0 and dev.subclass != ii.subclass) continue;

        //    e.callback(i);
        //    break;
        //}
    }
}
fn run_all_devices_registered_callback(entry: OnDeviceRegisterEntry) void {
    var iterator = devices_map.iterator();

    while (iterator.next()) |dev| {
        for (entry.context) |contexts| {
            if (contexts.guid != dev.?.identifier) continue;
            if (contexts.subclass != 0 and dev.?.subclass != contexts.subclass) continue;

            entry.callback(dev.key_ptr.*);
        }
    }
}

pub fn lsdev() callconv(.c) void {
    log.warn("lsdev", .{});
    log.info("Listing registered devices ({}):", .{devices_count});

    devices_map.lockPointers();
    var devices_iterator = devices_map.iterator();
    while (devices_iterator.next()) |dev| {
        log.info(
            "{:0>4}: {f}",
            .{ dev.key_ptr.*, dev.value_ptr.* },
        );
    }
    devices_map.unlockPointers();
}
