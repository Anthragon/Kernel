const std = @import("std");
const root = @import("root");
const sys = root.system;
const allocator = root.mem.heap.kernel_buddy_allocator;

const debug = root.debug;

pub const internal = switch (sys.arch) {
    //.x86 => ,
    .x86_64 => @import("x86_64/pci/pci.zig"),
    //.aarch64 => ,
    else => unreachable
};

const Addr = internal.Addr;
pub const DeviceList = std.ArrayList(*PciDevice);
const DeviceProbeFunc = *const fn(*PciDevice) callconv(.c) bool;

var devList: DeviceList = undefined;

pub const PciDevice = extern struct {

    const default_string: [*:0]const u8 = "unknown";

    addr: Addr,

    type_str: [*:0]const u8 = default_string,
    vendor_str: [*:0]const u8 = default_string,
    name_str: [*:0]const u8 = default_string,

    binded: bool = false,

    pub inline fn get_bus(s: @This()) u8 { return s.addr.bus; }
    pub inline fn get_device(s: @This()) u5 { return s.addr.device; }
    pub inline fn get_function(s: @This()) u3 { return s.addr.function; }

};
pub const PciDeviceQuery = extern struct {
    vendor: u16, device: u16,
    sub_vendor: u16, sub_device: u16,
    class: u8, sub_class: u8, prog_if: u8,

    pub fn byClass(class: u8, subclass: u8, prog_if: u8) @This() {
        return .{
            .vendor = 0xffff,
            .device = 0xffff,
            .sub_vendor = 0xffff,
            .sub_device = 0xffff,
            .class = class,
            .sub_class = subclass,
            .prog_if = prog_if,
        };
    }

    pub fn byVendor(vendor: u16, sub_vendor: u16, dev: u16, sub_dev: u16) @This() {
        return .{
            .vendor = vendor,
            .device = dev,
            .sub_vendor = sub_vendor,
            .sub_device = sub_dev,
            .class = 0,
            .sub_class = 0,
            .prog_if = 0,
        };
    }

    pub fn endOfChain() @This() {
        return .{
            .vendor = 0,
            .device = 0,
            .sub_vendor = 0,
            .sub_device = 0,
            .class = 0,
            .sub_class = 0,
            .prog_if = 0,
        };
    }
    pub fn isNull(s: @This()) bool {
        return s.vendor == 0;
    }
};

pub fn init() void {
    // Initializing device list
    devList = DeviceList.init(allocator);
}

pub fn list_pci_devices() !void {
    devList.clearAndFree();
    try internal.list_devices(&devList);
}

pub export fn pci_device_probe(query: [*]const PciDeviceQuery, func: DeviceProbeFunc) callconv(.c) void {

    // It will iterate through all unbinded devices,
    // test the query and call the function if it matches

    var j: usize = 0;
    while (!query[j].isNull()) : (j += 1) {
        const q = query[j];
        debug.err("query {} ", .{j});

        for (devList.items, 0..) |dev, dev_idx| {
            debug.err("dev {} ", .{dev_idx});
            
            if (!dev.binded) {

                if (q.vendor != 0xffff and dev.addr.vendor_id().read() != q.vendor) { debug.err("vendor fail\n", .{}); continue; }
                if (q.device != 0xffff and dev.addr.device_id().read() != q.device) { debug.err("device fail\n", .{}); continue; }
                if (q.class != 0 and dev.addr.base_class().read() != q.class) { debug.err("base class fail\n", .{}); continue; }
                if (q.sub_class != 0 and dev.addr.sub_class().read() != q.sub_class) { debug.err("sub class fail\n", .{}); continue; }
                if (q.prog_if != 0 and dev.addr.prog_if().read() != q.prog_if) { debug.err("prog if fail\n", .{}); continue; }

                debug.err("Passed\n", .{});

                const res = func(dev);
                if (res) {
                    debug.print("Device successfully binded by module!\n", .{});
                    dev.binded = true;
                }
            }
        }
    }

}



pub fn lspci() void {

    debug.print("Listing PCI devices:\n", .{});
    for (devList.items) |i| {
        debug.print(
            "{X:0>2}:{X:0>2}.{X:0>1} [{X:0>2}:{X:0>2}] {s}: [{X:0>4}] {s} - [{X:0>4}] {s}\n",
            .{

            i.get_bus(),
            i.get_device(),
            i.get_function(),

            i.addr.base_class().read(),
            i.addr.sub_class().read(),
            i.type_str,
            i.addr.vendor_id().read(),
            i.vendor_str,
            i.addr.device_id().read(),
            i.name_str
        });
    }

}
