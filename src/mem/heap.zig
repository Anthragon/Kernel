const root = @import("root");
const std = @import("std");
const mem = root.mem;
const Allocator = mem.Allocator;
const Alignment = mem.Allignment;

const debug = root.debug;

pub const kernel_buddy_allocator: Allocator = undefined;
pub const kernel_page_allocator = root.system.vmm.PageAllocator;


/// This is a abstraction above the ``kerbel_page_allocator to be able to
/// use it as a zig's PageAllocator
const PageAllocator = struct {

    const page_allocator_vtable: Allocator.VTable = .{
        .alloc = page_allocator_alloc,
        .resize = page_allocator_resize,
        .remap = page_allocator_remap,
        .free = page_allocator_free
    };

    fn page_allocator_alloc(_: *anyopaque, len: usize, _: Alignment, _: usize) ?[*]u8 {
        const pages = std.math.divCeil(usize, len, root.system.pmm.page_size) catch unreachable;

        debug.err("Page Allocator: Allocation requested: {} bytes ({} pages)\n", .{len, pages});

        return kernel_page_allocator.alloc(pages);
    }
    fn page_allocator_resize(_: *anyopaque, memory: []u8, alignment: Alignment, new_len: usize, _: usize) bool {
        debug.err("Page Allocator: Resize requested: {} bytes\n", .{ new_len });

        _ = memory;
        _ = alignment;

        return false;
    }
    fn page_allocator_remap(_: *anyopaque, memory: []u8, alignment: Alignment, new_len: usize, _: usize) ?[*]u8 {
        debug.err("Page Allocator: Allocation requested: {} bytes\n", .{ new_len });

        _ = memory;
        _ = alignment;

        return null;
    }
    fn page_allocator_free(_: *anyopaque, memory: []u8, _: Alignment, _: usize) void {
        debug.err("Page Allocator: Free requested\n", .{});

        kernel_page_allocator.free(memory);
    }
};
/// Used by zig std library
pub const page_allocator: Allocator = .{
    .ptr = undefined,
    .vtable = &PageAllocator.page_allocator_vtable
};
