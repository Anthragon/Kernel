const std = @import("std");
const root = @import("root");
const sys = root.system;

const log = std.log.scoped(.devices);

pub const acpi = @import("acpi.zig");

pub fn init() void {

    log.debug(" ## Setting up devices service...", .{});

    acpi.init() catch |err| log.err("Error initializing ACPI: {s}", .{ @errorName(err) });

}
