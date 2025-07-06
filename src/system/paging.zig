const root = @import("root");
const system = root.system;

const MapPtr = switch (system.arch) {
    //.aarch64 => ,
    .x86_64 => @import("x86_64/mem/paging.zig").MapPtr,
    //.x86 => ,
    else => unreachable,
};

pub const Attributes = packed struct(u16) {
  // access permitions
  read: bool = true,
  write: bool = true,
  execute: bool = false,
  
  // general attributes
  privileged: bool = false,
  disable_cache: bool = false,
  unitialized: bool = false,
  lock: bool = false,
  interrupt: bool = false,
  
  // automatic grow
  growns_up: bool = false,
  growns_down: bool = false,
  
  _unused_: u6 = 0
};

pub const MMapError = error {
  AddressAlreadyMapped,
  AddressNotMapped,
  Missaligned
};

pub const MemStatus = enum(usize) {
    unused = 0, // not being used, can be overrided
    free,
    reserved,

    kernel,
    kernel_heap,
    mem_page,
    framebuffer,

    program_code,
    program_data,
    program_misc,
};

const sys_paging = switch (system.arch) {
  //.x86 => ,
  .x86_64 => @import("x86_64/mem/paging.zig"),
  else => unreachable
};

pub const create_new_map = sys_paging.create_new_map;
pub const set_current_map = sys_paging.set_current_map;
pub const get_current_map = sys_paging.get_current_map;
pub const load_commited_map = sys_paging.load_commited_map;
pub const lsmemmap = sys_paging.lsmemmap;

pub const map_single_page = sys_paging.map_single_page;
pub const map_range = sys_paging.map_range;

pub const unmap_single_page = sys_paging.unmap_single_page;
pub const unmap_range = sys_paging.unmap_range;
