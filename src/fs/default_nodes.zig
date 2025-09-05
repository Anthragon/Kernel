const std = @import("std");
const root = @import("root");
const lib = @import("lib");
const interop = root.interop;

const FsNode = lib.common.FsNode;
const PartEntry = lib.common.PartEntry;
const Result = interop.Result;

const ChildrenList = std.StringArrayHashMapUnmanaged(*FsNode);

pub const VirtualDirectory = struct {
    node: FsNode = undefined,
    children: ChildrenList = .empty,

    pub fn init(name: []const u8) *VirtualDirectory {
        const allocator = root.fs.get_fs_allocator();

        var this = allocator.create(VirtualDirectory) catch root.oom_panic();
        const name_copy = allocator.dupeZ(u8, name) catch root.oom_panic();
        this.* = .{};

        this.node = .{
            .name = name_copy,
            .type = "Virtual Directory",
            .type_id = "virtual_directory",

            .iterable = true,
            .physical = false,

            .vtable = &vtable,
        };

        return this;
    }
    pub fn deinit(s: @This()) void {
        const allocator = root.fs.get_fs_allocator();
        allocator.free(s.node.name);
        s.children.deinit();
        allocator.destroy(s);
    }

    const vtable: FsNode.FsNodeVtable = .{ .append_node = append, .get_child = get_child };

    // Vtable functions after here

    fn append(ctx: *FsNode, node: *FsNode) callconv(.c) Result(void) {
        const s: *VirtualDirectory = @ptrCast(@alignCast(ctx));
        const slice = std.mem.sliceTo(node.name, 0);
        s.children.put(root.fs.get_fs_allocator(), slice, node) catch root.oom_panic();
        return .retvoid();
    }
    fn get_child(ctx: *FsNode, index: usize) callconv(.c) Result(*FsNode) {
        const s: *VirtualDirectory = @ptrCast(@alignCast(ctx));
        const children = s.children.values();

        if (index >= children.len) return .err(.outOfBounds);
        return .val(children[index]);
    }
};

pub const MountPoint = struct {
    node: FsNode = undefined,
    target: *FsNode,

    pub fn init(name: []const u8, target: *FsNode) *MountPoint {
        const allocator = root.fs.get_fs_allocator();

        var this = allocator.create(MountPoint) catch root.oom_panic();
        const name_copy = allocator.dupeZ(u8, name) catch root.oom_panic();
        this.* = .{
            .target = target,
        };

        this.node = .{
            .name = name_copy,
            .type = target.type,
            .type_id = "mount_point",

            .iterable = true,
            .physical = false,

            .vtable = &vtable,
        };

        return this;
    }
    pub fn deinit(s: @This()) void {
        const allocator = root.fs.get_fs_allocator();
        allocator.free(s.node.name);
        s.children.deinit();
        allocator.destroy(s);
    }

    const vtable: FsNode.FsNodeVtable = .{
        .append_node = append,
        .get_child = get_child,
    };

    fn append(ctx: *FsNode, node: *FsNode) callconv(.c) Result(void) {
        const s: *MountPoint = @ptrCast(@alignCast(ctx));
        if (s.target.vtable.append_node) |apn| return apn(s.target, node);
        @panic("Target has no append_node implementation!");
    }
    fn get_child(ctx: *FsNode, index: usize) callconv(.c) Result(*FsNode) {
        const s: *MountPoint = @ptrCast(@alignCast(ctx));
        if (s.target.vtable.get_child) |getc| return getc(s.target, index);
        @panic("Target has no get_child implementation!");
    }
};
