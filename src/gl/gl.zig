const std = @import("std");
const root = @import("root");
const debug = root.debug;

var framebuffer: []Pixel = undefined;
var height: usize = 0;
var width: usize = 0;
var pps: usize = 0;

var font_width: usize = 0;
var font_height: usize = 0;

var char_height: usize = 0;
var char_width: usize = 0;

const clear_color = Pixel.rgb(0, 0, 100);
const fg_color = Pixel.rgb(200, 200, 200);
const bg_color = Pixel.rgb(80, 80, 100);

const font: [2][]const u8 = .{
    @embedFile("assets/bitfont.bf"),
    @embedFile("assets/monofont.bf"),
};
const Pixel = packed struct(u32) {
    blue: u8,
    green: u8,
    red: u8,
    _ignored: u8 = 0,

    pub fn rgb(r: u8, g: u8, b: u8) Pixel {
        return .{ .red = r, .green = g, .blue = b };
    }
};

pub fn init(fb: []u8, w: usize, h: usize, p: usize) void {
    framebuffer.ptr = @ptrCast(@alignCast(fb.ptr));
    framebuffer.len = fb.len / 4;

    _ = p;

    height = h;
    width = w;
    pps = framebuffer.len / height;

    font_width = std.mem.readInt(u32, font[0][0..4], .big);
    font_height = std.mem.readInt(u32, font[0][4..8], .big);

    char_width = @min(100, @divFloor(width - 60, font_width));
    char_height = @divFloor(height - 60, font_height);

    debug.print(
        \\
        \\Graphics library info:
        \\w:  {: >5} h:  {: >5} p:  {: >5}
        \\fx: {: >5} fy: {: >5}
        \\cw: {: >5} ch: {: >5}
        \\
    , .{ width, height, pps, font_width, font_height, char_width, char_height });
}

var char_x: usize = 0;
var char_y: usize = 0;
pub fn clear() void {
    const fbaslong = @as([*]u64, @ptrCast(@alignCast(framebuffer.ptr)))[0 .. framebuffer.len / 2];
    const ccaslong: u64 = (@as(u64, @intCast(@as(u32, @bitCast(clear_color)))) << 32) | @as(u32, @bitCast(clear_color));

    for (0..width / 2) |x| {
        for (0..height) |y| fbaslong[x + y * (pps / 2)] = ccaslong;
    }
    char_x = 0;
    char_y = 0;
}

pub fn draw_char(c: u8) void {
    if (char_x > char_width or char_y > char_height) return;

    const char_base = font[1][0x10 + (c * 2 * font_height) ..];

    const gx = char_x * font_width + 30;
    const gy = char_y * font_height + 30;

    for (0..font_height) |y| {
        const c_line = std.mem.readInt(u16, char_base[y * 2 ..][0..2], .big);

        for (0..font_width) |x| {
            framebuffer[gx + x + (gy + y) * pps] =
                if ((std.math.shr(u16, c_line, 16 - x) & 1) != 0) fg_color else bg_color;
        }
    }

    char_x += 1;
}
pub fn set_cursor_pos(x: usize, y: usize) void {
    char_x = x;
    char_y = y;
}
