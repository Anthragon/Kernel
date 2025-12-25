const std = @import("std");
const root = @import("root");
const debug = root.debug;
const log = std.log.scoped(.@"syscalls 01");

const TaskContext = root.threading.TaskContext;

pub fn suicide(frame: *TaskContext) void {
    _ = frame;
}

pub fn get_task_id(frame: *TaskContext) void {
    _ = frame;
}

pub fn get_descriptor_kind(frame: *TaskContext) void {
    _ = frame;
}

pub fn heap_alloc(frame: *TaskContext) void {
    _ = frame;
}

pub fn heap_resize(frame: *TaskContext) void {
    _ = frame;
}

pub fn heap_remap(frame: *TaskContext) void {
    _ = frame;
}

pub fn heap_free(frame: *TaskContext) void {
    _ = frame;
}
