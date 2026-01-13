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

    _unused_: u6 = 0,
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

pub const MMapErrorInterop = enum(usize) {
    NoError = 0,
    Unknown = 1,

    AddressAlreadyMapped,
    AddressNotMapped,
    Missaligned,
};
