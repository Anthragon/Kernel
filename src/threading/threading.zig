const std = @import("std");
const root = @import("root");
const sys = root.system;

const log = std.log.scoped(.theading);

pub const Process = @import("Process.zig");
pub const Task = @import("Task.zig");

pub const TaskContext = sys.TaskContext;

pub const procman = @import("process_manager.zig");
pub const scheduler = @import("scheduler.zig");

pub fn init() void {
    log.debug(" ## Setting up threading service...", .{});

    procman.init();
    scheduler.init();
}
