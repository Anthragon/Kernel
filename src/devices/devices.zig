const std = @import("std");
const root = @import("root");
const sys = root.system;

pub const pci = @import("pci.zig");
pub const acpi = @import("acpi.zig");
pub const disk = @import("disk/disk.zig");

pub fn init() void {

    root.debug.err("Initializing devices service...\n", .{});

    pci.init();
    pci.list_pci_devices() catch @panic("Failed to list PCI devices");

    acpi.init();

    disk.init();

}
