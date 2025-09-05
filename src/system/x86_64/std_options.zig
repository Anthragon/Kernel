const std = @import("std");
const root = @import("root");
const ports = @import("ports.zig");

const serial = root.system.serial;
const debug = root.debug;

pub const options: std.Options = .{
    .page_size_min = 4096,
    .page_size_max = 4096,

    .enable_segfault_handler = false,

    .logFn = logFn,
    .cryptoRandomSeed = criptoRandomSeed,
    .crypto_always_getrandom = true,
};

var last_scope: usize = 0;

fn logFn(
    comptime message_level: std.log.Level,
    comptime scope: @TypeOf(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    var content_buf: [2048]u8 = undefined;

    const content = std.fmt.bufPrint(&content_buf, format, args) catch b: {
        const msg = "...[too long]\n";
        @memcpy(content_buf[2048 - msg.len ..], msg);
        break :b &content_buf;
    };

    const header = std.fmt.comptimePrint("[ {s: <15} {s: <5} ] ", .{ @tagName(scope), @tagName(message_level) });

    const output1, const output2, const output3 = switch (message_level) {
        .info => .{ true, false, true },

        .warn, .debug => .{ false, true, true },

        .err => .{ true, true, true },
    };

    var lines = std.mem.splitAny(u8, content, "\n");

    var current_line = lines.next();
    while (current_line) |line| : (current_line = lines.next()) {
        write_log_message(output1, output2, false, header);
        write_log_message(output1, output2, output3, line);
        write_log_message(output1, output2, output3, "\n");
    }

    debug.gout.redraw_screen();
}

fn write_log_message(out: bool, err: bool, scr: bool, content: []const u8) void {
    if (out) serial.chardev(1).writeAll(content) catch unreachable;
    if (err) serial.chardev(2).writeAll(content) catch unreachable;
    if (scr) debug.gout.swriter().writeAll(content) catch unreachable;
}

// TODO use system sensors for generating entropy

var step_entropy: usize = 0;
fn criptoRandomSeed(buffer: []u8) void {
    const timestamp = root.system.time.timestamp();
    const io_entropy = ports.inb(0x40);

    var seed = timestamp ^ (@as(u64, io_entropy) << 56) ^ step_entropy;

    for (buffer, 0..) |*b, i| {
        seed ^= seed >> 12;
        seed ^= seed << 25;
        seed ^= seed >> 27;
        seed = seed *% 0x2545F4914F6CDD1D;

        b.* = @truncate(std.math.shr(usize, seed, (i & 7)));
    }

    step_entropy +%= seed;
}
