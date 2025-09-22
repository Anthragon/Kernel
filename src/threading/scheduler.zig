const std = @import("std");
const root = @import("root");
const sys = root.system;
const debug = root.debug;
const allocator = root.mem.heap.kernel_buddy_allocator;

const Task = root.threading.Task;
const TaskContext = sys.TaskContext;

var task_list: std.ArrayListUnmanaged(*Task) = undefined;
var current_task: ?*Task = null;
var next_index: usize = 0;

pub fn init() void {

}

pub fn append_task(t: *Task) void {
    task_list.append(allocator, t) catch root.oom_panic();
}

pub fn do_schedule(current_frame: *TaskContext) callconv(.c) void {

    if (current_task) |ct| ct.context = current_frame.*;

    if (next_index >= task_list.items.len) next_index = 0;

    current_task = task_list.items[next_index];
    current_frame.* = current_task.?.context;

    next_index += 1;

}
