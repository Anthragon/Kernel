const std = @import("std");
const BootInfo = boot.BootInfo;

/// Boot information structures
pub const boot = @import("boot/boot.zig");
/// System-dependent implementations and core subroutines
pub const system = @import("system/system.zig");
/// Memory and Memory-management related
pub const mem = @import("mem/mem.zig");
/// Tools for debugguing and simple I/O
pub const debug = @import("debug/debug.zig");
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
/// Utils and help scripts
pub const utils = @import("utils/utils.zig");

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
    debug.print("\nHello, World from {s}!\n", .{ @tagName(system.arch) });
 
    debug.err("# Initializing OS specific\n", .{});

    fs.init();
    auth.init();   
    devices.init();
    modules.init();         
    threading.init();
    system.time.init();

    // Setting up Adam
    const system_proc = threading.procman.get_process_from_pid(0).?;
    _ = system_proc.create_task(
        @import("adam.zig")._start,
        @as([*]u8, @ptrFromInt(boot_info.kernel_stack_pointer_base - 0x1000))[0..0x1000],
        255
    ) catch unreachable;

    // Everything is ready, debug routine and them
    // start the scheduler
    debug.print("\nDumping random data to see if everything is right:\n", .{});

    debug.print("Time: {} ({})\n", .{ system.time.get_datetime(), system.time.timestamp() });
    debug.print("\n", .{});
    //system.vmm.lsmemblocks();
    devices.pci.lspci();
    debug.print("\n", .{});
    auth.lsusers();
    debug.print("\n", .{});
    threading.procman.lsproc();
    debug.print("\n", .{});
    threading.procman.lstasks();
    debug.print("\n", .{});

    debug.print("\nSetup finished. Giving control to the scheduler...\n", .{});
    system.finalize() catch @panic("System initialization could not be finalized!");

    while (true) system.assembly.flags.set_interrupt();
    unreachable;
}

/// Returns a copy of information from the
/// bootloader
pub inline fn get_boot_info() BootInfo {
    return boot_info;
}

pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, return_address: ?usize) noreturn {

    debug.print("\n!!! KERNEL PANIC !!!\n", .{});
    debug.print("Error: {s}\n\n", .{msg});

    system.pmm.lsmemblocks();

    if (return_address) |ret| {
        debug.print("Stack Trace in stderr\n", .{});
        debug.err("Stack Trace:\n", .{});
        debug.dumpStackTrace(ret);
    } else {
        debug.print("No Stack Trace\n", .{});
    }

    system.assembly.halt();
}
