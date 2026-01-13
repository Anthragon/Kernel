const std = @import("std");
const root = @import("root");
const nodes = @import("nodes.zig");
const interop = root.interop;

const Guid = root.utils.Guid;
const Result = interop.Result;

const kernel_allocator = root.mem.heap.kernel_buddy_allocator;

pub const Node = nodes.Node;

var capabilities_root: Node = .{
    .name = "root",
    .global = "",
    .parent = null,
    .data = .{ .resource = .{ .children = .empty } },
};
var capabilities_all: std.StringArrayHashMapUnmanaged(*Node) = .empty;

var arena: std.heap.ArenaAllocator = undefined;
var allocator: std.mem.Allocator = undefined;

const log = std.log.scoped(.capabilities);

pub fn init() void {
    arena = .init(kernel_allocator);
    allocator = arena.allocator();

    const sys_node = create_resource(
        null,
        "System",
    ) catch unreachable;

    const fs_node = create_resource(
        null,
        "Fs",
    ) catch unreachable;

    const mem_node = create_resource(
        null,
        "Memory",
    ) catch unreachable;

    const dev_node = create_resource(
        null,
        "Devices",
    ) catch unreachable;

    { // Internal memory related
        _ = create_callable(mem_node, "lsmemtable", root.mem.lsmemtable) catch unreachable;
    }
    _ = sys_node;
    _ = fs_node;
    _ = dev_node;
}

pub fn lscaps() void {
    log.warn("lscaps", .{});
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(allocator);

    var writer = buf.writer(allocator);

    const StackItem = struct {
        node: *Node,
        index: usize = 0,
        wrote: bool = false,
    };
    var stack: std.ArrayList(StackItem) = .empty;
    defer stack.deinit(allocator);

    stack.append(allocator, .{ .node = &capabilities_root }) catch root.oom_panic();

    while (stack.items.len > 0) {
        var current = &stack.items[stack.items.len - 1];

        if (!current.wrote) {
            switch (current.node.data) {
                .resource => |_| {
                    for (0..stack.items.len) |_| writer.writeAll("  ") catch unreachable;
                    writer.print("{s} {{\n", .{current.node.name}) catch unreachable;
                },
                .callable => |c| {
                    for (0..stack.items.len) |_| writer.writeAll("  ") catch unreachable;
                    writer.print("callable {s} -> ${x}\n", .{ current.node.name, @intFromPtr(c) }) catch unreachable;
                },
                .property => |f| {
                    for (0..stack.items.len) |_| writer.writeAll("  ") catch unreachable;
                    writer.print("property {s} -> ${x}\n", .{ current.node.name, @intFromPtr(f) }) catch unreachable;
                },
                .event => |e| {
                    for (0..stack.items.len) |_| writer.writeAll("  ") catch unreachable;
                    writer.print("event    {s} -> ${x}, ${x}\n", .{ current.node.name, @intFromPtr(e.bind_callback), @intFromPtr(e.unbind_callback) }) catch unreachable;
                },
            }
            current.wrote = true;
        }

        if (current.node.data == .resource) {
            if (current.index == current.node.data.resource.children.count()) {
                _ = stack.pop();
                for (0..stack.items.len + 1) |_| writer.writeAll("  ") catch unreachable;
                writer.writeAll("}\n") catch unreachable;
                continue;
            }

            stack.append(allocator, .{ .node = current.node.data.resource.children.values()[current.index] }) catch root.oom_panic();
            current.index += 1;
            continue;
        }
        _ = stack.pop();
    }

    log.info("{s}", .{buf.items});
}

/// Provides a zig interface for retrieving a node tough its path
pub fn get_node(path: []const u8) ?*Node {
    return capabilities_all.get(path);
}
/// Returns a node by its path
pub fn c__get_node(path: [*:0]const u8) callconv(.c) ?*Node {
    return get_node(std.mem.sliceTo(path, 0));
}

/// Returns the capabilities root
pub fn get_root() callconv(.c) *Node {
    return &capabilities_root;
}

/// Generic node creation
fn create_new_node(parent: ?*Node, name: []const u8) !*Node {
    const real_parent: *Node = parent orelse &capabilities_root;

    if (real_parent.data != .resource) return error.ParentIsNotResource;
    if (real_parent.data.resource.children.contains(name)) return error.NodeNameAlreadyExists;

    for (name) |c| if (!std.ascii.isAlphanumeric(c) and c != '_') return error.InvalidNameIdentifier;

    const nn = Node.create(allocator, real_parent, name) catch root.oom_panic();

    real_parent.data.resource.children.put(allocator, nn.name, nn) catch root.oom_panic();
    capabilities_all.put(allocator, nn.global, nn) catch root.oom_panic();

    return nn;
}

/// Provides a zig interface for creating a new resource in the capabilities tree
pub fn create_resource(parent: ?*Node, name: []const u8) !*Node {
    const nn = try create_new_node(parent, name);
    nn.data = .{ .resource = .{ .children = .empty } };
    return nn;
}
/// Provides a zig interface for creating a new callable in the capabilities tree
pub fn create_callable(parent: ?*Node, name: []const u8, callable: *const anyopaque) !*Node {
    const nn = try create_new_node(parent, name);
    nn.data = .{ .callable = callable };
    return nn;
}
/// Provides a zig interface for creating a new field pointer in the capabilities tree
pub fn create_field_pointer(parent: ?*Node, name: []const u8, ptr: *anyopaque) !*Node {
    const nn = try create_new_node(.zero(), parent, name);
    nn.data = .{ .field = ptr };
    return nn;
}
// Provides a zig interface for creating a new event in the capabilities tree
pub fn create_event(
    parent: ?*Node,
    name: []const u8,
    bind: nodes.Event.EventOnBindCallback,
    unbind: nodes.Event.EventOnUnbindCallback,
) !*Node {
    const nn = try create_new_node(parent, name);
    nn.data = .{ .event = .{
        .bind_callback = bind,
        .unbind_callback = unbind,
    } };
    return nn;
}
