const std = @import("std");
const root = @import("root");
const sys = root.system;
const debug = root.debug;
const units = root.utils.units.data;

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
        .context = ctx,
        
        .fs_node = undefined,

        .sectors_length = seclen,
        .vtable = vtable
    };
    if (devtype != null) entry.*.?.type = devtype.?;

    entry.*.?.fs_node = .init(entry.*.?.type, free_slot, allocator);
    
    const dev_dir = root.fs.get_root().branch("dev").val;
    _ = dev_dir.append(&entry.*.?.fs_node.node);

    root.fs.lsdir(dev_dir);

    return free_slot;
}

pub fn get_disk_by_idx(index: usize) ?DiskEntry {
    return disk_entry_list[index];
}

pub fn lsblk() void {
    for (disk_entry_list, 0..) |entry, i| {
        if (entry) |e| {

            const size_bytes = e.sectors_length * 512;

            var j: usize = 0;
            while (true) : (j += 1) if (size_bytes >= units[j].size) break;

            const size_float: f64 = @floatFromInt(size_bytes);
            const unit_float: f64 = @floatFromInt(units[j].size);

            debug.print("{: >4} : {s}  {d:.2} {s}\n",.{ i, entry.?.type, size_float/unit_float, units[j].name });

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
    const default_type: []const u8 = "UNK";

    /// Disk file node
    fs_node: root.fs.default_nodes.DiskEntry,

    /// Pointer to the guest context
    context: *anyopaque,

    /// The readable type name of the device
    /// e.g. `flash`, `CD`, `SSD`, `HHD`, `nVME`
    type: []const u8 = default_type,

    /// The disk length in sectors of 512 bytes
    sectors_length: usize,

    /// Virtual functions table associated with this
    /// entry
    vtable: *const VTable,

    /// Performs a read operation
    pub fn read(s: @This(), sector: usize, buffer: []u8) !void {
        const ok = s.vtable.read(s.context, sector, buffer.ptr, buffer.len);
        if (!ok) return error.CannotRead;
    }

};
