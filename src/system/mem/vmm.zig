const std = @import("std");
const builtin = @import("builtin");
const root = @import("root");
const paging = root.system.mem_paging;
const pmm = root.system.pmm;
const debug = root.debug;

const Alignment = std.mem.Alignment;
const Allocator = std.mem.Allocator;

/// Kernel's simplified kernel allocator
pub const PageAllocator = @import("page_allocator.zig").KernelPageAllocator;

pub var kernel_heap_next_addr: usize = undefined;

const DebugAllocator = std.heap.DebugAllocator(.{
    .thread_safe = false,
    .verbose_log = true,
    .canary = 0,
});
var debug_allocator: ?DebugAllocator = null;


pub fn get_debug_allocator_controller() ?DebugAllocator {
    return debug_allocator;
}

pub fn init() void {
    
    const heap_start = pmm.kernel_virt_end + pmm.page_size;
    kernel_heap_next_addr = heap_start;

    var gpa: Allocator = undefined;

    switch (builtin.mode) {
        .Debug, .ReleaseSafe => {
            debug_allocator = .init;
            gpa = debug_allocator.?.allocator();
        },
        .ReleaseFast, .ReleaseSmall => {
            gpa = std.heap.smp_allocator;
        },
    }

    // // Crimes here! // //
    const target = @constCast(&root.mem.heap.kernel_buddy_allocator);
    target.* = gpa;

}
