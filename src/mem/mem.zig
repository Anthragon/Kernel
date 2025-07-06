const root = @import("root");
const zig_mem = @import("std").mem;

/// Zig native Allocator structure
pub const Allocator = zig_mem.Allocator;
// Zig native Allignment enumerator
pub const Allignment = zig_mem.Alignment;

pub const heap = @import("heap.zig");

/// Physical memory manager
const pmm = switch (root.system.arch) {
    .x86_64 => @import("../system/x86_64/mem/pmm.zig"),
    //.x86 => @import("../system/x86_64/mem/pmm.zig"),
    //.aarch64 => @import("../system/x86_64/mem/pmm.zig"),
    else => undefined
};

pub const ptrFromPhys = pmm.ptrFromPhys;
pub const physFromPtr = pmm.physFromPtr;
pub const physFromVirt = pmm.physFromVirt;
pub const virtFromPhys = pmm.virtFromPhys;
