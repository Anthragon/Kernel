const std = @import("std");
const root = @import("root");
const lib = @import("lib");
const interop = root.interop;

const FsNode = lib.common.FsNode;
const PartEntry = lib.common.PartEntry;
const Result = interop.Result;

const ChildrenList = std.StringArrayHashMapUnmanaged(FsNode);

pub const VirtualDirectory = struct {
    uses: usize = 0,
    deleted: bool = false,

    name: [:0]const u8,
    children: ChildrenList = .empty,

    pub fn init(name: []const u8) *VirtualDirectory {
        const allocator = root.fs.get_fs_allocator();

        const this = allocator.create(VirtualDirectory) catch root.oom_panic();
        const name_copy = allocator.dupeZ(u8, name) catch root.oom_panic();
        this.* = .{
            .name = name_copy,
        };
        return this;
    }
    pub fn deinit(s: @This()) void {
        const allocator = root.fs.get_fs_allocator();
        allocator.free(s.name);
        s.children.deinit();
        allocator.destroy(s);
    }

    pub fn get_node(s: *@This()) FsNode {
        s.uses += 1;
        return .{
            .context = @ptrCast(s),
            .name = s.name,
            .type = "Virtual Directory",
            .type_id = "dir",
            .flags = .{
                .iterable = true,
                .physical = false,
                .readable = false,
                .writeable = false,
            },
            .vtable = &vtable,
        };
    }

    const vtable: FsNode.FsNodeVtable = .{
        .open = open,
        .close = close,
        .append_node = append,
        .get_child = get_child,
    };

    // Vtable functions after here

    fn open(ctx: *anyopaque) callconv(.c) FsNode {
        const s: *VirtualDirectory = @ptrCast(@alignCast(ctx));
        return get_node(s);
    }
    fn close(ctx: *anyopaque) callconv(.c) void {
        const s: *VirtualDirectory = @ptrCast(@alignCast(ctx));
        s.uses -= 1;
    }
    fn append(ctx: *anyopaque, node: FsNode) callconv(.c) Result(void) {
        const s: *VirtualDirectory = @ptrCast(@alignCast(ctx));

        const slice = std.mem.sliceTo(node.name, 0);
        s.children.put(root.fs.get_fs_allocator(), slice, node) catch root.oom_panic();
        return .retvoid();
    }
    fn get_child(ctx: *anyopaque, index: usize) callconv(.c) Result(FsNode) {
        const s: *VirtualDirectory = @ptrCast(@alignCast(ctx));
        const children = s.children.values();

        if (index >= children.len) return .err(.outOfBounds);
        return .val(children[index]);
    }
};

pub const MountPoint = struct {
    uses: usize = 0,
    deleted: bool = false,

    name: [:0]const u8,
    target: FsNode,

    pub fn init(name: []const u8, target: FsNode) *MountPoint {
        const allocator = root.fs.get_fs_allocator();

        const this = allocator.create(MountPoint) catch root.oom_panic();
        const name_copy = allocator.dupeZ(u8, name) catch root.oom_panic();
        this.* = .{
            .name = name_copy,
            .target = target,
        };
        return this;
    }
    pub fn deinit(s: @This()) void {
        const allocator = root.fs.get_fs_allocator();
        allocator.free(s.node.name);
        s.children.deinit();
        allocator.destroy(s);
    }

    pub fn get_node(s: *@This()) FsNode {
        s.uses += 1;
        return .{
            .context = @ptrCast(s),
            .name = s.name,
            .type = "MountPoint",
            .type_id = "dir,mountpoint",
            .flags = .{
                .iterable = true,
                .physical = false,
                .readable = false,
                .writeable = false,
            },
            .vtable = &vtable,
        };
    }

    const vtable: FsNode.FsNodeVtable = .{
        .open = open,
        .close = close,
        .append_node = append,
        .get_child = get_child,
    };

    fn open(ctx: *anyopaque) callconv(.c) FsNode {
        const s: *MountPoint = @ptrCast(@alignCast(ctx));
        return s.get_node();
    }
    fn close(ctx: *anyopaque) callconv(.c) void {
        const s: *MountPoint = @ptrCast(@alignCast(ctx));
        s.uses -= 1;
    }
    fn append(ctx: *anyopaque, node: FsNode) callconv(.c) Result(void) {
        const s: *MountPoint = @ptrCast(@alignCast(ctx));
        _ = s;
        _ = node;

        @panic("Not implemented fuck");
    }
    fn get_child(ctx: *anyopaque, index: usize) callconv(.c) Result(FsNode) {
        const s: *MountPoint = @ptrCast(@alignCast(ctx));
        _ = s;
        _ = index;

        @panic("Not implemented fuck");
    }
};
