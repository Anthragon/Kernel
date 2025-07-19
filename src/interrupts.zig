// TODO see a better place to put it (or not idk)
const std = @import("std");
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

    interrupts.set_vector(0x8, &double_fault, .kernel);

    interrupts.set_vector(0x0d, &general_protection_fault, .kernel);
    interrupts.set_vector(0x0e, &page_fault, .kernel);

}

fn division_error(frame: *TaskContext) void {
    std.log.debug("\n(#DE) Division Exception!\n", .{});
    std.log.debug("(#DE) An attempt to divide by 0 was made.\n", .{});

    root.panic("Division Error", null, frame.get_instruction_ptr());
}
fn overflow_error(frame: *TaskContext) void {
    std.log.debug("\n(#OF) Overflow Exception!\n", .{});
    std.log.debug("(#OF) INTO check failed.\n", .{});

    root.panic("Overflow Error", null, frame.get_instruction_ptr());
}
fn bound_range_exceeded(frame: *TaskContext) void {
    std.log.debug("\n(#BR) Bound Range Exceeded Exception!\n", .{});
    std.log.debug("(#BR) Index was out of bounds.\n", .{});

    root.panic("Bound Range Exceeded", null, frame.get_instruction_ptr());
}
fn invalid_opcode(frame: *TaskContext) void {
    std.log.debug("\n(#UD) Invalid OpCode Exception!\n", .{});
    std.log.debug("(#UD) Attempted to execute an invalid opcode.\n", .{});

    // Shows system-dependent error messages here
    switch (sys.arch) {
        .x86_64 => {
            std.log.debug("(#UD) Fetched bytes: {X:0>2} {X:0>2} {X:0>2} {X:0>2}"
            , .{
                @as(*u8, @ptrFromInt(frame.rip)).*,
                @as(*u8, @ptrFromInt(frame.rip + 1)).*,
                @as(*u8, @ptrFromInt(frame.rip + 2)).*,
                @as(*u8, @ptrFromInt(frame.rip + 3)).*,
            });
        },
        else => unreachable
    }

    root.panic("Invalid OpCode", null, frame.get_instruction_ptr());
}

fn double_fault(frame: *TaskContext) void {
    std.log.debug("(#DF) The same exception happened two times.\n", .{});

    std.log.debug("\n(#DF) Dumping frame:\n", .{});
    std.log.debug("{}\n", .{ frame });

    root.panic("Double fault", null, frame.get_instruction_ptr());
    sys.assembly.halt();
}

fn general_protection_fault(frame: *TaskContext) void {

    std.log.debug("\n(#GP) General Protection Exception!\n", .{});

    // Shows system-dependent error messages here
    switch (sys.arch) {
        .x86_64 => {
            const err: GeneralProtection_err_x86_64 = @bitCast(frame.error_code);

            std.log.debug("(#GP) Generated{s} when accessing index {} of the {s}\n", .{
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
    
    std.log.debug("(#GP) Dumping frame:\n", .{});
    std.log.debug("{}\n", .{ frame });

    root.panic("General Protection fault", null, frame.get_instruction_ptr());
    sys.assembly.halt();
}
fn page_fault(frame: *TaskContext) void {

    std.log.debug("\n(#PF) Page Fault Exception!\n", .{});

    // Shows system-dependent error messages here
    switch (sys.arch) {
        .x86_64 => {
            const err: PageFault_err_x86_64 = @bitCast(frame.error_code);

            std.log.debug(
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
    
    std.log.debug("\n(#PF) Dumping frame:\n", .{});
    std.log.debug("{}\n", .{ frame });

    root.panic("Page fault", null, frame.get_instruction_ptr());
    sys.assembly.halt();
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
