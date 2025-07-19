const std = @import("std");
const BootInfo = boot.BootInfo;

/// Boot information structures
pub const boot = @import("boot/boot.zig");
/// System-dependent implementations and core subroutines
pub const system = @import("system/system.zig");
/// Memory and Memory-management related
pub const mem = @import("mem/mem.zig");
/// Simple CPU-based graphics library
pub const gl = @import("gl/gl.zig");
/// SystemElva File System interface
pub const fs = @import("fs/fs.zig");
/// Devices management
pub const devices = @import("devices/devices.zig");
/// Users, authentication and permissions
pub const auth = @import("auth/auth.zig");
/// Processes, tasks and execution
pub const threading = @import("threading/threading.zig");
/// Modules and drivers management
pub const modules = @import("modules/modules.zig");

/// Debug helper script
pub const debug = @import("debug/debug.zig");
/// Utils and help scripts
pub const utils = @import("utils/utils.zig");
/// Interoperability help scripts
pub const interop = @import("interop/interop.zig");

/// Field that allow zig interfaces to comunicate
/// with the kernel. Do not mind.
pub const os = @import("os/os.zig");
/// Field that allow zig interfaces to comunicate
/// with the kernel. Do not mind.
pub const std_options = system.std_options.options;

var boot_info: BootInfo = undefined;

// linking entry point symbol
comptime { _ = @import("boot/limine/entry.zig"); }

pub fn main(_boot_info: BootInfo) noreturn {
    boot_info = _boot_info;
    system.assembly.flags.clear_interrupt();

    // Setting up graphics
    gl.init(
        boot_info.framebuffer.framebuffer,
        boot_info.framebuffer.width,
        boot_info.framebuffer.height,
        boot_info.framebuffer.pps
    );
    gl.clear();


    // Setupping system-dependant resources
    system.init() catch { @panic("System could not be initialized!"); };
    // Setting up Virtual memory manager
    system.vmm.init();

    // Setting up interrupts
    @import("interrupts.zig").install_interrupts();

    // Printing hello world
    std.log.info("\nHello, World from {s}!\n", .{ @tagName(system.arch) });
 
    std.log.debug("\n# Initializing OS specific\n", .{});

    modules.init();

    fs.init();
    auth.init();   
    devices.init();       
    threading.init();
    system.time.init();
    std.log.debug(" # All services ready!\n", .{});

    // Setting up Adam
    std.log.debug("# Registring adam process and task...\n", .{});
    const system_proc = threading.procman.get_process_from_pid(0).?;
    _ = system_proc.create_task(
        @import("adam.zig")._start,
        @as([*]u8, @ptrFromInt(boot_info.kernel_stack_pointer_base - 0x1000))[0..0x1000],
        255
    ) catch unreachable;
    std.log.debug(" # Adam is ready!\n", .{});

    // Everything is ready, debug routine and them
    // start the scheduler
    std.log.info("\nDumping random data to see if everything is right:\n", .{});

    std.log.info("\n", .{});
    std.log.info("Time: {} ({})\n", .{ system.time.get_datetime(), system.time.timestamp() });
    std.log.info("\n", .{});
    devices.pci.lspci();
    std.log.info("\n", .{});
    auth.lsusers();
    std.log.info("\n", .{});
    threading.procman.lsproc();
    std.log.info("\n", .{});
    threading.procman.lstasks();

    std.log.info("\nSetup finished. Giving control to the scheduler...\n", .{});
    system.finalize() catch @panic("System initialization could not be finalized!");

    std.log.debug("Testing a thing...", .{});
    std.log.info("Testing a thing...", .{});
    std.log.debug("Testing a thing...", .{});
    std.log.warn("Testing a thing...", .{});

    std.log.debug("# Giving control to the scheduer...\n", .{});
    while (true) system.assembly.flags.set_interrupt();
    unreachable;
}

/// Returns a copy of the information given by the
/// bootloader
pub inline fn get_boot_info() BootInfo {
    return boot_info;
}

var panicked: bool = false;
pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, return_address: ?usize) noreturn {
    if (panicked) {
        std.log.info("\n", .{});
        std.log.info("!--------------------------------------------------!\n", .{});
        std.log.info("!                   DOUBLE PANIC                   !\n", .{});
        std.log.info("!--------------------------------------------------!\n", .{});
        std.log.info("\nError: {s}\n\n", .{msg});
        system.assembly.halt();
    }

    panicked = true;

    std.log.info("\n", .{});
    std.log.info("!--------------------------------------------------!\n", .{});
    std.log.info("!                   KERNEL PANIC                   !\n", .{});
    std.log.info("!--------------------------------------------------!\n", .{});
    std.log.info("\nError: {s}\n\n", .{msg});

    var dalloc = mem.vmm.get_debug_allocator_controller();
    if (dalloc != null) {
        _ = dalloc.?.deinit();
    }

    if (return_address) |ret| {

        std.log.info("\nStack Trace in stderr\n", .{});
        std.log.debug("\nStack Trace:\n", .{});
        _ = ret;//debug.dumpStackTrace(ret);

    } else {
        std.log.info("No Stack Trace\n", .{});
    }

    panicked = false;
    system.assembly.halt();
}
