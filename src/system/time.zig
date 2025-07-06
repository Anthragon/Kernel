const std = @import("std");
const root = @import("root");
const sys = root.system;

const debug = root.debug;

pub const Date = struct {
    day: u8,
    month: u8,
    year: u32,

    pub fn format(s: *const @This(), comptime _: []const u8, _: std.fmt.FormatOptions, fmt: anytype) !void {
        fmt.write("{:0>4}-{:0>2}-{:0>2}", .{
            s.year, s.month, s.day
        });
    }
};

pub const Time = struct {
    seconds: u8,
    minutes: u8,
    hours: u8,

    pub fn format(s: *const @This(), comptime _: []const u8, _: std.fmt.FormatOptions, fmt: anytype) !void {
        fmt.write("{:0>2}:{:0>2}:{:0>2}", .{
            s.hours, s.minutes, s.seconds,
        });
    }
};

pub const DateTime = struct {
    // Date
    day: u8,
    month: u8,
    year: u32,

    // Time
    seconds: u8,
    minutes: u8,
    hours: u8,

    pub fn get_date(s: @This()) Date {
        return .{
            .day = s.day,
            .month = s.month,
            .year = s.year
        };
    }

    pub fn get_time(s: @This()) Time {
        return .{
            .seconds = s.seconds,
            .minutes = s.minutes,
            .hours = s.hours
        };
    }

    pub fn from_timestamp(ts: u64) DateTime {
        const spm = 60;
        const sph = 60 * spm;
        const spd = 24 * sph;

        var seconds = ts;

        const days_since_epoch = seconds / spd;
        seconds %= spd;

        const hour: u8 = @intCast(seconds / sph);
        seconds %= sph;

        const minute: u8 = @intCast(seconds / spm);
        const second: u8 = @intCast(seconds % spm);

        const date = epochDaysToDate(days_since_epoch);

        return DateTime{
            .year = date.year,
            .month = date.month,
            .day = date.day,
            .hours = hour,
            .minutes = minute,
            .seconds = second,
        };
    }
    fn epochDaysToDate(days: u64) struct { year: u32, month: u8, day: u8 } {
        var year: u32 = 1970;
        var _days: u64 = days;

        while (true) {
            const days_in_year: usize = if (isLeapYear(year)) 366 else 365;
            if (_days < days_in_year) break;
            _days -= days_in_year;
            year += 1;
        }

        const days_in_month = [_]u8{
            31, if (isLeapYear(year)) 29 else 28, 31, 30, 31, 30,
            31, 31, 30, 31, 30, 31
        };

        var month: u8 = 1;
        for (days_in_month, 0..) |dim, i| {
            if (_days < dim) {
                month = @intCast(i + 1);
                break;
            }
            _days -= dim;
        }

        const day: u8 = @intCast(_days + 1);

        return .{ .year = year, .month = month, .day = day };
    }
    fn isLeapYear(year: u32) bool {
        return (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0);
    }


    pub fn format(s: *const @This(), comptime _: []const u8, _: std.fmt.FormatOptions, fmt: anytype) !void {
        try fmt.print("{:0>2}:{:0>2}:{:0>2} {:0>4}-{:0>2}-{:0>2}", .{
            s.hours, s.minutes, s.seconds,
            s.year, s.month, s.day
        });
    }
};


const internal = switch (sys.arch) {
    .x86_64 => @import("x86_64/time.zig"),
    else => unreachable
};

var elapsed_ticks: usize = 0; 

pub const timestamp: fn () u64 = internal.timestamp;
pub const get_date: fn () Date = internal.get_date;
pub const get_time: fn () Time = internal.get_time;
pub const get_datetime: fn () DateTime = internal.get_datetime;

/// The elapsed ticks since the start of the
/// timer. Elapsed ticks should be in milisseconds,
/// but not trully guaranteed
pub fn get_elapsed_ticks() usize { return elapsed_ticks; }

pub fn init() void {
    root.debug.err("Initializing time service...\n", .{});

    // 0x20 = 32
    sys.interrupts.set_vector(0x20, timer_int, .kernel);
}

fn timer_int(f: *sys.TaskContext) void {

    elapsed_ticks += 1;
    
    // Check if timer conditions are reached
    // and execute

    if (elapsed_ticks % 3 == 0)
        root.threading.scheduler.do_schedule(f);

}
