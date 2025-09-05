const std = @import("std");
const root = @import("root");
const sys = root.system;
const debug = root.debug;

const log = std.log.scoped(.interrupt);

const TaskContext = root.system.TaskContext;

pub const InterruptHandler = *const fn (*TaskContext) void;
pub var interrupts: [256]?InterruptHandler = [_]?InterruptHandler{null} ** 256;

pub const syscall_vector: u8 = 0x80;
pub const spurious_vector: u8 = 0xFF;

const system_idt = switch (sys.arch) {
    .x86_64 => @import("x86_64/interruptDescriptorTable.zig"),
    else => unreachable,
};

// Interrupt functions
fn unhandled_interrupt(frame: *TaskContext) void {
    log.debug("\nUnhandled interrupt {0} (0x{0X:0>2})!", .{frame.intnum});
    log.debug("{f}", .{frame});
}

pub fn interrupt_handler(int_frame: *TaskContext) void {
    int_frame.intnum &= 0xFF;
    //log.info("Branching to interrupt {X:0>2}...", .{int_frame.intnum});
    debug.lock_frame(int_frame.get_frame_base());
    const handler = interrupts[int_frame.intnum] orelse unhandled_interrupt;
    handler(int_frame);
    debug.unlock_frame();
}

// Allocates a not used interrupt and returns it number
pub fn allocate_vector() u8 {
    for (0x30..0xF0) |i| {
        if (interrupts[i] == unhandled_interrupt) return @intCast(i);
    }
    @panic("No interrupt vector availeable!");
}

pub fn set_vector(int: u8, func: ?InterruptHandler, privilege: sys.Privilege) void {
    interrupts[int] = func;
    system_idt.set_privilege(int, privilege);
}
