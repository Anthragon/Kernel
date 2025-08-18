const std = @import("std");
const root = @import("root");
const debug = root.debug;
const interop = root.interop;

const log = std.log.scoped(.fs);

pub const FsNode = @import("fs_node.zig").FsNode;
pub const Result = interop.Result;
pub const default_nodes = @import("default_nodes.zig");

const kernel_allocator = root.mem.heap.kernel_buddy_allocator;
var arena: std.heap.ArenaAllocator = undefined;
var allocator: std.mem.Allocator = undefined;

var fs_root: *default_nodes.VirtualDirectory = undefined;


pub fn init() void {
    log.debug(" ## Setting up file system service...", .{});

    arena = .init(kernel_allocator);
    allocator = arena.allocator();

    // Creating root node
    fs_root = default_nodes.VirtualDirectory.init("root");

    // Creating dev node
    var fs_dev = default_nodes.VirtualDirectory.init("dev");
    _ = fs_root.node.append(&fs_dev.node);

}

pub inline fn get_fs_allocator() std.mem.Allocator {
    return allocator;
}

pub fn get_root() *FsNode {
    return &fs_root.node;
}


pub fn lsdir(node: *FsNode) void {

    var iterator = node.get_iterator().val;
    while (iterator.next()) |n| {
        log.info("{s: <15} {s}", .{n.name, n.type});
    }

}

/// Dumps all the file system
pub fn lsroot() void {

    var buffer: std.ArrayList(u8) = .init(allocator);
    defer buffer.deinit();

    const writer = buffer.writer();

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
    }) catch root.oom_panic();

    while (stack.items.len > 0) {
        var last = &stack.items[stack.items.len - 1];

        if (last.iter.next()) |node| {

            for (0..last.level) |_| writer.writeAll("  ") catch unreachable;

            if (node.iterable) {
                writer.print("{s: <20} {s}", .{ node.name, node.type }) catch unreachable;
            } else {
                writer.print("{s: <20} {s}", .{ node.name, node.type }) catch unreachable;
            }

            if (node.iterable) {

                const iter = node.get_iterator();

                if (iter.unwrap()) |v| {
                    stack.append(allocator, 
                    .{
                        .iter = v,
                        .level = last.level + 1,
                    }) catch root.oom_panic();
                }
            }

        }
        else _ = stack.pop();

    }

    log.info("{s}", .{ buffer.items });

}
