// TODO see a better place to put it (or not idk)
const root = @import("root");
const sys = root.system;
const interrupts = sys.interrupts;
const debug = root.debug;

const TaskContext = root.system.TaskContext;

pub fn install_interrupts() void {

    // Exceptions
    interrupts.set_vector(0x0, &division_error, .kernel);

    interrupts.set_vector(0x4, &overflow_error, .kernel);
    interrupts.set_vector(0x5, &bound_range_exceeded, .kernel);
    interrupts.set_vector(0x6, &invalid_opcode, .kernel);

    interrupts.set_vector(0x0d, &general_protection_fault, .kernel);
    interrupts.set_vector(0x0e, &page_fault, .kernel);

}

fn division_error(_: *TaskContext) void {
    debug.print("(#DE) Exception (see stderr)!\n", .{});
    debug.err("(#DE) Division Exception!\n", .{});
    debug.err("(#DE) An attempt to divide by 0 was made.\n", .{});
}
fn overflow_error(_: *TaskContext) void {
    debug.print("(#OF) Exception (see stderr)!\n", .{});
    debug.err("(#OF) Overflow Exception!\n", .{});
    debug.err("(#OF) INTO check failed.\n", .{});
}
fn bound_range_exceeded(_: *TaskContext) void {
    debug.print("(#BR) Exception (see stderr)!\n", .{});
    debug.err("(#BR) Bound Range Exceeded Exception!\n", .{});
    debug.err("(#BR) Index was out of bounds.\n", .{});
}
fn invalid_opcode(frame: *TaskContext) void {
    debug.print("(#UD) Exception (see stderr)!\n", .{});
    debug.err("(#UD) Invalid OpCode Exception!\n", .{});
    debug.err("(#UD) Attempted to execute an invalid opcode.\n", .{});

    // Shows system-dependent error messages here
    switch (sys.arch) {
        .x86_64 => {
            debug.err("(#UD) Fetched bytes: {X:0>2} {X:0>2} {X:0>2} {X:0>2}"
            , .{
                @as(*u8, @ptrFromInt(frame.rip)).*,
                @as(*u8, @ptrFromInt(frame.rip + 1)).*,
                @as(*u8, @ptrFromInt(frame.rip + 2)).*,
                @as(*u8, @ptrFromInt(frame.rip + 3)).*,
            });
        },
        else => unreachable
    }
}

fn double_fault(frame: *TaskContext) void {
    debug.print("(#DF) Exception (see stderr)!\n", .{});
    debug.err("(#DF) Double Fault Exception!\n", .{});
    debug.err("(#DF) The same exception happened two times.\n", .{});
    debug.err("(#DF) Dumping frame:\n", .{});
    debug.err("{}\n", .{ frame });
}

fn general_protection_fault(frame: *TaskContext) void {

    debug.print("(#GP) Exception (see stderr)!\n", .{});
    debug.err("(#GP) General Protection Exception!\n", .{});

    // Shows system-dependent error messages here
    switch (sys.arch) {
        .x86_64 => {
            const err: GeneralProtection_err_x86_64 = @bitCast(frame.error_code);

            debug.err("(#GP) Generated{s} when accessing index {} of the {s}\n", .{
                if (err.external) " externally" else "",
                err.index,
                switch (err.table) {
                    0b00 => "GDT",
                    0b10 => "LDT",
                    else => "IDT"
                }
            });
        },
        else => unreachable
    }
    
    debug.err("(#GP) Dumping frame:\n", .{});
    debug.err("{}\n", .{ frame });

    while (true) {}
}
fn page_fault(frame: *TaskContext) void {

    debug.print("(#PF) Exception (see stderr)!\n", .{});
    debug.err("(#PF) Page Fault Exception!\n", .{});

    // Shows system-dependent error messages here
    switch (sys.arch) {
        .x86_64 => {
            const err: PageFault_err_x86_64 = @bitCast(frame.error_code);

            debug.err(
                \\(#PF) error info:
                \\(#PF) -    page present:   {s}
                \\(#PF) -    access:         {s}
                \\(#PF) -    privilege:      {s}
                \\(#PF) -    rsvd write:     {s}
                \\(#PF) -    pkey violation: {s}  
                \\(#PF) -    shadow stack:   {s}
            , .{
                if (err.page_present) "YES" else "NO",
                @tagName(err.access),
                if (err.user_mode) "3" else "0",
                if (err.reserved_write) "YES" else "NO",
                if (err.protkey_violation) "YES" else "NO",
                if (err.shadow_stack) "YES" else "NO"
            });
        },
        else => unreachable
    }
    
    debug.err("\n(#PF) Dumping frame:\n", .{});
    debug.err("{}\n", .{ frame });

    while (true) {}
}


const GeneralProtection_err_x86_64 = packed struct (u64) {
    external: bool,
    table: u2,
    index: u13,
    _: u48
};
const PageFault_err_x86_64 = packed struct(u64) {
    page_present: bool,
    access: enum(u1) { read = 0, write = 1 },
    user_mode: bool,
    reserved_write: bool,
    instruction: bool,
    protkey_violation: bool,
    shadow_stack: bool,
    _: u57
};
