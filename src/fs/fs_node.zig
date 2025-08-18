const std = @import("std");
const root = @import("root");
const debug = root.debug;

const interop = root.interop;
const Result = interop.Result;

pub const FsNode = extern struct {

    pub const FsNodeVtable = extern struct {
        append_node: *const fn (ctx: *anyopaque, node: *FsNode) callconv(.c) Result(void),
        branch: ?*const fn (ctx: *anyopaque, path: [*:0]const u8) callconv(.c) Result(*FsNode) = null,
        get_child: *const fn (ctx: *anyopaque, index: usize) callconv(.c) Result(*FsNode),
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
    ctx: *anyopaque,

    /// Hook for the node's virtual functions
    vtable: *const FsNodeVtable,

    pub fn append(s: *@This(), node: *FsNode) callconv(.c) Result(void) {
        return s.vtable.append_node(s.ctx, node);
    }
    pub fn branch(s: *@This(), path: [*:0]const u8) callconv(.c) Result(*FsNode) {
        if (!s.iterable) return .err(.notIterable);
        if (s.vtable.branch) |b| return b(s.ctx, path); 

        // Default branching
        // FIXME verify if this function is realy reliable
        const pathslice = std.mem.sliceTo(path, 0);

        const i: usize = std.mem.indexOf(u8, pathslice, "/") orelse pathslice.len;
        const j: usize = std.mem.indexOf(u8, pathslice[i..], "/") orelse pathslice.len;

        var iterator = s.get_iterator().value;
        
        var q: *FsNode = undefined;
        while (iterator.next()) |node| {
            if (std.mem.eql(u8, std.mem.sliceTo(node.name, 0), pathslice)) {
                q = node;
                break;
            }
        }

        // If last item in path
        if (j == pathslice.len) return .val(q);

        // If not, delegate the rest of the job further
        return q.branch(path[j..]);
    }
    pub fn get_iterator(s: *@This()) callconv(.c) Result(NodeIterator) {
        if (!s.iterable) return .err(.notIterable);

        return .val(.{ .node = s });
    }
};

pub const NodeIterator = extern struct {
    node: *FsNode,
    index: usize = 0,

    pub fn next(s: *@This()) ?*FsNode {
        var ret = s.node.vtable.get_child(s.node.ctx, s.index);
        s.index += 1;
        return if (ret.unwrap()) |v| v else null;
    }
    pub fn reset(s: *@This()) void {
        s.index = 0;
    }
};
