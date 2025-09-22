const builtin = @import("builtin");
const std = @import("std");
const root = @import("root");

const assert = std.debug.assert;
const mem = std.mem;
const math = std.math;
const Allocator = std.mem.Allocator;
const PageAllocator = root.mem.vmm.PageAllocator;

const slab_len: usize = @max(std.heap.page_size_max, 64 * 1024);
const min_class = math.log2(@sizeOf(usize));
const size_class_count = math.log2(slab_len) - min_class;
const max_alloc_search = 1;

const Mutex = root.threading.Mutex;

pub const vtable: Allocator.VTable = .{
    .alloc = alloc,
    .resize = resize,
    .remap = remap,
    .free = free,
};

pub const BuddyAllocator = struct {
    mutex: Mutex = .{},

    next_addrs: [size_class_count]usize = @splat(0),
    frees: [size_class_count]usize = @splat(0),

    pub inline fn mutex_lock(s: *@This()) void {
        s.mutex.lock();
    }
    pub inline fn mutex_unlock(s: *@This()) void {
        s.mutex.unlock();
    }

    pub fn allocator(s: *@This()) std.mem.Allocator {
        return .{
            .ptr = @ptrCast(s),
            .vtable = &vtable,
        };
    }

    pub fn init() BuddyAllocator {
        return .{};
    }
    pub fn deinit(s: *@This()) void {
        _ = s;
    }
};

fn alloc(context: *anyopaque, len: usize, alignment: mem.Alignment, ra: usize) ?[*]u8 {
    const ctx: *BuddyAllocator = @ptrCast(@alignCast(context));
    _ = ra;

    const class = sizeClassIndex(len, alignment);
    if (class >= size_class_count) {
        @branchHint(.unlikely);
        return PageAllocator.alloc(
            std.math.divCeil(usize, len, std.heap.page_size_max) catch unreachable,
            alignment,
        );
    }

    const slot_size = slotSize(class);
    assert(slab_len % slot_size == 0);
    var search_count: u8 = 0;

    ctx.mutex_lock();

    while (true) : (search_count += 1) {
        const top_free_ptr = ctx.frees[class];
        if (top_free_ptr != 0) {
            @branchHint(.likely);
            defer ctx.mutex_unlock();

            const node: *usize = @ptrFromInt(top_free_ptr);
            ctx.frees[class] = node.*;
            return @ptrFromInt(top_free_ptr);
        }

        const next_addr = ctx.next_addrs[class];
        if ((next_addr % slab_len) != 0) {
            @branchHint(.likely);
            defer ctx.mutex_unlock();

            ctx.next_addrs[class] = next_addr + slot_size;
            return @ptrFromInt(next_addr);
        }

        if (search_count >= max_alloc_search) {
            @branchHint(.likely);
            defer ctx.mutex_unlock();

            const slab = PageAllocator.alloc(
                std.math.divCeil(usize, slab_len, std.heap.page_size_max) catch unreachable,
                .fromByteUnits(slab_len),
            ) orelse return null;
            ctx.next_addrs[class] = @intFromPtr(slab) + slot_size;
            return slab;
        }

        ctx.mutex_unlock();
    }
}

fn resize(context: *anyopaque, memory: []u8, alignment: mem.Alignment, new_len: usize, ra: usize) bool {
    _ = context;
    _ = ra;

    const class = sizeClassIndex(memory.len, alignment);
    const new_class = sizeClassIndex(new_len, alignment);

    if (class >= size_class_count) {
        if (new_class < size_class_count) return false;
        return PageAllocator.realloc(memory.ptr, new_len, alignment) != null;
    }

    return new_class == class;
}

fn remap(context: *anyopaque, memory: []u8, alignment: mem.Alignment, new_len: usize, ra: usize) ?[*]u8 {
    _ = context;
    _ = ra;

    const class = sizeClassIndex(memory.len, alignment);
    const new_class = sizeClassIndex(new_len, alignment);

    if (class >= size_class_count) {
        if (new_class < size_class_count) return null;
        return PageAllocator.realloc(memory.ptr, new_len, alignment);
    }

    return if (new_class == class) memory.ptr else null;
}

fn free(context: *anyopaque, memory: []u8, alignment: mem.Alignment, ra: usize) void {
    const ctx: *BuddyAllocator = @ptrCast(@alignCast(context));
    _ = ra;

    const class = sizeClassIndex(memory.len, alignment);
    if (class >= size_class_count) {
        @branchHint(.unlikely);
        return PageAllocator.free(memory);
    }

    const node: *usize = @ptrCast(@alignCast(memory.ptr));

    ctx.mutex.lock();
    defer ctx.mutex.unlock();

    node.* = ctx.frees[class];
    ctx.frees[class] = @intFromPtr(node);
}

fn sizeClassIndex(len: usize, alignment: mem.Alignment) usize {
    return @max(@bitSizeOf(usize) - @clz(len - 1), @intFromEnum(alignment), min_class) - min_class;
}

fn slotSize(class: usize) usize {
    return @as(usize, 1) << @intCast(class + min_class);
}
