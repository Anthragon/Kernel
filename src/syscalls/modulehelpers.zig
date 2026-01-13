const std = @import("std");
const root = @import("root");
const debug = root.debug;
const log = std.log.scoped(.@"syscalls 0B");

const TaskContext = root.threading.TaskContext;

pub fn load_kernel_vtable(frame: *TaskContext) void {
    _ = frame;
    log.info("Fuck return this shit now", .{});
    unreachable;
}
