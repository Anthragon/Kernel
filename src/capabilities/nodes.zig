const std = @import("std");
const root = @import("root");
const Guid = root.utils.Guid;
const interop = root.interop;
const Result = interop.Result;

const NodeDataTags = enum {
    resource,
    callable,
    property,
    event,
};
pub const Node = struct {
    parent: ?*Node,
    name: [:0]const u8,
    global: [:0]const u8,

    data: union(NodeDataTags) {
        resource: Resource,
        callable: Callable,
        property: Property,
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

const Callable = *const anyopaque;

const Property = *anyopaque;

pub const Event = extern struct {
    pub const EventOnBindCallback = *const fn (*const anyopaque, ?*anyopaque) callconv(.c) bool;
    pub const EventOnUnbindCallback = *const fn (*const anyopaque) callconv(.c) void;

    bind_callback: EventOnBindCallback,
    unbind_callback: EventOnUnbindCallback,

    pub fn bind(s: @This(), func: *const anyopaque, ctx: ?*anyopaque) callconv(.c) bool {
        return s.bind_callback(func, ctx);
    }
    pub fn unbind(s: @This(), func: *const anyopaque) callconv(.c) void {
        s.unbind_callback(func);
    }
};
