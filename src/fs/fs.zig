const std = @import("std");
const root = @import("root");
const debug = root.debug;
const interop = root.interop;

pub const FsNode = @import("fs_node.zig").FsNode;
pub const Result = interop.Result;
pub const default_nodes = @import("default_nodes.zig");

const kernel_allocator = root.mem.heap.kernel_buddy_allocator;
const allocator = kernel_allocator;
//var arena: std.heap.ArenaAllocator = undefined;
//var allocator: std.mem.Allocator = undefined;

var fs_root: default_nodes.VirtualDirectory = undefined;
var fs_dev: default_nodes.VirtualDirectory = undefined;


pub fn init() void {
    debug.err(" ## Setting up file system service...\n", .{});

    //arena = .init(kernel_allocator);
    //allocator = arena.allocator();

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
    var stack: std.ArrayListUnmanaged(Entry) = .empty;
    defer stack.deinit(allocator);

    const iterator = fs_root.node.get_iterator();
    stack.append(allocator, .{
        .iter = iterator.value,
        .level = 0,
    }) catch @panic("OOM");

    while (stack.items.len > 0) {
        var last = &stack.items[stack.items.len - 1];

        if (last.iter.next()) |node| {

            for (0..last.level) |_| debug.print("  ", .{});

            if (node.iterable) {
                debug.print("{s: <20} {s}\n", .{ node.name, node.type });
            } else {
                debug.print("{s: <20} {s}\n", .{ node.name, node.type });
            }

            if (node.iterable) {

                const iter = node.get_iterator();

                if (iter.unwrap()) |v| {
                    stack.append(allocator, 
                    .{
                        .iter = v,
                        .level = last.level + 1,
                    }) catch @panic("OOM");
                }
            }

        }
        else _ = stack.pop();

    }

}
