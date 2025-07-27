const root = @import("root");
const std = @import("std");
const mem = root.mem;
const Allocator = mem.Allocator;
const Alignment = mem.Allignment;

const debug = root.debug;

pub const kernel_buddy_allocator: Allocator = undefined;
pub const kernel_page_allocator = root.system.vmm.PageAllocator;

/// This is a abstraction above the `kernel_page_allocator` to be able to
/// use it as a zig's PageAllocator
const PageAllocator = struct {
    const log = std.log.scoped(.page_allocator);

    const page_allocator_vtable: Allocator.VTable = .{
        .alloc = page_allocator_alloc,
        .resize = page_allocator_resize,
        .remap = page_allocator_remap,
        .free = page_allocator_free
    };

    fn page_allocator_alloc(_: *anyopaque, len: usize, alignment: Alignment, _: usize) ?[*]u8 {
        const pages = std.math.divCeil(usize, len, root.system.pmm.page_size) catch unreachable;

        const addr = kernel_page_allocator.alloc(pages, alignment);

        log.debug("Page Allocator: Allocation requested: {} bytes, aligned to {} ({} pages) -> {x}", .{
            len, alignment.toByteUnits(), pages, if (addr == null) 0 else @intFromPtr(addr.?)});

        return addr;
    }
    fn page_allocator_resize(_: *anyopaque, memory: []u8, alignment: Alignment, new_len: usize, _: usize) bool {
        log.debug("Page Allocator: Resize requested: {} bytes", .{ new_len });

        _ = memory;
        _ = alignment;

        @panic("PA resize");
    }
    fn page_allocator_remap(_: *anyopaque, memory: []u8, alignment: Alignment, new_len: usize, _: usize) ?[*]u8 {
        log.debug("Page Allocator: Allocation requested: {} bytes", .{ new_len });

        _ = memory;
        _ = alignment;

        @panic("PA remap");
    }
    fn page_allocator_free(_: *anyopaque, memory: []u8, _: Alignment, _: usize) void {
        log.debug("Page Allocator: Free requested", .{});

        kernel_page_allocator.free(memory);
    }
};
/// Used by zig std library
pub const page_allocator: Allocator = .{
    .ptr = undefined,
    .vtable = &PageAllocator.page_allocator_vtable
};
