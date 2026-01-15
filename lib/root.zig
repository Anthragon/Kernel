pub const Privilege = enum(u1) { user = 0, kernel = 1 };

pub const interop = @import("interop/interop.zig");
pub const utils = @import("utils/utils.zig");

pub const Toml = @import("toml/Toml.zig");

pub const common = .{
    .Module = @import("common/Module.zig").Module,

    .TaskGeneralFlags = @import("common/TaskGeneralFlags.zig"),

    .FileSystemEntry = @import("common/FileSystemEntry.zig").FileSystemEntry,
    .DiskEntry = @import("common/DiskEntry.zig").DiskEntry,
    .PartEntry = @import("common/DiskEntry.zig").PartitionEntry,

    .FsNode = @import("common/FsNode.zig").FsNode,

    .time = @import("common/time.zig"),
};
pub const paging = @import("paging.zig");
pub const boot = @import("common/boot.zig");

pub const CapabilityKind = enum(usize) {
    Callable,

    PropertyGetter,
    PropertySetter,

    EventBind,
    EventUnbind,
};

pub const callables = @import("callables.zig");
