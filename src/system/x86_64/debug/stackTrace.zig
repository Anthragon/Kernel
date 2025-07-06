const pmm = @import("../mem/pmm.zig");

pub fn dumpStackTrace(return_address: usize, writer: anytype) void {

    var rbp: ?usize = return_address;
    const kstart = pmm.kernel_page_start * 4096;
    const kend = pmm.kernel_page_end * 4096;

    writer.print("<===addr===>\n", .{}) catch unreachable;

    while (rbp != null) {
        const raddr = rbp.?;
        var i: usize = 0;

        writer.print("{X}\n", .{raddr}) catch unreachable;

        const return_addr_ptr: *align(1) const usize = @ptrFromInt(rbp.? + @sizeOf(usize));
        const return_addr = return_addr_ptr.*;

        if (return_addr < kstart or return_addr > kend) break;
        rbp = return_addr;

        i += 1;
        if (i > 100) break;
    }

    writer.print("<===addr===/>\n", .{}) catch unreachable;

}
