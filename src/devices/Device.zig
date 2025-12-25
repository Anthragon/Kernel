const std = @import("std");
const root = @import("root");
const lib = root.lib;

name: [:0]const u8,
identifier: root.utils.Guid,
subclass: usize,
status: DeviceStatus,

canSee: Privilege,
canRead: Privilege,
canControl: Privilege,

pub fn format(self: @This(), writer: *std.Io.Writer) std.Io.Writer.Error!void {
    try writer.print(
        "{s} - {f}:{x:0>4} - {s}",
        .{ self.name, self.identifier, self.subclass, @tagName(self.status) },
    );
}

const Privilege = root.lib.Privilege;
pub const DeviceStatus = enum {
    unbinded,
    working,
    failed,
};
