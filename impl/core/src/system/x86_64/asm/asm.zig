pub const flags = @import("flags.zig");
pub const ctrl_regs = @import("ctrl_regs.zig");
pub const cpuid = @import("cpuid.zig");

pub inline fn halt() noreturn {
    asm volatile("hlt");
    unreachable;
}
