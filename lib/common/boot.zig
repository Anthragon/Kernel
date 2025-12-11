const root = @import("root");
const Guid = root.utils.Guid;

pub const BootInfo = struct {
    framebuffer: Framebuffer,
    memory_map: []*MemoryMapEntry,

    boot_device: BootDevice,

    kernel_stack_pointer_base: usize,
    kernel_base_virtual: usize,
    kernel_base_physical: usize,

    hhdm_base_offset: usize,

    rsdp_physical: usize,
};

pub const Framebuffer = struct {
    framebuffer: []u8,
    width: u64,
    height: u64,
    pps: u64,
};

pub const MemoryMapEntry = extern struct {
    base: u64,
    size: u64,
    type: RegionType,
};

pub const RegionType = enum(u64) {
    usable = 0,
    reserved = 1,
    acpi_reclaimable = 2,
    acpi_nvs = 3,
    bad_memory = 4,
    bootloader_reclaimable = 5,
    kernel_and_modules = 6,
    framebuffer = 7,
};

pub const BootDeviceTag = enum { mbr, gpt };
pub const BootDevice = union(BootDeviceTag) {
    mbr: struct {
        disk_id: usize,
        partition_index: usize,
    },
    gpt: struct {
        disk_uuid: Guid,
        part_uuid: Guid,
    },
};