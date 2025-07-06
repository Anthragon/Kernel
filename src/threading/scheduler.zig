const std = @import("std");
const root = @import("root");
const sys = root.system;
const debug = root.debug;
const allocator = root.mem.heap.kernel_buddy_allocator;

const Task = root.threading.Task;
const TaskContext = sys.TaskContext;
const TaskList = std.ArrayList(*Task);

var task_list: TaskList = undefined;
var current_task: ?*Task = null;
var next_index: usize = 0;

pub fn init() void {
    task_list = TaskList.init(allocator);
}

pub fn append_task(t: *Task) void {
    task_list.append(t) catch @panic("OOM");
    root.threading.procman.lstasks();
}

pub fn do_schedule(current_frame: *TaskContext) void {

    if (current_task) |ct| ct.context = current_frame.*;

    if (next_index >= task_list.items.len) next_index = 0;

    current_task = task_list.items[next_index];
    current_frame.* = current_task.?.context;

    next_index += 1;

}
