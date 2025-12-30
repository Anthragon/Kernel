const root = @import("root");
const Guid = root.utils.Guid;

pub const BootInfo = extern struct {
    framebuffer: Framebuffer,
    memory_map: [*]*MemoryMapEntry,
    memory_map_len: usize,

    boot_device_tag: BootDeviceTag,
    boot_device: BootDevice,

    kernel_stack_pointer_base: usize,
    kernel_base_virtual: usize,
    kernel_base_physical: usize,

    hhdm_base_offset: usize,

    rsdp_physical: usize,
};

pub const Framebuffer = extern struct {
    framebuffer: [*]u8,
    buffer_length: usize,
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

pub const BootDeviceTag = enum(usize) { mbr, gpt };
pub const BootDevice = extern union {
    mbr: extern struct {
        disk_id: usize,
        partition_index: usize,
    },
    gpt: extern struct {
        disk_uuid: Guid,
        part_uuid: Guid,
    },
};
