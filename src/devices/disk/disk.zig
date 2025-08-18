const std = @import("std");
const root = @import("root");
const sys = root.system;
const debug = root.debug;
const units = root.utils.units.data;

const log = std.log.scoped(.@"devices Disk");

const allocator = root.mem.heap.kernel_buddy_allocator;

var disk_entry_list: []?DiskEntry = undefined;

pub fn init() void {

    disk_entry_list = allocator.alloc(?DiskEntry, 16) catch unreachable;
    @memset(disk_entry_list, null);

}

pub fn append_device(
    ctx: *anyopaque,
    devtype: ?[]const u8,
    seclen: usize,
    vtable: *const DiskEntry.VTable,
) usize {

    const free_slot = b: {
        for (disk_entry_list, 0..) |slot, i| {
            if (slot == null) break :b i;
        }
        @panic("TODO increase disks slots array length");
    };

    const entry = &disk_entry_list[free_slot];
    entry.* = .{
        .global_identifier = "",

        .context = ctx,
        
        .sectors_length = seclen,
        .vtable = vtable
    };
    if (devtype != null) entry.*.?.type = devtype.?;

    //const dev_dir = root.fs.get_root().branch("dev").value;

    log.info("\nPrinting fs tree:", .{});
    root.fs.lsroot();
    log.info("", .{});

    return free_slot;
}

pub fn get_disk_by_index(index: usize) ?DiskEntry {
    return disk_entry_list[index];
}
pub fn get_disk_by_id(id: [:0]const u8) ?DiskEntry {
    
    for (disk_entry_list) |i| if (i) |disk| {
        if (std.mem.eql(u8, disk.global_identifier, id)) return disk;
    };
    return null;

}

pub fn lsblk() void {
    for (disk_entry_list, 0..) |entry, i| {
        if (entry) |e| {

            const size_bytes = e.sectors_length * 512;

            var j: usize = 0;
            while (true) : (j += 1) if (size_bytes >= units[j].size) break;

            const size_float: f64 = @floatFromInt(size_bytes);
            const unit_float: f64 = @floatFromInt(units[j].size);

            log.info("{: >4} : {s}  {d:.2} {s}",.{ i, entry.?.type, size_float/unit_float, units[j].name });

        }
    }
}

pub const DiskEntry = struct {

    pub const ReadWriteHook = *const fn (ctx: *anyopaque, sector: usize, buffer: [*]u8, length: usize) callconv(.c) bool;
    pub const RemoveHook = *const fn (ctx: *anyopaque) callconv(.c) void;
    pub const VTable = extern struct {
        read: ReadWriteHook,
        write: ReadWriteHook,
        remove: RemoveHook,
    };
    const default_type: []const u8 = "unk";

    /// Pointer to the guest context
    context: *anyopaque,

    /// The readable type name of the device
    /// e.g. `flash`, `cd`, `ssd`, `hhd`, `nvme`
    type: []const u8 = default_type,

    /// The disk length in sectors of 512 bytes
    sectors_length: usize,

    /// Virtual functions table associated with this
    /// entry
    vtable: *const VTable,

    /// Disk's global identifier string
    /// e.g. disk's uuid in GPT disks
    global_identifier: []const u8,

    /// Disk's partition entries
    partitions_entry: []? PartitionEntry = undefined,

    /// Performs a read operation
    pub fn read(s: @This(), sector: usize, buffer: []u8) !void {
        const ok = s.vtable.read(s.context, sector, buffer.ptr, buffer.len);
        if (!ok) return error.CannotRead;
    }

};
pub const PartitionEntry = struct {

    pub const ReadWriteHook = *const fn (ctx: *anyopaque, sector: usize, buffer: [*]u8, length: usize) callconv(.c) bool;
    pub const RemoveHook = *const fn (ctx: *anyopaque) callconv(.c) void;
    pub const VTable = extern struct {
        read: ReadWriteHook,
        write: ReadWriteHook,
        remove: RemoveHook,
    };
    const default_name: []const u8 = "undefined";

    /// Pointer to the guest context
    context: *anyopaque,

    /// The readable name of the partition
    name: []const u8 = default_name,

    /// The partition data begguin in sectors of 512 bytes
    sectors_begguin: usize,
    /// The partition data length in sectors of 512 bytes
    sectors_length: usize,

    /// Virtual functions table associated with this
    /// entry
    vtable: *const VTable,

    /// Partitions's global identifier string
    /// e.g. partition's uuid in GPT disks
    global_identifier: []const u8,

    /// Performs a read operation
    pub fn read(s: @This(), sector: usize, buffer: []u8) !void {
        const ok = s.vtable.read(s.context, sector, buffer.ptr, buffer.len);
        if (!ok) return error.CannotRead;
    }

};
