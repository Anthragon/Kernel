const std = @import("std");
const root = @import("root");

const acpi_tables = @import("acpi/tables.zig");
const Rsd = acpi_tables.Rsd;

const debug = root.debug;

pub fn init() void {

    const binfo = root.get_boot_info();
    const rsd_ptr = root.mem.ptrFromPhys(*align(1) Rsd, binfo.rsdp_physical);

    if (!std.mem.eql(u8, &rsd_ptr.signature, "RSD PTR ")) @panic("Invalid RSD signature!");

    //const table = rsd_ptr.get_root_table(); 

    // for (0..table.len()) |i| {
        
    //     const t = table.get_ptr(i);
    //     debug.print("{} - rev {} - {s} - checksum {}\n", .{i, t.header.revision, t.header.signature, t.header.do_checksum()});

    // }

}
