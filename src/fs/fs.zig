const std = @import("std");
const root = @import("root");
const debug = root.debug;

pub const FsNode = @import("fs_node.zig").FsNode;
pub const FsResult = @import("fs_node.zig").FsResult;
pub const default_nodes = @import("default_nodes.zig");

const kernel_allocator = root.mem.heap.kernel_buddy_allocator;
const allocator = kernel_allocator;

//var arena: std.heap.ArenaAllocator = undefined;
//var allocator: std.mem.Allocator = undefined;

var fs_root: default_nodes.VirtualDirectory = undefined;
var fs_dev: default_nodes.VirtualDirectory = undefined;


pub fn init() void {

    // FIXME discover why arena is not working
    //arena = .init(allocator);
    //allocator = arena.allocator();

    //debug.err("{}\n", .{ arena.state });

    // Creating root node
    fs_root = default_nodes.VirtualDirectory.init("root", allocator);
    fs_root.set_context();

    // Creating dev node
    fs_dev = default_nodes.VirtualDirectory.init("dev", allocator);
    fs_dev.set_context();
    _ = fs_root.node.append(&fs_dev.node);

}

pub fn get_root() *FsNode {
    return &fs_root.node;
}


pub fn lsdir(node: *FsNode) void {

    var iterator = node.get_iterator().val;
    while (iterator.next()) |n| {
        debug.print("{s: <15} {s}\n", .{n.name, n.type});
    }

}

/// Dumps all the file system
pub fn lsroot() void {

    const Entry = struct {
        iter: FsNode.FsNodeIterator,
        level: usize,
    };
    var stack: std.ArrayList(Entry) = .init(allocator);
    defer stack.deinit();

    const iterator = fs_root.node.get_iterator();
    stack.append(.{
        .iter = iterator.val,
        .level = 0
    }) catch @panic("OOM");

    while (stack.items.len > 0) {

        var last = &stack.items[stack.items.len - 1];

        if (last.iter.next()) |node| {

            for (0..last.level) |_| debug.print("  ", .{});
            if (node.iterable) {
                const mem = std.fmt.allocPrint(allocator, "{s}/", .{node.name}) catch @panic("OOM");
                debug.print("{s/: <20} {s}\n", .{ mem, node.type });
                allocator.free(mem);
            } else {
                debug.print("{s: <20} {s}\n", .{ node.name, node.type });
            }

            if (node.iterable) {

                const iter = node.get_iterator();

                if (iter.isok()) {
                    stack.append(.{
                        .iter = iter.val,
                        .level = last.level + 1,
                    }) catch @panic("OOM");
                }
            }
        }
        else _ = stack.pop();

    }

}
