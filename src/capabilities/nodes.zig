const std = @import("std");
const root = @import("root");
const Guid = root.utils.Guid;
const interop = root.interop;
const Result = interop.Result;

pub const events = @import("event/event.zig");

const NodeDataTags = enum {
    resource,
    field,
    callable,
    event,
};
pub const Node = struct {
    parent: ?*Node,
    name: [:0]const u8,
    global: [:0]const u8,

    data: union(NodeDataTags) {
        resource: Resource,
        field: Field,
        callable: Callable,
        event: Event,
    },

    pub fn create(
        allocator: std.mem.Allocator,
        parent: ?*Node,
        name: []const u8,
    ) !*Node {
        const instance = try allocator.create(Node);
        errdefer allocator.destroy(instance);

        var global = brk: {
            if (std.mem.indexOfSentinel(u8, 0, parent.?.global) == 0)
                break :brk allocator.dupeZ(u8, name) catch root.oom_panic();

            break :brk std.fmt.allocPrintSentinel(
                allocator,
                "{s}.{s}",
                .{ parent.?.global, name },
                0,
            ) catch root.oom_panic();
        };
        errdefer allocator.free(global);

        instance.global = global;
        instance.name = global[(global.len - name.len)..];
        instance.parent = parent;

        return instance;
    }

    pub fn deinit(s: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(s.name);
        allocator.destroy(s);
    }

    pub fn branch(s: *@This(), path: []const u8) ?*Node {
        var slice = std.mem.tokenizeAny(u8, path, ".");
        return s.branch_internal(&slice);
    }
    fn branch_internal(s: *@This(), iter: *std.mem.TokenIterator(u8, .any)) ?*Node {
        if (s.data != .resource) return null;

        const curr = iter.next() orelse return null;
        const child = s.data.resource.children.get(curr) orelse return null;
        if (iter.peek() == null) return child;
        return child.branch_internal(iter);
    }
};

const Resource = struct {
    children: std.StringArrayHashMapUnmanaged(*Node),
};

const Field = *anyopaque;

const Callable = *const anyopaque;

const Event = events.Event;
