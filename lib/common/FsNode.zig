const std = @import("std");
const root = @import("root");
const debug = root.debug;

const interop = root.interop;
const Result = interop.Result;
const KernelError = interop.KernelError;

pub const FsNode = extern struct {
    pub const FsNodeVtable = extern struct {
        open: *const fn (ctx: *anyopaque) callconv(.c) FsNode,
        close: *const fn (ctx: *anyopaque) callconv(.c) void,

        append_node: ?*const fn (ctx: *anyopaque, node: FsNode) callconv(.c) Result(void) = null,
        branch: ?*const fn (ctx: *anyopaque, path: [*:0]const u8) callconv(.c) Result(FsNode) = null,
        get_child: ?*const fn (ctx: *anyopaque, index: usize) callconv(.c) Result(FsNode) = null,

        // content related
        read: ?*const fn (ctx: *anyopaque, buffer: [*]u8, len: usize) callconv(.c) Result(usize) = null,

        // metadata related
        get_size: ?*const fn (ctx: *anyopaque) callconv(.c) Result(usize) = null,
    };
    pub const FsNodeFlags = packed struct(usize) {
        /// Says if the node is iterable (e.g. Directories)
        /// or not (e.g. Files)
        iterable: bool,
        // Says if the node represents physical or virtual entry
        physical: bool,
        readable: bool,
        writeable: bool,

        _: u60 = 0,
    };
    pub const FsNodeIterator = NodeIterator;

    /// Internal node non-generic context
    context: *anyopaque,

    /// The name of this node \
    /// It can be the file/directory name
    /// of some readable identification for the user
    name: [*:0]const u8,

    /// The readable type of this node
    type: [*:0]const u8,

    /// The type ID string of this node,
    /// used by other modules to identify what
    /// they are handling with
    type_id: [*:0]const u8,

    flags: FsNodeFlags,

    vtable: *const FsNodeVtable,

    pub fn open(s: @This()) callconv(.c) FsNode {
        return s.vtable.open(s.context);
    }
    pub fn close(s: @This()) callconv(.c) void {
        s.vtable.close(s.context);
    }

    pub fn append(s: @This(), node: FsNode) callconv(.c) Result(void) {
        if (s.vtable.append_node) |appn| return appn(s.context, node);
        std.log.warn("append not implemented!", .{});
        return .err(.notImplemented);
    }
    pub fn branch(s: @This(), path: [*:0]const u8) callconv(.c) Result(FsNode) {
        if (s.vtable.branch) |br| return br(s.context, path);
        if (!s.flags.iterable) return .err(.notIterable);

        // Default branching
        const pathslice = std.mem.sliceTo(path, 0);
        const i: usize = std.mem.indexOf(u8, pathslice, "/") orelse pathslice.len;
        const j: usize = std.mem.indexOf(u8, pathslice[i..], "/") orelse pathslice.len;

        var iterator = s.get_iterator().value;

        var q: ?FsNode = null;
        while (iterator.next()) |node| {
            const nodename = std.mem.sliceTo(node.name, 0);
            if (std.mem.eql(u8, nodename, pathslice)) {
                q = node;
                break;
            }
        }

        // If q is null, return error
        if (q == null) return .err(.invalidPath);

        // If last item in path
        if (j == pathslice.len) return .val(q.?);

        // If not, delegate the rest of the job further
        return q.?.branch(path[j..]);
    }
    pub fn get_child(s: @This(), index: usize) Result(FsNode) {
        if (s.vtable.get_child) |getc| return getc(s.context, index);
        std.log.warn("get_child not implemented!", .{});
        return .err(.notImplemented);
    }
    pub fn get_iterator(s: @This()) callconv(.c) Result(NodeIterator) {
        if (!s.flags.iterable) return .err(.notIterable);
        return .val(.{ .node = s });
    }

    pub fn get_size(s: @This()) callconv(.c) Result(usize) {
        if (s.vtable.get_size) |gs| return gs(s.context);
        std.log.warn("get_size not implemented!", .{});
        return .err(.notImplemented);
    }

    pub fn read(s: @This(), buffer: [*]u8, len: usize) callconv(.c) Result(usize) {
        if (s.vtable.read) |re| return re(s.context, buffer, len);
        return .err(.cannotRead);
    }
    pub fn readAll(s: @This(), allocator: std.mem.Allocator) ![]const u8 {
        const size = s.get_size().unwrap() orelse return error.InternalError;
        const buf = allocator.alloc(u8, size) catch root.oom_panic();

        _ = try s.read(buf.ptr, buf.len).asbuiltin();
        return buf;
    }

};

pub const NodeIterator = extern struct {
    node: FsNode,
    index: usize = 0,
    last_is_null: bool = true,
    last_iteration: FsNode = undefined,

    pub fn next(s: *@This()) ?FsNode {
        if (!s.last_is_null) s.last_iteration.close();

        const val = s.node.get_child(s.index).asbuiltin() catch |err| switch (err) {
            KernelError.OutOfBounds => {
                s.last_is_null = true;
                s.last_iteration = undefined;
                return null;
            },
            else => std.debug.panic("iterator bruh: {s}\nnode: {s}", .{
                @errorName(err),
                s.node.name,
            }),
        };

        s.index += 1;
        s.last_is_null = false;
        s.last_iteration = val;
        return val;
    }
    pub fn reset(s: *@This()) void {
        s.index = 0;
    }
    pub fn deinit(s: *@This()) void {
        if (!s.last_is_null) s.last_iteration.close();
    }
};
