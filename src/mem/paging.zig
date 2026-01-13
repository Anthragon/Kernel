const root = @import("root");
const system = @import("system");

const MapPtr = system.mem.MapPtr;

const sys_paging = system.mem.paging;

pub const create_new_map = sys_paging.create_new_map;
pub const get_current_map = sys_paging.get_current_map;
pub const get_commited_map = sys_paging.get_commited_map;
pub const lsmemmap = sys_paging.lsmemmap;

pub const map_single_page = sys_paging.map_single_page;
pub const map_range = sys_paging.map_range;

pub const unmap_single_page = sys_paging.unmap_single_page;
pub const unmap_range = sys_paging.unmap_range;

pub const physFromVirt = sys_paging.phys_from_virt;
pub const physFromPtr = sys_paging.phys_from_ptr;
