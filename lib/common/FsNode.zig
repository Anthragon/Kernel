const std = @import("std");
const root = @import("root");
const debug = root.debug;

const interop = root.interop;
const Result = interop.Result;

pub const FsNode = extern struct {

    pub const FsNodeVtable = extern struct {
        append_node: ?*const fn (self: *FsNode, node: *FsNode) callconv(.c) Result(void) = null,
        branch: ?*const fn (self: *FsNode, path: [*:0]const u8) callconv(.c) Result(*FsNode) = null,
        get_child: ?*const fn (self: *FsNode, index: usize) callconv(.c) Result(*FsNode) = null,

        // metadata related
        get_size: ?*const fn (self: *FsNode) callconv(.c) Result(usize) = null,
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

    /// Hook for the node's virtual functions
    vtable: *const FsNodeVtable,


    pub fn append(s: *@This(), node: *FsNode) callconv(.c) Result(void) {
        if (s.vtable.append_node) |appn| return appn(s, node);
        return .err(.notImplemented);
    }
    pub fn branch(s: *@This(), path: [*:0]const u8) callconv(.c) Result(*FsNode) {
        if (!s.iterable) return .err(.notIterable);
        if (s.vtable.branch) |b| return b(s, path); 

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
    pub fn get_child(s: *@This(), index: usize) Result(*FsNode) {
        if (s.vtable.get_child) |getc| return getc(s, index);
        return .err(.notImplemented);
    }
    pub fn get_iterator(s: *@This()) callconv(.c) Result(NodeIterator) {
        if (!s.iterable) return .err(.notIterable);

        return .val(.{ .node = s });
    }

    pub fn get_size(s: *@This()) callconv(.c) Result(usize) {
        if (s.vtable.get_size) |gs| return gs(s);
        return .err(.notImplemented);
    }
};

pub const NodeIterator = extern struct {
    node: *FsNode,
    index: usize = 0,

    pub fn next(s: *@This()) ?*FsNode {
        var ret = s.node.get_child(s.index);
        s.index += 1;
        return if (ret.unwrap()) |v| v else null;
    }
    pub fn reset(s: *@This()) void {
        s.index = 0;
    }
};
