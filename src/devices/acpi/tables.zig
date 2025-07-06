const std = @import("std");
const root = @import("root");
const sys = root.system;
const pmm = sys.pmm;

const debug = root.debug;

pub const Rsd = extern struct {
    signature: [8]u8,
    checksum: u8,
    oem_id: [6]u8,
    revision: u8,
    rsdt_addr: u32, // deprecated since version 2.0

    length: u32,
    xsdt_addr: u64,
    ext_checksum: u8,
    _reserved_0: [3]u8,

    pub fn get_root_table(s: @This()) *Rsdt {
        const phys: usize = if (s.revision >= 2) s.xsdt_addr
        else @as(usize, @intCast(s.rsdt_addr));

        return pmm.ptrFromPhys(*Rsdt, phys);
    }

};

const SdtHeader = extern struct {

    signature: [4]u8,
    length: u32,
    revision: u8,
    checksum: u8,
    oem_id: [6]u8,
    oem_table_id: [8]u8,
    oem_revision: u32,
    creator_id: u32,
    creator_revision: u32,

    pub fn do_checksum(tableHeader: *const @This()) bool {

        const ptr = @as([*]u8, @ptrCast(@alignCast(@constCast(tableHeader))));
        const len = tableHeader.length;

        var sum: u8 = 0;
        for (0..len) |i| {
            sum +%= ptr[i];
        }
        return sum == 0;
    }
};

// Bruh for some reason the root uses a diferent
// logic
pub const Rsdt = struct {
    header: SdtHeader,
    entries: [0]u8,

    pub fn len(s: *@This()) usize {
        const b = s.header.length - @sizeOf(SdtHeader);
        return b / @as(usize, if (std.mem.eql(u8, &s.header.signature, "XSDT")) 8 else 4);
    }

    pub fn get_ptr(s: *@This(), index: usize) *const Sdt {
        if (index >= s.len()) @panic("Out of bounds");

        const ptr: [*]const u8 = @ptrCast(&s.entries);

        const v: usize = if (std.mem.eql(u8, &s.header.signature, "XSDT"))
            std.mem.readInt(u64, ptr[index * 8 ..][0..8], sys.endian)
        else 
            @intCast(std.mem.readInt(u32, ptr[index * 4 ..][0..4], sys.endian));

        return pmm.ptrFromPhys(*Sdt, v);
    }

    pub fn find_acpi_table(sdt: *const @This(), sig: [4]u8) ?*const Sdt {

        const count = sdt.len();
        for (0..count) |i| {

            const table = sdt.get_ptr(i);
            if (table.header.signature == sig) return table;

        }
        return null;
    }
};
pub const Sdt = struct {
    header: SdtHeader,
    entries: [0]u8,

    pub fn len(s: *@This()) usize {
        const b = s.header.length - @sizeOf(SdtHeader);
        return b / @as(usize, if (s.header.revision >= 2) 8 else 4);
    }

    pub fn get_ptr(s: *@This(), index: usize) *const Sdt {
        if (index >= s.len()) @panic("Out of bounds");

        const ptr: [*]const u8 = @ptrCast(&s.entries);

        const v: usize = if (s.header.revision >= 2)
            std.mem.readInt(u64, ptr[index * 8 ..][0..8], sys.endian)
        else 
            @intCast(std.mem.readInt(u32, ptr[index * 4 ..][0..4], sys.endian));

        return pmm.ptrFromPhys(*Sdt, v);
    }

    pub fn find_acpi_table(sdt: *const Sdt, sig: [4]u8) ?*const Sdt {

        const count = sdt.len();
        for (0..count) |i| {

            const table = sdt.get_ptr(i);
            if (table.header.signature == sig) return table;

        }
        return null;
    }
};
