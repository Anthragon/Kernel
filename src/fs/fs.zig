const std = @import("std");
const lib = @import("lib");
const root = @import("root");
const debug = root.debug;
const interop = lib.interop;
const fsroot = @import("fsroot.zig");

const log = std.log.scoped(.fs);

pub const FileSystemEntry = lib.common.FileSystemEntry;
pub const DiskEntry = lib.common.DiskEntry;
pub const PartEntry = lib.common.PartEntry;
pub const FsNode = lib.common.FsNode;

pub const default_nodes = @import("default_nodes.zig");
pub const Result = interop.Result;

var arena: std.heap.ArenaAllocator = undefined;
var allocator: std.mem.Allocator = undefined;

var fs_resource: *root.capabilities.Node = undefined;

var fileSystems: std.StringArrayHashMapUnmanaged(*FileSystemEntry) = .empty;

pub fn init() void {
    log.debug(" ## Setting up file system service...", .{});

    arena = .init(root.mem.heap.kernel_buddy_allocator);
    allocator = arena.allocator();

    fsroot.init();

    // getting capability resource node
    fs_resource = root.capabilities.get_node_by_guid(root.utils.Guid.fromString("0d132c17-8f92-4861-a735-d78c753b73cf") catch unreachable).?;

    _ = root.capabilities.create_callable(fs_resource, "lsdir", @ptrCast(&lsdir)) catch unreachable;
    _ = root.capabilities.create_callable(fs_resource, "lsroot", @ptrCast(&lsroot)) catch unreachable;
    
    _ = root.capabilities.create_callable(fs_resource, "chroot", @ptrCast(&chroot)) catch unreachable;

    _ = root.capabilities.create_callable(fs_resource, "append_file_system", @ptrCast(&append_file_system)) catch unreachable;
    _ = root.capabilities.create_callable(fs_resource, "remove_file_system", @ptrCast(&remove_file_system)) catch unreachable;

    _ = root.capabilities.create_callable(fs_resource, "mount_disk", @ptrCast(&mount_disk)) catch unreachable;
    _ = root.capabilities.create_callable(fs_resource, "mount_part", @ptrCast(&mount_part)) catch unreachable;
    _ = root.capabilities.create_callable(fs_resource, "mount_disk_by_identifier_part_by_identifier", @ptrCast(&mount_disk_by_identifier_part_by_identifier)) catch unreachable;

}

pub inline fn get_fs_allocator() std.mem.Allocator {
    return allocator;
}

pub fn chroot(newroot: *FsNode) callconv(.c) void {
    fsroot.chroot(newroot);
}
pub fn get_root() *FsNode {
    return &fsroot.root_wrapper;
}


fn append_file_system(entry: FileSystemEntry) callconv(.c) Result(void) {
    if (entry.name == null) return .err(.nullArgument);
    const slice = std.mem.sliceTo(entry.name.?, 0);
    if (fileSystems.contains(slice)) return .err(.nameAlreadyUsed);

    const instance = allocator.create(FileSystemEntry) catch root.oom_panic();
    instance.* = entry;

    fileSystems.put(allocator, slice, instance) catch root.oom_panic();
    return .retvoid();
}
fn remove_file_system(name: ?[*:0]const u8) callconv(.c) void {
    if (name == null) return;
    const slice = std.mem.sliceTo(name.?, 0);
    const instance = (fileSystems.fetchSwapRemove(slice) orelse return).value;
    allocator.destroy(instance);
}


pub fn mount_disk(disk: *anyopaque) void {
    _ = disk;
}
pub fn mount_part(part: *PartEntry) void {
    log.debug("Mounting partition...", .{});

    const fs = get_partition_fs(part) orelse @panic("No compatible file system found!");
    log.debug("Mounting with {s}...", .{fs.name orelse "-"});
    part.file_system = fs;
    fs.vtable.mount(part);

}
pub fn mount_disk_by_identifier_part_by_identifier(disk: [*:0]const u8, part: [*:0]const u8) callconv(.c) void {
    log.debug("mount requested - {s} : {s}", .{ disk, part });

    const getdbipbi: *const fn ([*:0]const u8, [*:0]const u8) callconv(.c) ?*lib.common.PartEntry = 
        @ptrCast(@alignCast((root.capabilities.get_node("Devices.MassStorage.get_disk_by_identifier_part_by_identifier")
        orelse @panic("Callable not found!")).data.callable));
    
    const entry = getdbipbi(disk, part) orelse @panic("Trying to mount a null partition entry!");
    mount_part(entry);
}

fn get_partition_fs(part: *PartEntry) ?*FileSystemEntry {

    for (fileSystems.values()) |i| {
        log.debug("Testing {s}...", .{i.name.?});

        const res = i.vtable.scan(part);
        if (res) return i;

    }
    return null;

}


/// Dumps the content of the `node` directory
pub fn lsdir(node: *FsNode) callconv(.c) void {

    var iterator = node.get_iterator().value;
    while (iterator.next()) |n| {
        log.info("{s: <15} {s}", .{n.name, n.type});
    }

}
/// Dumps all the file system
pub fn lsroot() callconv(.c) void {

    var buffer: std.ArrayList(u8) = .init(allocator);
    defer buffer.deinit();

    const writer = buffer.writer();

    const Entry = struct {
        iter: FsNode.FsNodeIterator,
        level: usize,
    };
    var stack: std.ArrayListUnmanaged(Entry) = .empty;
    defer stack.deinit(allocator);

    const iterator = get_root().get_iterator();
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
