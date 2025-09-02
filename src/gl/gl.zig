const std = @import("std");
const root = @import("root");
const debug = root.debug;

var framebuffer: []Pixel = undefined;
var height: usize = 0;
var width: usize = 0;
var pps: usize = 0;

pub var char_height: usize = 0;
pub var char_width: usize = 0;

const clear_color = Pixel.rgb(0, 0, 0);
const fg_color = Pixel.rgb(200, 200, 200);
const bg_color = Pixel.rgb(0, 0, 0);

const Pixel = packed struct(u32) {
    blue: u8,
    green: u8,
    red: u8,
    _ignored: u8 = 0,

    pub fn rgb(r: u8, g: u8, b: u8) Pixel {
        return .{ .red = r, .green = g, .blue = b };
    }
};
const font: []const u8 = @embedFile("assets/FATSCII.F16");
const font_width: usize = 8;
const font_height: usize = 16;

const log = std.log.scoped(.gl);

pub fn init(fb: []u8, w: usize, h: usize, p: usize) void {
    framebuffer.ptr = @ptrCast(@alignCast(fb.ptr));
    framebuffer.len = fb.len / 4;

    _ = p;

    height = h;
    width = w;
    pps = framebuffer.len / height;

    char_width = @min(200, @divFloor(width - font_width*2, font_width));
    char_height = @min(50, @divFloor(height - font_height*2, font_height));

    log.info(
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
    const fb_ptr = framebuffer.ptr;
    const len: usize = framebuffer.len;

    const blocks: usize = len / 4;
    const col: u32 = @bitCast(clear_color);

    if (blocks != 0) {
        asm volatile (
            \\ movl   %[color], %eax
            \\ movd   %eax, %xmm0
            \\ pshufd $0x00, %xmm0, %xmm0
            \\ movq   %[blocks], %rcx
            \\ movq   %[dst], %rdi
            \\ 1:
            \\   movdqu %xmm0, (%rdi)
            \\   addq   $16, %rdi
            \\   decq   %rcx
            \\   jne    1b
            :
            : [dst]  "r" (fb_ptr),
              [blocks] "r" (blocks),
              [color] "r" (col)
            : "rax","rcx","rdi","xmm0","memory","cc"
        );
    }

    var start_tail: usize = blocks * 4;
    while (start_tail < len) : (start_tail += 1) fb_ptr[start_tail] = clear_color;

    char_x = 0;
    char_y = 0;
}

pub fn draw_char(c: u8) void {
    if (char_x > char_width or char_y > char_height) return;

    const char_base = font[c  * font_height ..];

    const gx = char_x * font_width + font_width;
    const gy = char_y * font_height + font_height;

    for (0..font_height) |y| {
        const c_line: u8 = char_base[y];

        const dst_index = gx + (gy + y) * pps;
        const dst_ptr: [*]Pixel = framebuffer[dst_index..].ptr;

        asm volatile (
            \\ testb   $0x80,   %[msk]
            \\ cmovnz  %[cfg],  %edi        # if bit=1: [dst] = cfg
            \\ cmovz   %[cbg],  %edi        # else:     [dst] = cbg
            \\ movl    %edi,   (%[dst])
            \\ addq    $4,     %[dst]
            \\
            \\ testb   $0x40,   %[msk]
            \\ cmovnz  %[cfg],  %edi
            \\ cmovz   %[cbg],  %edi
            \\ movl    %edi,   (%[dst])
            \\ addq    $4,     %[dst]
            \\
            \\ testb   $0x20,   %[msk]
            \\ cmovnz  %[cfg],  %edi
            \\ cmovz   %[cbg],  %edi
            \\ movl    %edi,   (%[dst])
            \\ addq    $4,     %[dst]
            \\
            \\ testb   $0x10,   %[msk]
            \\ cmovnz  %[cfg],  %edi
            \\ cmovz   %[cbg],  %edi
            \\ movl    %edi,   (%[dst])
            \\ addq    $4,     %[dst]
            \\
            \\ testb   $0x08,   %[msk]
            \\ cmovnz  %[cfg],  %edi
            \\ cmovz   %[cbg],  %edi
            \\ movl    %edi,   (%[dst])
            \\ addq    $4,     %[dst]
            \\
            \\ testb   $0x04,   %[msk]
            \\ cmovnz  %[cfg],  %edi
            \\ cmovz   %[cbg],  %edi
            \\ movl    %edi,   (%[dst])
            \\ addq    $4,     %[dst]
            \\
            \\ testb   $0x02,   %[msk]
            \\ cmovnz  %[cfg],  %edi
            \\ cmovz   %[cbg],  %edi
            \\ movl    %edi,   (%[dst])
            \\ addq    $4,     %[dst]
            \\
            \\ testb   $0x01,   %[msk]
            \\ cmovnz  %[cfg],  %edi
            \\ cmovz   %[cbg],  %edi
            \\ movl    %edi,   (%[dst])
            \\ addq    $4,     %[dst]
            :
            :
                [msk] "r" (c_line),
                [dst] "r" (dst_ptr),
                [cfg] "r" (fg_color),
                [cbg] "r" (bg_color),
            : "rdi","rsi","memory","cc"
        );
    }

    char_x += 1;
}

pub inline fn set_cursor_pos(x: usize, y: usize) void {
    char_x = x;
    char_y = y;
}
