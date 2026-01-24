const root = @import("root");
const system = @import("system");
const std = @import("std");
const builtin = @import("builtin");

const log = std.log.scoped(.no_header);

pub const serial = system.io.serial;
const tty_config: std.io.tty.Config = .no_color;

const stdout = 1;
const stderr = 2;

var locked_frame: usize = 0;

pub const gout = @import("gout.zig");

pub fn dumpStackTrace(ret_address: usize) void {
    const writer = serial.chardev(stderr);

    const real_ret_addr = if (locked_frame == 0) ret_address else locked_frame;

    if (builtin.strip_debug_info) {
        writer.print("Unable to dump stack trace: debug info stripped\n", .{}) catch unreachable;
        return;
    }

    writer.print("Stack trace:\n\n", .{}) catch unreachable;
    @import("system").debug.dumpStackTrace(real_ret_addr, writer);
}

pub fn dumpHex(bytes: []const u8) void {
    dumpHexInternal(bytes, tty_config, serial.chardev(stdout)) catch {};
}
pub fn dumpHexErr(bytes: []const u8) void {
    dumpHexInternal(bytes, tty_config, serial.chardev(stderr)) catch {};
}
pub fn dumpHexFailable(bytes: []const u8) !void {
    try dumpHexInternal(bytes, tty_config, serial.chardev(stdout));
}

/// Reimplementation of zig's `std.debug.dumpHexInternal`
fn dumpHexInternal(bytes: []const u8, ttyconf: std.io.tty.Config, writer: anytype) !void {
    var chunks = std.mem.window(u8, bytes, 16, 16);
    while (chunks.next()) |window| {
        const address = (@intFromPtr(bytes.ptr) + 0x10 * (std.math.divCeil(usize, chunks.index orelse bytes.len, 16) catch unreachable)) - 0x10;

        try ttyconf.setColor(writer, .dim);
        try writer.print("{x:0>[1]}  ", .{ address, @sizeOf(usize) * 2 });
        try ttyconf.setColor(writer, .reset);

        for (window, 0..) |byte, index| {
            try writer.print("{X:0>2} ", .{byte});
            if (index == 7) try writer.writeByte(' ');
        }
        try writer.writeByte(' ');
        if (window.len < 16) {
            var missing_columns = (16 - window.len) * 3;
            if (window.len < 8) missing_columns += 1;
            try writer.writeByteNTimes(' ', missing_columns);
        }

        for (window) |byte| {
            if (std.ascii.isPrint(byte)) try writer.writeByte(byte) else { // Not printable char

                if (ttyconf == .windows_api) {
                    try writer.writeByte('.');
                    continue;
                }

                switch (byte) {
                    '\n' => try writer.writeAll("␊"),
                    '\r' => try writer.writeAll("␍"),
                    '\t' => try writer.writeAll("␉"),
                    else => try writer.writeByte('.'),
                }
            }
        }

        try writer.writeByte('\n');
    }
}

pub inline fn lock_frame(frame: usize) void {
    locked_frame = frame;
}
pub inline fn unlock_frame() void {
    locked_frame = 0;
}

/// Prints to the stdout, stderr or screen console depending on
/// the message level
pub fn print(
    comptime message_level: std.log.Level,
    comptime scope: @TypeOf(.enum_literal),
    comptime format: []const u8,
    comptime headerless: bool,
    args: anytype,
) void {
    if (root.mem.heap.is_allocator_enabled()) {
        aloc_print(message_level, scope, format, headerless, args);
    } else {
        buf_print(message_level, scope, format, headerless, args);
    }
}

/// Allocator-free print version
pub fn buf_print(
    comptime message_level: std.log.Level,
    comptime scope: @TypeOf(.enum_literal),
    comptime format: []const u8,
    comptime headerless: bool,
    args: anytype,
) void {
    var content_buf: [2048]u8 = undefined;

    const content = std.fmt.bufPrint(&content_buf, format, args) catch b: {
        const msg = "...[too long]\n";
        @memcpy(content_buf[2048 - msg.len ..], msg);
        break :b &content_buf;
    };

    const header = std.fmt.comptimePrint(
        "[ {s: <15} {s: <5} ] ",
        .{ @tagName(scope), @tagName(message_level) },
    );

    const output1, const output2, const output3 = switch (message_level) {
        .info => .{ true, false, true },
        .warn, .debug => .{ false, true, true },
        .err => .{ true, true, true },
    };

    if (headerless) {
        write_log_message(output1, output2, output3, content);
        write_log_message(output1, output2, output3, "\n");
    } else {
        var lines = std.mem.splitAny(u8, content, "\n");
        var current_line = lines.next();
        while (current_line) |line| : (current_line = lines.next()) {
            if (!headerless) write_log_message(output1, output2, false, header);
            write_log_message(output1, output2, output3, line);
            write_log_message(output1, output2, output3, "\n");
        }
    }
    if (output3) gout.redraw_screen();
}

fn aloc_print(
    comptime message_level: std.log.Level,
    comptime scope: @TypeOf(.enum_literal),
    comptime format: []const u8,
    comptime headerless: bool,
    args: anytype,
) void {
    const gpa = root.mem.heap.kernel_buddy_allocator;
    const content = std.fmt.allocPrint(gpa, format, args) catch root.oom_panic();
    defer gpa.free(content);

    const header: []const u8 = std.fmt.comptimePrint(
        "[ {s: <15} {s: <5} ] ",
        .{ @tagName(scope), @tagName(message_level) },
    );

    const output1, const output2, const output3 = switch (message_level) {
        .info => .{ true, false, true },
        .warn, .debug => .{ false, true, true },
        .err => .{ true, true, true },
    };

    if (headerless) {
        write_log_message(output1, output2, output3, content);
        write_log_message(output1, output2, output3, "\n");
    } else {
        var lines = std.mem.splitAny(u8, content, "\n");
        var current_line = lines.next();
        while (current_line) |line| : (current_line = lines.next()) {
            if (!headerless) write_log_message(output1, output2, false, header);
            write_log_message(output1, output2, output3, line);
            write_log_message(output1, output2, output3, "\n");
        }
    }
    if (output3) gout.redraw_screen();
}

fn write_log_message(out: bool, err: bool, scr: bool, content: []const u8) void {
    if (out) serial.chardev(1).writeAll(content) catch unreachable;
    if (err) serial.chardev(2).writeAll(content) catch unreachable;
    if (scr) gout.swriter().writeAll(content) catch unreachable;
}
