const std = @import("std");
const root = @import("root");
const nodes = @import("nodes.zig");
const interop = root.interop;

const Guid = root.utils.Guid;
const Result = interop.Result;

const kernel_allocator = root.mem.heap.kernel_buddy_allocator;

pub const Event = @import("event/event.zig").Event;
pub const Node = nodes.Node;

var capabilities_root: Node = .{
    .guid = Guid.zero(),
    .name = "root",
    .parent = null,
    .data = .{ .resource = .{ .children = .empty } }
};
var capabilities_all: std.AutoArrayHashMapUnmanaged(Guid, *Node) = .empty;

var arena: std.heap.ArenaAllocator = undefined;
var allocator: std.mem.Allocator = undefined;

pub fn init() void {

    arena = .init(kernel_allocator);
    allocator = arena.allocator();

    const kernel_node = create_resource_internal(
        Guid.fromString("645fc46e-ec52-4f0b-a748-bee542baf1bf") catch unreachable,
        null, "Kernel") catch unreachable;

    const devices_node = create_resource_internal(
        Guid.fromString("753d870c-e51b-40d2-96b9-beb3bfa8cd02") catch unreachable,
        null, "Devices") catch unreachable;

    _ = kernel_node;
    _ = devices_node;

}

/// Provides a zig interface for retrieving a node though it uuid
pub fn get_node_by_guid_internal(guid: Guid) ?*Node {
    return capabilities_all.get(guid);
}
/// Provides a zig interface for retrieving a node tough it path
pub fn get_node_internal(path: []const u8) ?*Node {
    return capabilities_root.branch(path);
}
/// Provides a zig interface for retrieving the capabilities root
pub fn get_root_internal() *Node {
    return &capabilities_root;
}

/// Generic node creation
fn create_new_node(guid: Guid, parent: ?*Node, name: []const u8) !*Node {

    const real_parent: *Node = parent orelse &capabilities_root;
    const real_guid: Guid = if (guid.isZero()) Guid.new() else guid;

    if (real_parent.data != .resource) return error.ParentIsNotResource;
    if (capabilities_all.contains(real_guid)) return error.NodeGuidAlreadyExists;
    if (real_parent.data.resource.children.contains(name)) return error.NodeNameAlreadyExists;

    const nn = Node.create(allocator, real_parent, real_guid, name) catch root.oom_panic();
    
    real_parent.data.resource.children.put(allocator, name, nn) catch root.oom_panic();
    capabilities_all.put(allocator, nn.guid, nn) catch root.oom_panic();

    return nn;

}

/// Provides a zig interface for creating a new resource in the capabilities tree
pub fn create_resource_internal(guid: Guid, parent: ?*Node, name: []const u8) !*Node {
    const nn = try create_new_node(guid, parent, name);
    nn.data = .{ .resource = .{ .children = .empty } };
    return nn;
}
/// Provides a zig interface for creating a new callable in the capabilities tree
pub fn create_callable_internal(parent: ?*Node, name: []const u8, callable: *const anyopaque) !*Node {
    const nn = try create_new_node(.zero(), parent, name);
    nn.data = .{ .callable = callable };
    return nn;
}
/// Provides a zig interface for creating a new field pointer in the capabilities tree
pub fn create_field_ptr_internal(parent: ?*Node, name: []const u8, ptr: *anyopaque) !*Node {
    const nn = try create_new_node(.zero(), parent, name);
    nn.data = .{ .field = ptr };
    return nn;
}
// Provides a zig interface for creating a new event in the capabilities tree
pub fn create_event_internal(
    parent: ?*Node,
    name: []const u8,
    bind: Event.EventOnBindCallback,
    unbind: Event.EventOnUnbindCallback,
) !*Node {
    const nn = try create_new_node(.zero(), parent, name);
    nn.data = .{ .event = .{
        .bind_callback = bind,
        .unbind_callback = unbind,
    }};
    return nn;
}
