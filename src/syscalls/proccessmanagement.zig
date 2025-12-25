const std = @import("std");
const root = @import("root");
const debug = root.debug;
const log = std.log.scoped(.@"syscalls 02");

const TaskContext = root.threading.TaskContext;

pub fn spawn(frame: *TaskContext) void {
    _ = frame;
}

pub fn kill(frame: *TaskContext) void {
    _ = frame;
}

pub fn signalize(frame: *TaskContext) void {
    _ = frame;
}

pub fn wait(frame: *TaskContext) void {
    _ = frame;
}

pub fn set_priority(frame: *TaskContext) void {
    _ = frame;
}
