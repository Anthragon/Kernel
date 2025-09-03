const std = @import("std");
const root = @import("root");
const gl = root.basicgl;

const max_screen_width = 200;
const max_screen_height = 50;
var screen_buffer: [max_screen_width * max_screen_height]u8 = [_]u8{ 0 } ** (max_screen_width * max_screen_height);
var screenx: usize = 0;
var screeny: usize = 0;

pub const ScreenWriter = std.io.Writer(*anyopaque, error{}, screen_buffer_write);
pub inline fn swriter() ScreenWriter { return .{ .context = undefined }; }

pub fn redraw_screen() void {
    if (!gl.active) return;

    const sh = @min(max_screen_height, gl.grid_height);
    const sw = @min(max_screen_width, gl.grid_width);
    const mw = max_screen_width;

    for (0 .. sh) |i| {
        const line = std.mem.sliceAsBytes(&screen_buffer)[i * mw .. i * mw + sw];
        gl.draw_line(line, i);
    }
}

fn screen_buffer_write(_: *anyopaque, bytes: []const u8) !usize {
    var lines: isize = 0;
    for (bytes) |c| { if (c == '\n') lines += 1; }

    const sh: isize = @min(max_screen_height, gl.grid_height);
    push_lines_up(@max(0, lines - (sh - @as(isize, @bitCast(screeny)) )));

    const sb = std.mem.sliceAsBytes(&screen_buffer);

    for (bytes) |c| {
        switch (c) {
            '\n' => { screeny += 1; screenx = 0; },
            '\r' => screenx = 0,
            
            '\t' => { 
                const off = std.mem.alignForward(usize, screenx, 4) - screenx;
                for (0..off) |i| sb[screenx + i + screeny * max_screen_width] = ' ';
                screenx += off;
            },
            
            else => {
                sb[screenx + screeny * max_screen_width] = c;
                screenx += 1;
            }
        }
    }

    return bytes.len;
}

fn push_lines_up(offset: usize) void {
    if (offset == 0) return;

    //const sw: usize = @min(max_screen_width, gl.grid_width);
    const sh: usize = @min(max_screen_height, gl.grid_height);
    const mw = max_screen_width;

    const lines_to_copy = sh - offset;
    const dst = &screen_buffer;

    for (0..lines_to_copy) |i| {
        const src_off = (i + offset) * mw;
        const dst_off = i * mw;

        const blocks = mw / 16;
        asm volatile (
            \\ movq   %[blocks], %%rcx
            \\ movq   %[src], %%rsi
            \\ movq   %[dst], %%rdi
            \\ 1:
            \\   movdqu (%%rsi), %%xmm0
            \\   movdqu %%xmm0, (%%rdi)
            \\   addq   $16, %%rsi
            \\   addq   $16, %%rdi
            \\   decq   %%rcx
            \\   jne    1b
            :
            : [src] "r" (&dst[src_off]),
              [dst] "r" (&dst[dst_off]),
              [blocks] "r" (blocks)
            : "rcx","rsi","rdi","xmm0","memory","cc"
        );
    }

    for (0..offset) |j| {
        const off = (sh - offset + j) * mw;
        const blocks = mw / 16;

        asm volatile (
            \\ pxor %%xmm0, %%xmm0
            \\ movq %[blocks], %%rcx
            \\ movq %[dst], %%rdi
            \\ 1:
            \\   movdqu %%xmm0, (%%rdi)
            \\   addq   $16, %%rdi
            \\   decq   %%rcx
            \\   jne    1b
            :
            : [dst] "r" (&dst[off]),
              [blocks] "r" (blocks)
            : "rcx","rdi","xmm0","memory","cc"
        );
    }

    screeny -= offset + 1;
}
