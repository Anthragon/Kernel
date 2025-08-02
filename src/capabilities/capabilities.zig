const std = @import("std");
const root = @import("root");
const nodes = @import("nodes.zig");

const Guid = root.utils.Guid;
const Node = nodes.Node;

const kernel_allocator = root.mem.heap.kernel_buddy_allocator;

var arena: std.heap.ArenaAllocator = undefined;
var allocator: std.mem.Allocator = undefined;

var capabilities_root: Node = .{
    .guid = Guid.zero(),
    .name = "root",
    .parent = null,
    .data = .{ .resource = .{ .children = .empty } }
};
var capabilities_all: std.AutoArrayHashMapUnmanaged(Guid, *Node) = .empty;

pub fn init() void {

    arena = .init(kernel_allocator);
    allocator = arena.allocator();

    std.log.info("{X}\n", .{@intFromPtr(&arena)});
    const ptr: [*]u8 = @ptrCast(@alignCast(&arena));
    root.debug.dumpHex(ptr[0 .. @sizeOf(std.heap.ArenaAllocator)]);

    std.log.debug("{}", .{ arena });

    const kernel_node = create_resource_internal(Guid.zero(), null, "Kernel") 
        catch @panic("ParentIsNotResource");

    _ = kernel_node;

}


pub fn create_resource_internal(guid: Guid, parent: ?*Node, name: []const u8) !void {

    const real_parent: *Node = parent orelse &capabilities_root;
    if (real_parent.data != .resource) return error.ParentIsNotResource;


    const nn = Node.create(allocator, parent, guid, name) catch root.oom_panic();
    nn.data = .{ .resource = .{ .children = .empty } };
    
    real_parent.data.resource.children.put(allocator, name, nn) catch root.oom_panic();
    capabilities_all.put(allocator, nn.guid, nn) catch root.oom_panic();
}
