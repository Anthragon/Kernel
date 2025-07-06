const std = @import("std");
const root = @import("root");
const builtin = @import("builtin");

pub const arch = builtin.cpu.arch;
pub const endian = arch.endian();

pub const Privilege = enum { kernel, user };

// Zig interfaces related
pub const std_options = switch(arch) {
    .x86_64 => @import("x86_64/std_options.zig"),
    else => unreachable
};

// IO
pub const ports = switch (arch) {
    .x86_64 => @import("x86_64/ports.zig"),
    .aarch64 => @panic("IO ports not available for " ++ arch ++ "!"),
    else => unreachable
};
pub const serial = switch (arch) {
    .aarch64 => @import("aarchx64/serial.zig"),
    .x86_64 =>  @import("x86_64/serial.zig"),
    .x86 =>     @import("x86/serial.zig"),
    else => unreachable
};

/// Memory and pagination management
pub const mem_paging = @import("paging.zig");
pub const pmm = switch (arch) {
    //.aarch64 => @import("aarchx64/asm.zig"),
    .x86_64 =>  @import("x86_64/mem/pmm.zig"),
    //.x86 =>     @import("x86/asm.zig"),
    else => unreachable
};
pub const vmm = @import("mem/vmm.zig");
/// Interrupt management
pub const interrupts = @import("interrupts.zig");

/// Tasks and Theading
pub const TaskContext = switch (arch) {
    //.aarch64 => @import("aarchx64/asm.zig"),
    .x86_64 => @import("x86_64/taskContext.zig").TaskContext,
    //.x86 =>     @import("x86/asm.zig"),
    else => unreachable
};
pub const TaskGeneralFlags = struct {
    carry: bool,
    zero: bool,
    sign: bool,
    overflow: bool,
    interrupt: bool
};

/// Timing and timestamps
pub const time = @import("time.zig");

// Misc
pub const assembly = switch (arch) {
    //.aarch64 => @import("aarchx64/asm.zig"),
    .x86_64 =>  @import("x86_64/asm/asm.zig"),
    //.x86 =>     @import("x86/asm.zig"),
    else => unreachable
};


/// Specific system routines
/// for each archtecture
const general = switch (arch) {
    .aarch64 => @import("aarchx64/general.zig"),
    .x86_64 =>  @import("x86_64/general.zig"),
    .x86 =>     @import("x86/general.zig"),
    else => unreachable
};

pub const init = general.init;
pub const finalize = general.finalize;


/// Endian to host \
/// Forcefully converts the endianness of the integer value given if diferent of the
/// host endianness.
pub inline fn en2h(comptime T: type, x: T, comptime e: std.builtin.Endian) T {
    return if (endian == e) return x else @byteSwap(x);
}
