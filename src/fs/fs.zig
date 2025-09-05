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
pub fn get_root() callconv(.c) *FsNode {
    return &fsroot.root_wrapper;
}
pub fn get_node(path: [*:0]const u8) callconv(.c) Result(*FsNode) {
    return get_root().branch(path);
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
pub fn mount_part(part: *PartEntry) *FsNode {
    log.debug("Mounting partition...", .{});

    const fs = get_partition_fs(part) orelse @panic("No compatible file system found!");
    log.debug("Mounting with {s}...", .{fs.name orelse "-"});
    part.file_system = fs;
    return fs.vtable.mount(part);
}
pub fn mount_disk_by_identifier_part_by_identifier(disk: [*:0]const u8, part: [*:0]const u8) callconv(.c) *FsNode {
    log.debug("mount requested - {s} : {s}", .{ disk, part });

    const getdbipbi: *const fn ([*:0]const u8, [*:0]const u8) callconv(.c) ?*lib.common.PartEntry =
        @ptrCast(@alignCast((root.capabilities.get_node("Devices.MassStorage.get_disk_by_identifier_part_by_identifier") orelse @panic("Callable not found!")).data.callable));

    const entry = getdbipbi(disk, part) orelse @panic("Trying to mount a null partition entry!");
    return mount_part(entry);
}

fn get_partition_fs(part: *PartEntry) ?*FileSystemEntry {
    for (fileSystems.values()) |i| {
        log.debug("Testing {s}...", .{i.name.?});

        const res = i.vtable.scan(part);
        if (res) return i;
    }
    return null;
}

pub fn set_mount_point(node: *FsNode, path: [*:0]const u8) Result(void) {
    
    const path_slice = std.mem.sliceTo(path, 0);
    const path_separator = std.mem.lastIndexOfLinear(u8, path_slice, "/") orelse std.debug.panic("Invalid Mount point '{s}'", .{path});
    const dir_path = allocator.dupeZ(u8, path_slice[0..path_separator]) catch root.oom_panic();
    defer allocator.free(dir_path);
    const node_name = allocator.dupeZ(u8, path_slice[path_separator + 1 ..]) catch root.oom_panic();
    defer allocator.free(node_name);

    const parent_node: Result(*FsNode) = get_node(dir_path);
    if (!parent_node.isok()) return .err(parent_node.@"error");
    const mountpoint = default_nodes.MountPoint.init(node_name, node);

    _ = parent_node.unwrap().?.append(&mountpoint.node);
    return .retvoid();
}

/// Dumps the content of the `node` directory
pub fn lsdir(node: *FsNode) callconv(.c) void {
    var iterator = node.get_iterator().value;
    while (iterator.next()) |n| {
        log.info("{s: <15} {s}", .{ n.name, n.type });
    }
}
/// Dumps all the file system
pub fn lsroot() callconv(.c) void {
    var buffer: std.ArrayList(u8) = .empty;
    defer buffer.deinit(allocator);
    const writer = buffer.writer(allocator);

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
                const name = std.mem.sliceTo(node.name, 0);
                writer.print("{s}/", .{name}) catch unreachable;
                for (name.len..19) |_| writer.writeByte(' ') catch unreachable;
                writer.print(" {s}", .{node.type}) catch unreachable;
            } else {
                writer.print("{s: <20} {s: <25}", .{ node.name, node.type }) catch unreachable;

                const size = node.get_size();
                if (size.isok()) {
                    const unit = lib.utils.units.calc(
                        size.value,
                        &lib.utils.units.data,
                    );
                    writer.print(" {d:.2} {s}", .{ unit.@"0", unit.@"1" }) catch unreachable;
                } else writer.print("Unk", .{}) catch unreachable;
            }

            if (node.iterable) {
                const iter = node.get_iterator();

                if (iter.unwrap()) |v| {
                    stack.append(allocator, .{
                        .iter = v,
                        .level = last.level + 1,
                    }) catch root.oom_panic();
                }
            }

            writer.writeByte('\n') catch unreachable;
        } else _ = stack.pop();
    }

    log.info("{s}", .{buffer.items});
}
