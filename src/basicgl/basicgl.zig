const std = @import("std");
const root = @import("root");
const debug = root.debug;

var framebuffer: []Pixel = undefined;
var height: usize = 0;
var width: usize = 0;
var pps: usize = 0;

pub var active: bool = true;

const clear_color = Pixel.rgb(0, 0, 0);
const fg_color = Pixel.rgb(200, 200, 200);
const bg_color = Pixel.rgb(0, 0, 0);

const margin_h: usize = 8;
const margin_v: usize = 16;
pub var grid_width: usize = 0;
pub var grid_height: usize = 0;

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

    grid_width = @divFloor(width - margin_h * 2, font_width);
    grid_height = @divFloor(height - margin_v * 2, font_height);

    log.info(
        \\
        \\Graphics library info:
        \\w:  {: >5} h:  {: >5} p:  {: >5}
        \\fx: {: >5} fy: {: >5}
        \\gw: {: >5} gh: {: >5}
        \\
    , .{ width, height, pps, font_width, font_height, grid_width, grid_height });
}

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
            : [dst] "r" (fb_ptr),
              [blocks] "r" (blocks),
              [color] "r" (col),
            : .{ .rax = true, .rcx = true, .rdi = true, .xmm0 = true, .memory = true, .cc = true });
    }

    var start_tail: usize = blocks * 4;
    while (start_tail < len) : (start_tail += 1) fb_ptr[start_tail] = clear_color;
}
pub fn clear_line(line: usize) void {
    for (0..grid_width) |i| {
        clear_char(i, line);
    }
}

pub fn draw_line(str: []const u8, line: usize) void {
    if (line >= grid_height) return;

    var i: usize = 0;
    while (i < str.len and i < grid_width and str[i] != 0) : (i += 1)
        draw_char(str[i], i, line);

    while (i < grid_width) : (i += 1) clear_char(i, line);
}
pub fn draw_char(c: u8, posx: usize, posy: usize) void {
    if (posx > grid_width or posy > grid_height) return;

    const char_base = font[c * font_height ..];

    const gx = posx * font_width + font_width;
    const gy = posy * font_height + font_height;

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
            : [msk] "r" (c_line),
              [dst] "r" (dst_ptr),
              [cfg] "r" (fg_color),
              [cbg] "r" (bg_color),
            : .{ .rdi = true, .rsi = true, .memory = true, .cc = true });
    }
}
pub fn clear_char(posx: usize, posy: usize) void {
    if (posx > grid_width or posy > grid_height) return;

    const gx = posx * font_width + font_width;
    const gy = posy * font_height + font_height;

    for (0..font_height) |y| {
        const dst_index = gx + (gy + y) * pps;
        const dst_ptr: [*]Pixel = framebuffer[dst_index..].ptr;
        const blocks: usize = 2;

        asm volatile (
            \\ movl   %[color], %%eax        // coloca a cor em eax
            \\ movd   %%eax, %%xmm0          // move 32-bit para xmm0
            \\ pshufd $0x00, %%xmm0, %%xmm0 // duplica 4 bytes para 16 bytes
            \\ movq   %[blocks], %%rcx       // contador
            \\ movq   %[dst], %%rdi          // ponteiro de destino
            \\ 1:
            \\   movdqu %%xmm0, (%%rdi)      // escreve 16 bytes
            \\   addq   $16, %%rdi
            \\   decq %%rcx
            \\   jne 1b
            :
            : [dst] "r" (dst_ptr),
              [blocks] "r" (blocks),
              [color] "r" (bg_color),
            : .{ .rax = true, .rcx = true, .rdi = true, .xmm0 = true, .memory = true, .cc = true });
    }
}
