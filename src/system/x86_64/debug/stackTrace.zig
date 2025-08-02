const std = @import("std");
const pmm = @import("../mem/pmm.zig");

pub fn dumpStackTrace(frame_addr: usize, writer: anytype) void {

    var frame =  frame_addr;

    writer.print("<===addr===>\n", .{}) catch unreachable;

    // ignore first frame as it will refer to `root.panic()`
    frame = @as(*usize, @ptrFromInt(frame)).*;

    while (frame != 0) {
        const last_frame: usize = @as(*usize, @ptrFromInt(frame)).*;
        const return_ptr: usize = @as(*usize, @ptrFromInt(frame + 8)).*;

        writer.print("{X}\n", .{return_ptr}) catch unreachable;

        frame = last_frame;
    }

    writer.print("<===addr===/>\n", .{}) catch unreachable;

}
