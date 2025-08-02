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
    guid: Guid,
    parent: ?*Node,
    name: [*:0]const u8,

    data: union(NodeDataTags) {
        resource: Resource,
        field: Field,
        callable: Callable,
        event: Event,
    },

    pub fn create(
        allocator: std.mem.Allocator,
        parent: ?*Node,
        guid: ?Guid,
        name: []const u8,
    ) !*Node {

        const instance = try allocator.create(Node);
        errdefer allocator.destroy(instance);

        instance.name = try allocator.dupeZ(u8, name);
        errdefer allocator.free(instance.name);
        instance.parent = parent;
        instance.guid = guid orelse Guid.new();

        return instance;
    }
};

const Resource = struct {
    children: std.StringHashMapUnmanaged(*Node),
};

const Field = *anyopaque;

const Callable = *const fn (...) callconv(.c) Result(usize);

const Event = events.Event;
