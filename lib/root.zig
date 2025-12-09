pub const interop = @import("interop/interop.zig");
pub const utils = @import("utils/utils.zig");

pub const Toml = @import("toml/Toml.zig");

pub const common = .{
    .FileSystemEntry = @import("common/FileSystemEntry.zig").FileSystemEntry,
    .DiskEntry = @import("common/DiskEntry.zig").DiskEntry,
    .PartEntry = @import("common/DiskEntry.zig").PartitionEntry,

    .FsNode = @import("common/FsNode.zig").FsNode,

    .time = @import("common/time.zig"),
};

pub const capabilities = @import("root").capabilities;
pub const callables = @import("callables.zig");
