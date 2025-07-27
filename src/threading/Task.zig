// Implementation of the task's context and extra
// information that should not be shared by the process

// This structure should only indicate a single task, an asyncronous
// procedure in execution. Each task represents a CPU state and is
// schedued to do multitasking.

const std = @import("std");
const root = @import("root");
const threading = root.threading;

task_id: u32,
priority: u8,
state: TaskState,
context: root.system.TaskContext,
process: *threading.Process,
creation_timestamp: u64,

// Cleanup data
stack: []u8 = undefined,
free_stack: bool = true,


pub const TaskState = enum(u8) {
    Running,
    Ready,
    Waiting,
    Terminated,
};

pub fn format(self: *const @This(), comptime _: []const u8, _: std.fmt.FormatOptions, fmt: anytype) !void {

    try fmt.print("process {s} ({}) task {} - priority {} - {s}", .{
        self.process.name, self.process.process_id, self.task_id, self.priority, @tagName(self.state) });
        
    try fmt.print("privilege: {}", .{ self.process.privilege });
    try fmt.print("created at: {}", .{ self.creation_timestamp });

    try fmt.print("context:\n{}", .{ self.context });
    

}
