const std = @import("std");
const sys = @import("system");
const root = @import("root");

const debug = root.debug;
const serial = debug.serial;

pub const options: std.Options = .{
    .page_size_min = sys.std_options.page_size_min,
    .page_size_max = sys.std_options.page_size_max,

    .enable_segfault_handler = false,

    .logFn = logFn,
    .cryptoRandomSeed = criptoRandomSeed,
    .crypto_always_getrandom = true,
};

pub fn logFn(
    comptime message_level: std.log.Level,
    comptime scope: @TypeOf(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    debug.print(
        message_level,
        scope,
        format,
        false,
        args,
    );
}

// TODO use system sensors for generating entropy
var step_entropy: usize = 0;
fn criptoRandomSeed(buffer: []u8) void {
    const timestamp = root.time.timestamp();
    const io_entropy = 0; //ports.inb(0x40);

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
