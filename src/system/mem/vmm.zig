const std = @import("std");
const builtin = @import("builtin");
const root = @import("root");
const paging = root.system.mem_paging;
const pmm = root.system.pmm;
const debug = root.debug;

const Alignment = std.mem.Alignment;
const Allocator = std.mem.Allocator;

/// Kernel's simplified page allocator
pub const PageAllocator = @import("page_allocator.zig").KernelPageAllocator;

var kernel_heap_start: usize = undefined;
pub var kernel_heap_next_addr: usize = undefined;

const DebugAllocator = std.heap.DebugAllocator(.{
    .thread_safe = false,
    .verbose_log = true,
    .canary = 0,
    .stack_trace_frames = 0,
});
var debug_allocator: ?DebugAllocator = null;


pub fn get_debug_allocator_controller() ?DebugAllocator {
    return debug_allocator;
}

pub fn init() void {
    
    kernel_heap_start = pmm.kernel_virt_end + 2048 * pmm.page_size;
    kernel_heap_next_addr = kernel_heap_start;

    debug.err("Heap start located at {x}\n", .{ kernel_heap_start });

    var gpa: Allocator = undefined;

    debug_allocator = .init;
    gpa = debug_allocator.?.allocator();

    // // Crimes here! // //
    const target = @constCast(&root.mem.heap.kernel_buddy_allocator);
    target.* = gpa;

}
