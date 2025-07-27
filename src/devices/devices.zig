const std = @import("std");
const root = @import("root");
const sys = root.system;

const log = std.log.scoped(.devices);

pub const pci = @import("pci.zig");
pub const acpi = @import("acpi.zig");
pub const disk = @import("disk/disk.zig");

pub fn init() void {

    log.debug(" ## Setting up devices service...", .{});

    pci.init();
    pci.list_pci_devices() catch @panic("Failed to list PCI devices");

    acpi.init();

    disk.init();

}
