const std = @import("std");
const root = @import("root");
const FsNode = root.fs.FsNode;
const FsResult = root.fs.FsResult;

const ChildrenList = std.ArrayList(*FsNode);

pub const VirtualDirectory = struct {

    allocator: std.mem.Allocator,

    node: FsNode,
    children: ChildrenList,

    pub fn init(name: [*:0]const u8, allocator: std.mem.Allocator) VirtualDirectory {

        var this = @This() {
            .allocator = allocator,
            .children = ChildrenList.init(allocator),
            .node = undefined,
        };

        this.node = .{
            .name = name,
            .type = "Virtual Directory",
            .type_id = "virtual_directory",
            .iterable = true,

            .ctx = null,
            .vtable = &vtable
        };

        return this;
    
    }
    pub fn deinit(s: @This()) void {
        s.children.deinit();
    }
    pub fn set_context(s: *VirtualDirectory) void {
        s.node.ctx = s;
    }

    const vtable: FsNode.FsNodeVtable = .{
        .append_node = append,
        .get_child = getchild
    };

    // Vtable functions after here

    fn append(ctx: *anyopaque, node: *FsNode) callconv(.c) FsResult(void) {
        const s: *VirtualDirectory = @ptrCast(@alignCast(ctx));
        s.children.append(node) catch @panic("OOM");
        return .retvoid();
    }
    fn getchild(ctx: *anyopaque, index: usize) callconv(.c) FsResult(*FsNode) {
        const s: *VirtualDirectory = @ptrCast(@alignCast(ctx));
        if (index < 0 or index >= s.children.items.len) return .err(.outOfBounds);
        return .ret(s.children.items[index]);
    }

};

pub const DiskEntry = struct {

    allocator: std.mem.Allocator,

    node: FsNode,
    partitions: ChildrenList,

    pub fn init(dev: []const u8, index: usize, allocator: std.mem.Allocator) DiskEntry {
        var this = @This() {
            .allocator = allocator,
            .partitions = ChildrenList.init(allocator),
            .node = undefined,
        };
        
        const file_name = std.fmt.allocPrintZ(root.mem.heap.kernel_buddy_allocator,
        "{s}-{}", .{dev, index}) catch @panic("OOM");

        this.node = .{
            .name = file_name,
            .type = "Disk Drive",
            .type_id = "disk_drive",
            .iterable = true,
            
            .ctx = null,
            .vtable = undefined
        };

        return this;
    }
    pub fn deinit(s: @This()) void {
        s.allocator.free(s.node.name);
        s.children.deinit();
    }
    pub fn set_context(s: *VirtualDirectory) void {
        s.node.ctx = s;
    }

};

