const std = @import("std");
const lib = @import("lib");
const interop = lib.interop;

const log = std.log.scoped(.fs);

const FileSystemEntry = lib.common.FileSystemEntry;
const DiskEntry = lib.common.DiskEntry;
const PartEntry = lib.common.PartEntry;
const FsNode = lib.common.FsNode;

const default_nodes = @import("default_nodes.zig");
const Result = interop.Result;

var vfs_root: *default_nodes.VirtualDirectory = undefined;
var pfs_root: ?*FsNode = null;

pub var root_wrapper: FsNode = .{
    .name = "Root",
    .type = "Root",
    .type_id = "root",
    .iterable = true,
    .vtable = &vtable,
};

pub fn init() void {

    // Creating virtual root node
    vfs_root = default_nodes.VirtualDirectory.init("root");

    // Creating dev node
    var fs_dev = default_nodes.VirtualDirectory.init("dev");
    _ = vfs_root.node.append(&fs_dev.node);

}

pub fn chroot(newroot: *FsNode) void {
    pfs_root = newroot;
}


fn initialize_virtual_root() void {
    // Creating virtual root node
    vfs_root = default_nodes.VirtualDirectory.init("root");

    // Creating dev node
    var fs_dev = default_nodes.VirtualDirectory.init("dev");
    _ = vfs_root.node.append(&fs_dev.node);
}

const vtable: FsNode.FsNodeVtable = .{
    .append_node = append,
    .get_child = getchild,
    .branch = branch,
};

// Vtable functions after here

fn append(_: *FsNode, node: *FsNode) callconv(.c) Result(void) {
    _ = node;
    // TODO see how to handle it somehow
    @panic("TODO see how to handle it somehow");
}
fn getchild(_: *FsNode, index: usize) callconv(.c) Result(*FsNode) {
    const vfs_children = vfs_root.children.values();

    if (index < vfs_children.len) return .val(vfs_children[index])
    else if (pfs_root) |r| return r.get_child(index - vfs_children.len)

    else return .err(.outOfBounds);
}
fn branch(_: *FsNode, path: [*:0]const u8) callconv(.c) Result(*FsNode) {

    const pathslice = std.mem.sliceTo(path, 0);

    const i: usize = std.mem.indexOf(u8, pathslice, "/") orelse pathslice.len;
    const nodename = pathslice[0..i];

    var vcdict = vfs_root.children;
    if (vcdict.contains(nodename)) {
        const node = vcdict.get(nodename).?;
        if (i != pathslice.len) return node.branch(path[i+1..]);
        return .val(node);
    }

    return if (pfs_root) |pfs| pfs.branch(path) else @panic("fuck");
}
