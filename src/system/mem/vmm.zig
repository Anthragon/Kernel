const std = @import("std");
const root = @import("root");
const paging = root.system.mem_paging;
const pmm = root.system.pmm;
const debug = root.debug;

const Alignment = std.mem.Alignment;
const Allocator = std.mem.Allocator;

const free_magic: u32 = 0x626F6F42;
const used_magic: u32 = 0x73746954;

var kernel_heap_next_addr: usize = undefined;

pub var kernel_buddy_allocator: KernelBuddyAllocator = undefined;
pub const kernel_page_allocator = KernelPageAllocator;

// Implementation of a buddy allocator
pub const KernelBuddyAllocator = struct {
    blocks_root: *Block,
    rover: *Block,

    const base_alignment = 32;
    pub const vtable: Allocator.VTable = .{
        .alloc = &alloc,
        .resize = &resize,
        .remap = &remap,
        .free = &free
    };

    fn alloc(self: *anyopaque, len: usize, alignment: Alignment, ret_addr: usize) ?[*]u8 {
        
        _ = alignment;
        _ = ret_addr;

        const aligned_len = std.mem.alignForward(usize, len, base_alignment);
        var s: *KernelBuddyAllocator = @ptrCast(@alignCast(self));

        debug.err("allocation requested: {}; aligned: {}\n", .{len, aligned_len});

        // Finding a free block
        const free_block: *Block = b: {

            for (0..5) |_| { 

                var cur: ?*Block = s.rover;
                cur.?.doTest();
                var i: usize = 0;

                while (cur != null and !(i > 0 and cur == s.rover.prev)) : ({ cur = cur.?.next; i += 1; }) {
                    if (cur.?.is_free() and cur.?.len >= aligned_len) break :b cur.?;
                }

                s.extend_heap() catch return null;
            }
            return null;
        };

        // Slicing the block if necessary
        if (free_block.len - aligned_len - @sizeOf(Block) > base_alignment) {

            const next: *Block = @ptrFromInt(@intFromPtr(free_block) + @sizeOf(Block) + aligned_len);
            next.len = free_block.len - aligned_len - @sizeOf(Block);
            free_block.len = aligned_len;

            next.set_use(false);
            next.prev = free_block;
            next.next = free_block.next;

            free_block.next = next;
            free_block.set_use(false);

            s.rover = next;
        }

        free_block.set_use(true);
        const buf: [*]u8 = @ptrFromInt(@intFromPtr(free_block) + @sizeOf(Block));
        @memset(buf[0..free_block.len], 0xAA);
        return buf;
    }
    fn resize(self: *anyopaque, memory: []u8, alignment: Alignment, new_len: usize, ret_addr: usize) bool {

        _ = alignment;
        _ = ret_addr;

        const aligned_len = std.mem.alignForward(usize, new_len, base_alignment);
        var s: *KernelBuddyAllocator = @ptrCast(@alignCast(self));

        debug.err("resize requested: {}; aligned: {}\n", .{new_len, aligned_len});

        const curr_block: *Block = @ptrFromInt(@intFromPtr(memory.ptr) - @sizeOf(Block));
        curr_block.doTest();

        // If there's no next block or next block is used, cannot resize
        if (curr_block.next == null or !curr_block.next.?.is_free()) return false;
        const next_block = curr_block.next.?;
        next_block.doTest();

        // If there's a gap between this and the next block, cannot resize
        if (@intFromPtr(curr_block) + @sizeOf(Block) + curr_block.len != @intFromPtr(next_block)) return false;

        const block_size = curr_block.len + next_block.len + @sizeOf(Block);

        // If the current block + next block (header included) is lesser than
        // aligned_len, cannot resize
        if (block_size < aligned_len) return false;

        // If the block is big enough to be sliced, do it
        const block_rest = block_size - aligned_len;
        if (block_rest > @sizeOf(Block) + base_alignment) {

            const nblock: *Block = @ptrFromInt(@intFromPtr(curr_block) + @sizeOf(Block) + aligned_len);

            nblock.* = .{
                .len = block_rest - @sizeOf(Block),
                .prev = curr_block,
                .next = next_block.next,
            };
            nblock.set_use(false);
            curr_block.next = nblock;
            
            // Set the new empty memory as undefined
            const new_slice_start: [*]u8 = @ptrFromInt(@intFromPtr(curr_block) + curr_block.len + @sizeOf(Block));
            const new_slice_len = aligned_len - curr_block.len;
            @memset(new_slice_start[0 .. new_slice_len], 0xAA);

            // Select it as current rover if before the old one
            if (@intFromPtr(nblock) < @intFromPtr(s.rover)) s.rover = nblock;

            return true;
        }

        // Set the new empty memory as undefined
        const new_slice_start: [*]u8 = @ptrFromInt(@intFromPtr(curr_block) + curr_block.len + @sizeOf(Block));
        const new_slice_len = aligned_len - curr_block.len;
        @memset(new_slice_start[0..new_slice_len], 0xAA);

        // Merging the blocks
        curr_block.len = aligned_len;
        curr_block.next = next_block.next;

        return true;
    }
    fn remap(self: *anyopaque, memory: []u8, alignment: Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
        _ = self;
        _ = memory;
        _ = alignment;
        _ = ret_addr;

        const aligned_len = std.mem.alignForward(usize, new_len, 8);

        debug.err("remap requested: {}; aligned: {}\n", .{new_len, aligned_len});

        return null;
    }
    fn free(self: *anyopaque, memory: []u8, alignment: Alignment, ret_addr: usize) void {
        _ = alignment;
        _ = ret_addr;

        debug.err("free requested\n", .{});

        var s: *KernelBuddyAllocator = @ptrCast(@alignCast(self));

        const curr_block: *Block = @ptrFromInt(@intFromPtr(memory.ptr) - @sizeOf(Block));
        curr_block.doTest();
        if (curr_block.is_free()) @panic("Trying to free not allocated memory!");

        curr_block.set_use(false);
        if (curr_block.len > 64) s.rover = curr_block;
    }

    fn extend_heap(kalloc: @This()) !void {
        _ = kalloc;
        @panic("Extend heap not implemented yet!");
        // TODO This function should allocate a new block of memory and add it to the
        // end of the linked list of blocks.
        // It should also update the `rover` pointer if necessary.
        // For now, it just panics to indicate that this functionality is not yet implemented.
    }

    pub fn lsmemblocks(s: @This()) void {
        var cur: ?*Block = s.blocks_root;
        var i: usize = 0;

        while (cur != null) : ({ cur = cur.?.next; i += 1; }) {
            const c_start = @intFromPtr(cur) + @sizeOf(Block);

            const block_bytes = std.mem.asBytes(cur.?);
            debug.err("{X: <16} :", .{@intFromPtr(cur.?)});

            var buf: [32*3 + 32]u8 = undefined;
            var ptr: usize = 0;

            for (0..32) |j| ptr += (std.fmt.bufPrint(buf[ptr ..], "{X:0>2} ", .{block_bytes[j]}) catch unreachable).len;
            for (0..32) |j| ptr += (std.fmt.bufPrint(buf[ptr ..], "{c}", .{ if (std.ascii.isPrint(block_bytes[j])) block_bytes[j] else '.' }) catch unreachable).len;
            debug.err("{s}\n", .{buf[0..ptr]});
            
            debug.err("{x: >8}, {X: >16}, {X: >16}: ", .{cur.?.magic_a, c_start, cur.?.len});

            const c_end = @addWithOverflow(c_start, cur.?.len);
            debug.err("{s} {X} .. {X}{s} ({} bytes) - {s} (next in {X})", .{
                if (cur.?.doTestFailable()) "OK " else "BAD",
                c_start,
                c_end[0],
                if (c_end[1] == 1) "!" else " ",
                cur.?.len,
                if (cur.?.is_free()) "free" else "used",
                if (cur.?.next) |n| @intFromPtr(n) else 0
            });
            
            if (s.blocks_root == cur) debug.err(" (root)", .{});
            if (s.blocks_root.prev == cur) debug.err(" (end)", .{});
            if (s.rover == cur) debug.err(" (rover)", .{});

            debug.err("\n\n", .{});
            if (!cur.?.doTestFailable()) break;
        }
    }

    pub const Block = packed struct {
        magic_a: u32 = 0,
        len: usize,
        prev: ?*Block,
        next: ?*Block,
        magic_b: u32 = 0,

        pub fn doTest(s: *@This()) void {
            if (!s.doTestFailable())
                @panic("Invalid memory block detected (if indeed allocated, maybe it is a heap corruption)!");
        }
        pub fn doTestFailable(s: *@This()) bool {
            return (s.magic_a == free_magic or s.magic_a == used_magic) and s.magic_a == s.magic_b;
        }
        pub fn is_free(s: *@This()) bool {
            return s.magic_a == s.magic_b and s.magic_a == free_magic;
        }
        pub fn set_use(s: *@This(), value: bool) void {
            if (value) {
                s.magic_a = used_magic;
                s.magic_b = used_magic;
            } else {
                s.magic_a = free_magic;
                s.magic_b = free_magic;
            }
        }
    };
};

// Implementation of a slab allocator TODO
pub const KernelSlabAllocator = struct {

};

// Implementation of a page allocator
/// Kernel page allocator \
/// This structure does not uses the zig standard allocator,
/// instead it is directly refered and it interaction happens
/// though a simplier allocator
pub const KernelPageAllocator = struct {

    pub fn alloc(size: usize) ?[*]u8 {
        // TODO
        _ = size;
        return null;
    }
    pub fn free(memory: []u8) void {
        _ = memory;
        // TODO
    }
    
    /// Diferently of alloc, will only request
    /// space inside the kernel address space,
    /// without mapping any page
    pub fn request_space(size: usize) usize {
        
        const curr_addr = kernel_heap_next_addr;

        const aligned_size = std.mem.alignForward(usize, size, pmm.page_size);
        kernel_heap_next_addr += aligned_size;

        return curr_addr;

    }
    /// Diferently of free, will subtract
    /// space from the kernel address space.
    /// Musb be used with caution and right after
    /// `request_space`
    pub fn free_space(size: usize) void {
        const aligned_size = std.mem.alignForward(usize, size, pmm.page_size);
        kernel_heap_next_addr -= aligned_size;
    }
};

pub fn init() void {
    // Allocating 2 pages to use as initial heap
    const heap_raw =  pmm.get_multiple_pages(16, .kernel_heap);
    const heap_start = pmm.kernel_virt_end + pmm.page_size;

    // Mapping it to after the kernel
    paging.map_range(
        pmm.physFromPtr(heap_raw),
        heap_start,
        16 * pmm.page_size,
        pmm.atributes_ROX_privileged_fixed
    ) catch unreachable;
    const heap: *anyopaque = @ptrFromInt(heap_start);

    @memset(@as([*]u8, @ptrCast(@alignCast(heap)))[0 .. pmm.page_size * 2], '@');

    const block_root: *KernelBuddyAllocator.Block = @ptrCast(@alignCast(heap));
    block_root.* = .{
        .len = pmm.page_size * 2 - @sizeOf(KernelBuddyAllocator.Block),
        .prev = null,
        .next = null
    };
    block_root.set_use(false);

    debug.err("Kernel allocator root at: {X}\n", .{ @intFromPtr(block_root) });

    kernel_buddy_allocator = .{
        .blocks_root = block_root,
        .rover = block_root,
    };
    kernel_heap_next_addr = heap_start + pmm.page_size * 16;
}

pub fn lsmemblocks() void {
    debug.err("Kernel allocator memory blocks:\n", .{});
    debug.err("--------------------------------------------------------------------\n", .{});
    kernel_buddy_allocator.lsmemblocks();
    debug.err("--------------------------------------------------------------------\n", .{});
    debug.err("\n", .{});
}

