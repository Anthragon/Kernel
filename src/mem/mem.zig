const root = @import("root");
const zig_mem = @import("std").mem;

/// Zig native Allocator structure
pub const Allocator = zig_mem.Allocator;
// Zig native Allignment enumerator
pub const Allignment = zig_mem.Alignment;

pub const heap = @import("heap.zig");

/// Physical memory manager
pub const pmm = root.system.pmm;
/// Virtual memory manager
pub const vmm = root.system.vmm;

pub const ptrFromPhys = pmm.ptrFromPhys;
pub const physFromPtr = pmm.physFromPtr;
pub const physFromVirt = pmm.physFromVirt;
pub const virtFromPhys = pmm.virtFromPhys;
