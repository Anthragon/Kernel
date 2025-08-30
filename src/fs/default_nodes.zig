const std = @import("std");
const root = @import("root");
const lib = @import("lib");
const interop = root.interop;

const FsNode = lib.common.FsNode;
const PartEntry = lib.common.PartEntry;
const Result = interop.Result;

const ChildrenList = std.ArrayListUnmanaged(*FsNode);

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
        .get_child = get_child
    };

    // Vtable functions after here

    fn append(ctx: *FsNode, node: *FsNode) callconv(.c) Result(void) {
        const s: *VirtualDirectory = @ptrCast(@alignCast(ctx));
        s.children.append(root.fs.get_fs_allocator(), node) catch root.oom_panic();
        return .retvoid();
    }
    fn get_child(ctx: *FsNode, index: usize) callconv(.c) Result(*FsNode) {
        const s: *VirtualDirectory = @ptrCast(@alignCast(ctx));
        if (index < 0 or index >= s.children.items.len) return .err(.outOfBounds);
        return .val(s.children.items[index]);
    }

};

