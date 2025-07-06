const std = @import("std");
const mem = std.mem;
const root = @import("root");
const system = root.system;

pub inline fn be2h(comptime T: type, v: T) T {
    return system.en2h(T, v, .little);
}

// constants
const FDT_MAGIC = 0xd00dfeed;
const FDT_BEGIN_NODE = 1;
const FDT_END_NODE = 2;
const FDT_PROP = 3;
const FDT_NOP = 4;
const FDT_END = 9;

// TODO not all fields in this structure
const Header = packed struct {
    magic: u32,
    totalsize: u32,
    off_dt_struct: u32,
    off_dt_strings: u32,
    off_mem_rsvmap: u32,
    version: u32,
    last_comp_version: u32,
};


pub fn parse_dtb(dtb: [*]const u8) !void {
    
    const header = mem.bytesAsValue(Header, dtb[0..@sizeOf(Header)]);

    if (be2h(u32, header.magic) != FDT_MAGIC) return error.InvalidDeviceTree;

    const struct_off = be2h(u32, header.off_dt_struct);
    const string_off = be2h(u32, header.off_dt_strings);

    _ = string_off;

    var pos = struct_off;
    while (true) : (pos += 4) {
        
        const token = mem.readInt(u32, dtb[pos..][0..4], .little);

        switch (token) {
            FDT_BEGIN_NODE => {

            },
            FDT_END_NODE => {

            },
            FDT_PROP => {

            },
            FDT_NOP => {

            },
            FDT_END => {

            },
            else => return error.InvalidDeviceTree
        }

    }

}
