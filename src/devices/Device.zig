const std = @import("std");
const root = @import("root");
const lib = root.lib;
const Result = root.interop.Result;

pub const VTable = lib.common.devices.VTable;
pub const Status = lib.common.devices.Status;
const Privilege = root.lib.Privilege;

name: [:0]const u8,
identifier: root.utils.Guid,
interface: root.utils.Guid,
specifier: usize,
status: Status,

canSee: Privilege,
canRead: Privilege,
canControl: Privilege,

implPointer: *anyopaque,
implVtable: *const VTable,

pub fn format(self: @This(), writer: *std.Io.Writer) std.Io.Writer.Error!void {
    try writer.print(
        "{s: <16} - {f} : {f} : {x:0>4} - {s}",
        .{ self.name, self.interface, self.identifier, self.specifier, @tagName(self.status) },
    );
}
