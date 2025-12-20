const std = @import("std");
const root = @import("root");
const vmm = @import("vmm.zig");
const pmm = @import("system").mem.pmm;
const paging = root.mem.paging;

const Alignment = std.mem.Alignment;

const log = std.log.scoped(.@"page allocator");

/// Kernel Page Allocator
/// This structure does not uses the zig standard allocator,
/// instead it is directly refered and it interaction happens
/// though a simplier allocator
pub const KernelPageAllocator = struct {
    pub fn alloc(size: usize, alignment: Alignment) ?[*]u8 {
        const vaddr = reserve(size, alignment);

        log.debug("allocating {} pages in address {x}", .{ size, vaddr });

        for (0..size) |i| {
            const page = pmm.get_single_page(.kernel_heap);
            paging.map_single_page(
                pmm.physFromPtr(page),
                vaddr + i * pmm.page_size,
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
    pub fn realloc(old_mem: [*]u8, size: usize, alignment: Alignment) ?[*]u8 {
        log.debug("reallocating {} pages", .{size});

        _ = old_mem;
        _ = alignment;

        // TODO impllement realloc
        return null;
    }

    /// Diferently of alloc, will only request
    /// space inside the kernel address space,
    /// without mapping any page
    pub fn reserve(size: usize, alignment: Alignment) usize {
        vmm.kernel_heap_next_addr = alignment.forward(vmm.kernel_heap_next_addr);

        const curr_addr = vmm.kernel_heap_next_addr;
        vmm.kernel_heap_next_addr += size * pmm.page_size;
        return curr_addr;
    }

    pub fn free(memory: anytype) void {
        _ = memory;
        // TODO
    }
};
