//! Time service \
//! Provides some methods to retrieve current time

const std = @import("std");
const root = @import("root");
const sys = root.system;

pub const Date = root.lib.common.time.Date;
pub const Time = root.lib.common.time.Time;
pub const DateTime = root.lib.common.time.DateTime;

const log = std.log.scoped(.time);

const debug = root.debug;

const internal = switch (sys.arch) {
    .x86_64 => @import("../system/x86_64/time.zig"),
    else => unreachable,
};

var elapsed_ticks: usize = 0;

// Secconds elapsed since january 1st, 1970
pub const timestamp: fn () u64 = internal.timestamp;
// Get current date
pub const get_date: fn () Date = internal.get_date;
// Get current time
pub const get_time: fn () Time = internal.get_time;
// Get current date and time
pub const get_datetime: fn () DateTime = internal.get_datetime;

/// The elapsed ticks since the start of the
/// timer. Elapsed ticks should be in milisseconds,
/// but not preciselly guaranteed
pub fn get_elapsed_ticks() usize {
    return elapsed_ticks;
}

pub fn init() void {
    log.debug(" ## Setting up time service...", .{});

    // This will handle the timer interrupt
    root.interrupts.set_vector(0x20, timer_int, .kernel);
}

/// Handles the timer interrupt
fn timer_int(f: *sys.TaskContext) void {
    elapsed_ticks += 1;

    // Check if timer conditions are reached
    // and execute

    // Scheduling tasks each 3 ticks (around 3 ms)
    if (elapsed_ticks % 3 == 0)
        root.threading.scheduler.do_schedule(f);
}
