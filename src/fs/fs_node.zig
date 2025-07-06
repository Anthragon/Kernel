const std = @import("std");
const root = @import("root");
const debug = root.debug;

pub const FsNode = extern struct {

    pub const FsNodeVtable = extern struct {
        append_node: *const fn (ctx: *anyopaque, node: *FsNode) callconv(.c) FsResult(void),
        branch: ?*const fn (ctx: *anyopaque, path: [*:0]const u8) callconv(.c) FsResult(*FsNode) = null,
        get_child: *const fn (ctx: *anyopaque, index: usize) callconv(.c) FsResult(*FsNode),
    };
    pub const FsNodeIterator = NodeIterator;


    /// The name of this node \
    /// It can be the file/directory name
    /// of some identification for the user
    name: [*:0]const u8,

    /// The readable type of this node
    type: [*:0]const u8,

    /// The type ID string of this node,
    /// used by other modules to identify what
    /// they are handling
    type_id: [*:0]const u8,

    /// Says if the node is iterable (e.g. Directories)
    /// or not (e.g. Files)
    iterable: bool,

    /// The custom context of the node
    ctx: ?*anyopaque,

    /// Hook for the node's virtual functions
    vtable: *const FsNodeVtable,

    pub fn append(s: *@This(), node: *FsNode) callconv(.c) FsResult(void) {
        return s.vtable.append_node(s.ctx.?, node);
    }
    pub fn branch(s: *@This(), path: [*:0]const u8) callconv(.c) FsResult(*FsNode) {

        if (!s.iterable) return .err(.notIterable);
        if (s.vtable.branch) |b| return b(s.ctx.?, path); 

        // Default branching
        // FIXME verify if this function is realy reliable
        const pathslice = std.mem.sliceTo(path, 0);

        const i: usize = std.mem.indexOf(u8, pathslice, "/") orelse pathslice.len;
        const j: usize = std.mem.indexOf(u8, pathslice[i..], "/") orelse pathslice.len;

        var iterator = s.get_iterator().val;
        
        var q: *FsNode = undefined;
        while (iterator.next()) |node| {
            if (std.mem.eql(u8, std.mem.sliceTo(node.name, 0), pathslice)) {
                q = node;
                break;
            }
        }

        // If last item in path
        if (j == pathslice.len) return .ret(q);

        // If not, delegate the rest of the job further
        return q.branch(path[j..]);
    }
    pub fn get_iterator(s: *@This()) callconv(.c) FsResult(NodeIterator) {
        if (!s.iterable) return .err(.notIterable);
        return .ret(.{ .node = s });
    }
};

pub const NodeIterator = extern struct {
    node: *FsNode,
    index: usize = 0,

    pub fn next(s: *@This()) ?*FsNode {
        var ret = s.node.vtable.get_child(s.node.ctx.?, s.index);
        s.index += 1;
        return if (ret.isok()) ret.val else null;
    }
    pub fn reset(s: *@This()) void {
        s.index = 0;
    }
};

pub fn FsResult(T: type) type {
    return extern struct {
        @"error": FsError,
        val: T,

        pub fn ret(v: T) FsResult(T) {
            return .{
                .@"error" = .noerror,
                .val = v
            };
        }
        pub fn retvoid() FsResult(void) {
            return .{
                .@"error" = .noerror,
                .val = undefined
            };
        }
        pub fn err(e: FsError) FsResult(T) {
            return .{
                .@"error" = e,
                .val = undefined
            };
        }

        pub fn isok(s: *@This()) bool {
            return s.@"error" == .noerror;
        }
    };
}
pub const FsError = enum(usize) {
    noerror = 0,

    notIterable = 1,
    outOfBounds = 2,
};
