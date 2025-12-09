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
    else => unreachable
};
pub const serial = switch (arch) {
    .x86_64 =>  @import("x86_64/serial.zig"),
    else => unreachable
};

/// Memory and pagination management
pub const mem_paging = @import("paging.zig");
/// Physical Memory Manager
pub const pmm = switch (arch) {
    .x86_64 =>  @import("x86_64/mem/pmm.zig"),
    else => unreachable
};

// Tasks and Theading
/// Task Context
pub const TaskContext = switch (arch) {
    .x86_64 => @import("x86_64/taskContext.zig").TaskContext,
    else => unreachable
};
/// Task Context Flags
pub const TaskGeneralFlags = struct {
    carry: bool,
    zero: bool,
    sign: bool,
    overflow: bool,
    interrupt: bool
};

// Misc
/// Quick assembly interface
pub const assembly = switch (arch) {
    .x86_64 =>  @import("x86_64/asm/asm.zig"),
    else => unreachable
};


/// Specific system routines
/// for each archtecture
const general = switch (arch) {
    .x86_64 =>  @import("x86_64/general.zig"),
    else => unreachable
};

/// System-Specific general initialization
pub const init = general.init;
/// System-Specific general initialization finalize
pub const finalize = general.finalize;


/// Endian to host \
/// Forcefully converts the endianness of the integer value given if diferent of the
/// host endianness.
pub inline fn en2h(comptime T: type, x: T, comptime e: std.builtin.Endian) T {
    return if (endian == e) return x else @byteSwap(x);
}
