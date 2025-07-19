const std = @import("std");
const root = @import("root");
const sys = root.system;

pub const Process = @import("Process.zig");
pub const Task = @import("Task.zig");

pub const TaskContext = sys.TaskContext;

pub const procman = @import("process_manager.zig");
pub const scheduler = @import("scheduler.zig");

pub fn init() void {
    std.log.debug(" ## Setting up threading service...\n", .{});

    procman.init();
    scheduler.init();
}
