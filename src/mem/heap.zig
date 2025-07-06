const root = @import("root");
const std = @import("std");
const mem = root.mem;
const Allocator = mem.Allocator;
const Alignment = mem.Allignment;

const debug = root.debug;

pub const kernel_buddy_allocator : Allocator = .{
    .ptr = &root.system.vmm.kernel_buddy_allocator,
    .vtable = &root.system.vmm.KernelBuddyAllocator.vtable
};
pub const kernel_page_allocator = root.system.vmm.kernel_page_allocator;

// TODO Page allocator
pub const page_allocator: Allocator = .{
    .ptr = undefined,
    .vtable = &PageAllocator.page_allocator_vtable
};
const PageAllocator = struct {

    const page_allocator_vtable: Allocator.VTable = .{
        .alloc = page_allocator_alloc,
        .resize = page_allocator_resize,
        .remap = page_allocator_remap,
        .free = page_allocator_free
    };

    fn page_allocator_alloc(_: *anyopaque, len: usize, alignment: Alignment, _: usize) ?[*]u8 {
        debug.err("allocation of len {}, align {} requested\n", .{len, @intFromEnum(alignment)});

        if (len >= std.math.maxInt(usize) - root.mem.pmm.page_size) return null;
        const alignment_bytes = alignment.toByteUnits();

        const aligned_len = std.mem.alignForward(usize, len, mem.pmm.page_size);
        const max_drop_len = alignment_bytes - @min(alignment_bytes, mem.pmm.page_size);
        const overalloc_len = if (max_drop_len <= aligned_len - mem.pmm.page_size) aligned_len
            else std.mem.alignForward(usize, aligned_len + max_drop_len, mem.pmm.page_size);

        debug.err("requesting {} bytes\n", .{overalloc_len});

        return null;
    }
    fn page_allocator_resize(_: *anyopaque, memory: []u8, alignment: Alignment, new_len: usize, _: usize) bool {
        debug.err("resize of address {X} to len {}, align {} requested\n", .{@intFromPtr(memory.ptr), new_len, @intFromEnum(alignment)});
        return false;
    }
    fn page_allocator_remap(_: *anyopaque, memory: []u8, alignment: Alignment, new_len: usize, _: usize) ?[*]u8 {
        debug.err("remap of address {X} to len {}, align {} requested\n", .{@intFromPtr(memory.ptr), new_len, @intFromEnum(alignment)});
        return null;
    }
    fn page_allocator_free(_: *anyopaque, memory: []u8, alignment: Alignment, _: usize) void {
        debug.err("free of address {X}, align {} requested\n", .{@intFromPtr(memory.ptr), @intFromEnum(alignment)});
    }
};
