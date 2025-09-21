const root = @import("root");
const std = @import("std");
const mem = root.mem;
const Allocator = mem.Allocator;
const Alignment = mem.Allignment;

const debug = root.debug;

/// This is an simplier and direct interface to the real page allocator.
/// Use it it you need some pages!
pub const kernel_page_allocator = root.system.vmm.PageAllocator;

/// This is a abstraction above the `kernel_page_allocator` to be able to
/// use it as a zig's PageAllocator
const PageAllocator = struct {
    const log = std.log.scoped(.page_allocator);

    const page_allocator_vtable: Allocator.VTable = .{ .alloc = page_allocator_alloc, .resize = page_allocator_resize, .remap = page_allocator_remap, .free = page_allocator_free };

    fn page_allocator_alloc(_: *anyopaque, len: usize, alignment: Alignment, _: usize) ?[*]u8 {
        const pages = std.math.divCeil(usize, len, root.system.pmm.page_size) catch unreachable;

        const addr = kernel_page_allocator.alloc(pages, alignment);

        log.debug("Page Allocator: Allocation requested: {} bytes, aligned to {} ({} pages) -> {x}", .{ len, alignment.toByteUnits(), pages, if (addr == null) 0 else @intFromPtr(addr.?) });

        return addr;
    }
    fn page_allocator_resize(_: *anyopaque, memory: []u8, alignment: Alignment, new_len: usize, _: usize) bool {
        log.debug("Page Allocator: Resize requested: {} bytes", .{new_len});

        _ = memory;
        _ = alignment;

        return false;
        //TODO @panic("PA resize");
    }
    fn page_allocator_remap(_: *anyopaque, memory: []u8, alignment: Alignment, new_len: usize, _: usize) ?[*]u8 {
        log.debug("Page Allocator: Allocation requested: {} bytes", .{new_len});

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
pub const page_allocator: Allocator = .{ .ptr = undefined, .vtable = &PageAllocator.page_allocator_vtable };

pub const kernel_buddy_allocator: Allocator = .{
    .ptr = undefined,
    .vtable = &kernel_buddy_allocator_vtable,
};
const kernel_buddy_allocator_vtable: Allocator.VTable = .{
    .alloc = wrapper_alloc,
    .resize = wrapper_resize,
    .remap = wrapper_remap,
    .free = wrapper_free,
};

fn wrapper_alloc(_: *anyopaque, len: usize, alignment: Alignment, ret_addr: usize) ?[*]u8 {
    const alloc = root.mem.vmm.kernel_allocator.?.allocator();
    return alloc.vtable.alloc(alloc.ptr, len, alignment, ret_addr);
}
fn wrapper_resize(_: *anyopaque, memory: []u8, alignment: Alignment, new_len: usize, ret_addr: usize) bool {
    const alloc = root.mem.vmm.kernel_allocator.?.allocator();
    return alloc.vtable.resize(alloc.ptr, memory, alignment, new_len, ret_addr);
}
fn wrapper_remap(_: *anyopaque, memory: []u8, alignment: Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
    const alloc = root.mem.vmm.kernel_allocator.?.allocator();
    return alloc.vtable.remap(alloc.ptr, memory, alignment, new_len, ret_addr);
}
fn wrapper_free(_: *anyopaque, memory: []u8, alignment: Alignment, ret_addr: usize) void {
    const alloc = root.mem.vmm.kernel_allocator.?.allocator();
    return alloc.vtable.free(alloc.ptr, memory, alignment, ret_addr);
}
