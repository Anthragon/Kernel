const std = @import("std");
const root = @import("root");
const threading = root.threading;
const auth = root.auth;
const allocator = root.mem.heap.kernel_buddy_allocator;

const log = std.log.scoped(.@"process man");

const debug = root.debug;

var proc_list: []?*Process = undefined;

const Process = threading.Process;

pub fn init() void {
    proc_list = allocator.alloc(?*threading.Process, 32) catch root.oom_panic();
    @memset(proc_list, null);

    // initializing process 0 (kernel process)
    const kproc = allocator.create(threading.Process) catch @panic("OOM");
    kproc.* = threading.Process{
        .process_id = 0,
        .name = "system",
        .tasks = &.{},
        .user = auth.get_user_by_index(0).?, // 0 = Adam
        .privilege = .kernel,
        .creation_timestamp = root.time.timestamp(),
    };
    proc_list[0] = kproc;
}

// TODO return here when the concept of process is
// implemented in the kernel
pub fn create_process(name: []const u8, user: *root.auth.User) !*Process {
    var proc = try allocator.create(threading.Process);
    errdefer allocator.destroy(proc);

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
    log.warn("lsproc", .{});
    log.info("Listing processes:", .{});

    for (proc_list) |proc| {
        if (proc) |p| {
            log.info("{: <2} - {s} - {s} (running by {s}) - {} tasks", .{
                p.process_id,
                p.name,
                @tagName(p.privilege),
                p.user.name,
                p.tasks.len,
            });
        }
    }
}
pub fn lstasks() void {
    log.warn("lstasks", .{});
    log.info("Listing tasks:", .{});

    for (proc_list) |proc| {
        if (proc) |p| {
            log.info("{: <2} - {s} - {s} (running by {s}) - {} tasks", .{
                p.process_id,
                p.name,
                @tagName(p.privilege),
                p.user.name,
                p.tasks.len,
            });

            for (p.tasks) |task| {
                if (task) |t| {
                    log.info("    {X:0>4}:{X:0>4} - {s} - created at {f}", .{
                        p.process_id,
                        t.task_id,
                        @tagName(t.state),
                        root.time.DateTime.from_timestamp(t.creation_timestamp),
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
