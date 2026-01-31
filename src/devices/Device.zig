const std = @import("std");
const root = @import("root");
const lib = root.lib;

name: [:0]const u8,
identifier: root.utils.Guid,
interface: root.utils.Guid,
specifier: usize,
status: DeviceStatus,

canSee: Privilege,
canRead: Privilege,
canControl: Privilege,

pub fn format(self: @This(), writer: *std.Io.Writer) std.Io.Writer.Error!void {
    try writer.print(
        "{s} - {f}:{f}:{x:0>4} - {s}",
        .{ self.name, self.interface, self.identifier, self.specifier, @tagName(self.status) },
    );
}

const Privilege = root.lib.Privilege;
pub const DeviceStatus = enum(usize) {
    failed = 0,
    unset,
    
    unbinded,
    working,
};
