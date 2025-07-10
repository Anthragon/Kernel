const std = @import("std");
const root = @import("root");
const vmm = @import("vmm.zig");
const pmm = root.system.pmm;
const paging = root.system.mem_paging;

/// Kernel Page Allocator
/// This structure does not uses the zig standard allocator,
/// instead it is directly refered and it interaction happens
/// though a simplier allocator
pub const KernelPageAllocator = struct {

    pub fn alloc(size: usize) ?[*]u8 {
        const vaddr = reserve(size);

        for (0 .. size) |i| {
            const page = pmm.get_single_page(.kernel_heap);
            paging.map_single_page(
                pmm.physFromPtr(page),
                vaddr + i*pmm.page_size,
                10,
                .{
                    .disable_cache = false,
                    .execute = false,
                    .lock = true,
                    .privileged = true,
                    .read = true,
                    .write = true,
                },
            ) catch |err| std.debug.panic("Mapping error: {s} (vaddress {x})!", .{ @errorName(err), vaddr });
        }

        return @as([*]u8, @ptrFromInt(vaddr));
    }
    /// Diferently of alloc, will only request
    /// space inside the kernel address space,
    /// without mapping any page
    pub fn reserve(size: usize) usize {
        
        const curr_addr = vmm.kernel_heap_next_addr;
        vmm.kernel_heap_next_addr += size * pmm.page_size;
        return curr_addr;

    }

    pub fn free(memory: []u8) void {
        _ = memory;
        // TODO        
    }
    // TODO use only free
    pub fn free_space(size: usize) void {
        const aligned_size = std.mem.alignForward(usize, size, pmm.page_size);
        vmm.kernel_heap_next_addr -= aligned_size;
    }
};
