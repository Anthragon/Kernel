const root = @import("root");
const std = @import("std");
const builtin = @import("builtin");

pub const serial = root.system.serial;
const tty_config: std.io.tty.Config = .no_color;

const stdout = 0;
const stderr = 1;

const screen_width = 150;
const screen_height = 45;
var screen_buffer: [screen_width * screen_height]u8 = undefined;
var screenx: usize = 0;
var screeny: usize = 0;

pub inline fn print(comptime fmt: []const u8, args: anytype) void {
    serial.writer(stdout).print(fmt, args) catch |e| std.debug.panic("print error: {s}", .{@errorName(e)});
    swriter().print(fmt, args) catch |e| std.debug.panic("draw error: {s}", .{@errorName(e)});
    redraw_screen();
}
pub inline fn err(comptime fmt: []const u8, args: anytype) void {
    serial.writer(stderr).print(fmt, args) catch |e| std.debug.panic("print error: {s}", .{@errorName(e)});
}

pub fn dumpStackTrace(ret_address: usize) void {
    if (builtin.strip_debug_info) {
        err("Unable to dump stack trace: debug info stripped\n", .{});
        return;
    }

    const writer = serial.writer(stderr);

    // I hate my life
    switch (root.system.arch) {
        .x86_64 => @import("../system/x86_64/debug/stackTrace.zig").dumpStackTrace(ret_address, writer),
        else => unreachable,
    }
}

pub fn dumpHex(bytes: []const u8) void {
    dumpHexInternal(bytes, tty_config, serial.writer(stdout)) catch {};
    dumpHexInternal(bytes, tty_config, swriter()) catch {};
}
pub fn dumpHexFailable(bytes: []const u8) void {
    try dumpHexInternal(bytes, tty_config, serial.writer(stdout));
}

// Reimplementation of zig's `std.debug.dumpHexInternal`
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

// Screen things
pub const ScreenWriter = std.io.Writer(*anyopaque, error{}, screen_out);

inline fn swriter() ScreenWriter {
    return .{ .context = undefined };
}
fn screen_out(_: *anyopaque, bytes: []const u8) !usize {
    for (bytes) |e| {
        if (e == '\n') {
            screenx = 0;
            screeny += 1;
            if (screeny >= screen_height) push_lines_up();
        } else if (e == '\r') {
            screenx = 0;
        } else {
            screen_buffer[screenx + screeny * screen_width] = e;
            screenx += 1;
            if (screenx >= screen_width) {
                screenx = 0;
                screeny += 1;
                if (screeny >= screen_height) push_lines_up();
            }
        }
    }

    return bytes.len;
}
fn push_lines_up() void {
    for (0..screen_height - 1) |i|
        @memcpy(screen_buffer[i * screen_width .. i * screen_width + screen_width], screen_buffer[i * screen_width + screen_width .. i * screen_width + screen_width * 2]);
    @memset(screen_buffer[(screen_height - 1) * screen_width .. screen_height * screen_width], 0);
    screeny -= 1;
}
fn redraw_screen() void {
    const gl = root.gl;

    for (0..screen_height) |y| {
        gl.set_cursor_pos(0, y);

        var x: usize = 0;
        while (x < screen_width) : (x += 1) {
            const c = screen_buffer[x + y * screen_width];
            if (c == 0) break;
            gl.draw_char(c);
        }
        while (x < screen_width) : (x += 1) gl.draw_char(' ');
    }
}
