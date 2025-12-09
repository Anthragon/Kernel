const root = @import("root");
const zig_mem = @import("std").mem;
const pmm = root.system.pmm;

/// Zig native Allocator structure
pub const Allocator = zig_mem.Allocator;
// Zig native Allignment enumerator
pub const Allignment = zig_mem.Alignment;

pub const heap = @import("heap.zig");

/// Virtual memory manager
pub const vmm = @import("vmm.zig");
// Paging manager
pub const paging = root.system.mem_paging;

pub const ptrFromPhys = pmm.ptrFromPhys;
pub const physFromPtr = pmm.physFromPtr;
pub const physFromVirt = pmm.physFromVirt;
pub const virtFromPhys = pmm.virtFromPhys;

pub const lsmemtable = pmm.lsmemtable;
