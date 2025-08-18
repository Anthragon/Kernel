const std = @import("std");
const root = @import("root");
const interop = root.interop;
const FsNode = root.fs.FsNode;
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

            .ctx = this,
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
        .get_child = getchild
    };

    // Vtable functions after here

    fn append(ctx: *anyopaque, node: *FsNode) callconv(.c) Result(void) {
        const s: *VirtualDirectory = @ptrCast(@alignCast(ctx));
        s.children.append(root.fs.get_fs_allocator(), node) catch root.oom_panic();
        return .retvoid();
    }
    fn getchild(ctx: *anyopaque, index: usize) callconv(.c) Result(*FsNode) {
        const s: *VirtualDirectory = @ptrCast(@alignCast(ctx));
        if (index < 0 or index >= s.children.items.len) return .err(.outOfBounds);
        return .val(s.children.items[index]);
    }

};

