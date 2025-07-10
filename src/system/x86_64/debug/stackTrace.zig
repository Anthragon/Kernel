const pmm = @import("../mem/pmm.zig");

pub fn dumpStackTrace(return_address: usize, writer: anytype) void {

    //var rbp: ?usize = return_address;
    //const kstart = pmm.kernel_page_start * 4096;
    //const kend = pmm.kernel_page_end * 4096;

    writer.print("<===addr===>\n", .{}) catch unreachable;

    writer.print("{X}\n", .{return_address}) catch unreachable;

    // while (rbp != null) {
    //     var i: usize = 0;

    //     const return_addr: usize = @as(*align(1) const usize, @ptrFromInt(rbp.? + @sizeOf(usize)*2)).*;
    //     const base_addr: usize =   @as(*align(1) const usize, @ptrFromInt(rbp.? + @sizeOf(usize)*1)).*;

    //     writer.print("{X} {X}\n", .{base_addr, return_addr}) catch unreachable;

    //     if (return_addr < kstart or return_addr > kend) break;
    //     rbp = base_addr;

    //     i += 1;
    //     if (i > 100) break;
    // }

    writer.print("<===addr===/>\n", .{}) catch unreachable;

}
