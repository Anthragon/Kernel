const std = @import("std");
const root = @import("root");
const gl = root.basicgl;

const max_screen_width = 200;
const max_screen_height = 50;
var screen_buffer: [max_screen_width * max_screen_height]u8 = [_]u8{0} ** (max_screen_width * max_screen_height);
var screenx: usize = 0;
var screeny: usize = 0;

var screen_writer: std.io.Writer = .{
    .buffer = &.{},
    .end = 0,
    .vtable = &.{ .drain = screen_buffer_drain },
};

pub fn swriter() *std.io.Writer {
    return &screen_writer;
}

pub fn redraw_screen() void {
    if (!gl.active) return;

    const sh = @min(max_screen_height, gl.grid_height);
    const sw = @min(max_screen_width, gl.grid_width);
    const mw = max_screen_width;

    for (0..sh) |i| {
        const line = std.mem.sliceAsBytes(&screen_buffer)[i * mw .. i * mw + sw];
        gl.draw_line(line, i);
    }
}

fn screen_buffer_drain(_: *std.io.Writer, data: []const []const u8, splen: usize) !usize {
    _ = splen;

    var count: usize = 0;
    for (data) |bytes| {
        screen_buffer_write(bytes);
        count += bytes.len;
    }

    return count;
}
fn screen_buffer_write(bytes: []const u8) void {
    var lines: isize = 1;
    for (bytes) |c| {
        if (c == '\n') lines += 1;
    }

    const sh: isize = @min(max_screen_height, gl.grid_height);
    push_lines_up(@max(0, lines - (sh - @as(isize, @bitCast(screeny)))));

    const sb = std.mem.sliceAsBytes(&screen_buffer);

    for (bytes) |c| {
        switch (c) {
            '\n' => {
                screeny += 1;
                screenx = 0;
            },
            '\r' => screenx = 0,

            '\t' => {
                const off = std.mem.alignForward(usize, screenx, 4) - screenx;
                for (0..off) |i| sb[screenx + i + screeny * max_screen_width] = ' ';
                screenx += off;
            },

            else => {
                sb[screenx + screeny * max_screen_width] = c;
                screenx += 1;
            },
        }
    }
}

fn push_lines_up(offset: usize) void {
    if (offset == 0) return;

    const sh: usize = @min(max_screen_height, gl.grid_height);
    const mw = max_screen_width;

    const lines_to_copy = sh - offset + 1;
    const dst = &screen_buffer;

    for (0..lines_to_copy) |i| {
        const src_off = (i + offset) * mw;
        const dst_off = i * mw;

        const src_slice = dst[src_off .. src_off + mw];
        const dst_slice = dst[dst_off .. dst_off + mw];

        @memcpy(dst_slice, src_slice);
    }

    for (0..offset + 1) |j| {
        const off = (sh - offset + j) * mw;
        const slice = dst[off .. off + mw];

        @memset(slice, 0);
    }

    screeny -= offset;
}
