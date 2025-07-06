const std = @import("std");
const root = @import("root");
const threading = root.threading;
const auth = root.auth;
const allocator = root.mem.heap.kernel_buddy_allocator;

const debug = root.debug;

var proc_list: []?*Process = undefined;

const Process = threading.Process;

pub fn init() void {

    proc_list = allocator.alloc(?*threading.Process, 32) catch {
        debug.print("Failed to allocate process list\n", .{});
        @panic("OOM");
    };
    @memset(proc_list, null);

    // setting the process 0 (kernel process)
    const kproc = allocator.create(threading.Process) catch @panic("OOM");
    kproc.* = threading.Process{
        .process_id = 0,
        .name = "kernel",
        .tasks = &.{},
        .user = auth.get_user_by_index(0).?, // 0 = Adam
        .privilege = .kernel,
        .creation_timestamp = root.system.time.timestamp(),
    };
    proc_list[0] = kproc;

}

// TODO return here when the concept of process is
// implemented in the kernel
pub fn create_process(name: []const u8, user: *root.auth.User) !*Process {
    var proc = try allocator.create(threading.Process);

    proc.* = .{
        .process_id = 0,
        .name = name,
        .tasks = &.{},
        .priority = 0,
        .user = user,
    };

    // Find an empty slot in the process list
    // and store the new process
    while (true) {
        for (1..proc_list.len) |i| {
            if (proc_list[i] == null) {
                proc.process_id = @intCast(i);
                proc_list[i] = proc;
                return proc;
            }
        }
        // If no process slot is available,
        // enlarge the process list
        enlarge_process_list();
    }
}
pub fn get_process_from_pid(pid: usize) ?*Process {
    if (pid > proc_list.len) return null;
    return proc_list[pid];
}

pub fn lsproc() void {
    debug.print("Listing processes:\n", .{});

    for (proc_list) |proc| {
        if (proc) |p| {
            debug.print("{: <2} - {s} (running by {s})\n", .{
                p.process_id,
                p.name,
                p.user.name,
            });
        }
    }

}
pub fn lstasks() void {
    debug.print("Listing tasks:\n", .{});

    for (proc_list) |proc| {
        if (proc) |p| {
            
            for (p.tasks) |task| {
                if (task) |t| {

                    debug.print("{X:0>4}:{X:0>4} - {s} - created at {}\n", .{
                        p.process_id,
                        t.task_id,
                        @tagName(t.state),
                        root.system.time.DateTime.from_timestamp(t.creation_timestamp),
                    });

                }
            }

        }
    }
}

fn enlarge_process_list() !void {
    const new_size = proc_list.len + proc_list.len / 2;
    const new_list = try allocator.alloc(?*threading.Process, new_size);
    @memcpy(new_list[0..proc_list.len], proc_list[0..proc_list.len]);
    @memset(new_list[proc_list.len..new_size], null);
    allocator.free(proc_list);
    proc_list = new_list;
}
