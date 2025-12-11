const std = @import("std");
const builtin = @import("builtin");
const system = @import("system");
const root = @import("root");
const paging = root.mem.paging;
const pmm = system.mem.pmm;
const debug = root.debug;

const log = std.log.scoped(.vmm);

const Alignment = std.mem.Alignment;
const Allocator = std.mem.Allocator;

/// Kernel's simplified page allocator
pub const PageAllocator = @import("page_allocator.zig").KernelPageAllocator;
pub const BuddyAllocator = @import("buddy_allocator.zig").BuddyAllocator;

var kernel_heap_start: usize = undefined;
pub var kernel_heap_next_addr: usize = undefined;

pub var kernel_allocator: ?BuddyAllocator = .{};

pub fn init() void {
    kernel_heap_start = pmm.kernel_virt_end + 2048 * pmm.page_size;
    kernel_heap_next_addr = kernel_heap_start;

    log.debug("Heap start located at {x}", .{kernel_heap_start});
}
