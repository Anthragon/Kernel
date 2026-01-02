const std = @import("std");
const root = @import("root");
const debug = root.debug;
const log = std.log.scoped(.syscalls);

const TaskContext = root.threading.TaskContext;

const quickactions = @import("quickactions.zig");
const proccessmanagement = @import("proccessmanagement.zig");
const modulehelpers = @import("modulehelpers.zig");

pub fn init() void {
    root.interrupts.set_vector(0x80, syscall_router, .user);
}

fn syscall_router(frame: *TaskContext) void {
    log.info("Syscall!", .{});

    const vector = frame.get_syscall_vector();
    const group = (vector >> 16) & 0xffff;
    const func = vector & 0xffff;

    switch (group) {
        else => undefined_syscall(group, func),

        0x00 => switch (func) {
            else => undefined_syscall(group, func),

            0x00 => quickactions.suicide(frame),
            0x01 => quickactions.get_task_id(frame),
            0x02 => quickactions.get_descriptor_kind(frame),
            0x03 => quickactions.heap_alloc(frame),
            0x04 => quickactions.heap_remap(frame),
            0x05 => quickactions.heap_resize(frame),
            0x06 => quickactions.heap_free(frame),
        },

        0x01 => switch (func) {
            else => undefined_syscall(group, func),

            0x00 => proccessmanagement.spawn(frame),
            0x01 => proccessmanagement.kill(frame),
            0x02 => proccessmanagement.signalize(frame),
            0x03 => proccessmanagement.wait(frame),
            0x04 => proccessmanagement.set_priority(frame),
        },

        0x0B => switch (func) {
            else => undefined_syscall(group, func),

            0x00 => modulehelpers.load_kernel_vtable(frame),
        },
    }
}

fn undefined_syscall(group: usize, func: usize) void {
    _ = group;
    _ = func;
}
