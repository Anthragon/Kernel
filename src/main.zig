const std = @import("std");
pub const lib = @import("lib");
const BootInfo = boot.BootInfo;

/// Boot information structures
pub const boot = @import("boot/boot.zig");
/// System-dependent implementations and core subroutines
pub const system = @import("system/system.zig");
/// Memory and Memory-management related
pub const mem = @import("mem/mem.zig");
/// Simple CPU-based graphics library
pub const gl = @import("gl/gl.zig");
/// Galvan File System interface
pub const fs = @import("fs/fs.zig");
/// Devices management
pub const devices = @import("devices/devices.zig");
/// Users, authentication and permissions
pub const auth = @import("auth/auth.zig");
/// Processes, tasks and execution
pub const threading = @import("threading/threading.zig");
/// Modules and drivers management
pub const modules = @import("modules/modules.zig");
/// Capabilities system
pub const capabilities = @import("capabilities/capabilities.zig");
/// Debug helper script
pub const debug = @import("debug/debug.zig");

/// Utils and help scripts
pub const utils = lib.utils;
/// Interoperability help scripts
pub const interop = lib.interop;

/// Field that allow zig interfaces to comunicate
/// with the kernel. Do not mind.
pub const os = @import("os/os.zig");
/// Field that allow zig interfaces to comunicate
/// with the kernel. Do not mind.
pub const std_options = system.std_options.options;

const log = std.log.scoped(.main);

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
    log.info("\nHello, World from {s}!", .{ @tagName(system.arch) });
 
    // Initializing kernel services
    log.debug("\n# Initializing services", .{});

    capabilities.init(); // Capabilities must aways initialize first!

    fs.init();
    auth.init();   
    modules.init();
    devices.init();       
    threading.init();
    system.time.init();

    log.debug(" # All services ready!", .{});

    log.debug("# Registring adam process and task...", .{});
    // Setting up Adam process (process 0)
    const system_proc = threading.procman.get_process_from_pid(0).?;
    // Setting up Adam task
    // (It will override the stack being currently used)
    _ = system_proc.create_task(
        @import("adam.zig")._start,
        @as([*]u8, @ptrFromInt(std.mem.alignForward(
            usize,
            boot_info.kernel_stack_pointer_base,
            16
        )))[0 .. 0x1000],
        255
    ) catch unreachable;
    log.debug(" # Adam is ready!", .{});

    // Everything is ready, debug routine and them
    // start the scheduler
    log.info("\nDumping random data to see if everything is right:", .{});

    log.info("", .{});
    log.info("Time: {} ({})", .{ system.time.get_datetime(), system.time.timestamp() });
    log.info("", .{});
    auth.lsusers();
    log.info("", .{});
    threading.procman.lsproc();
    log.info("", .{});
    threading.procman.lstasks();

    log.info("\nSetup finished. Giving control to the scheduler...", .{});
    system.finalize() catch @panic("System initialization could not be finalized!");

    log.debug("# Giving control to the scheduer...", .{});
    while (true) system.assembly.flags.set_interrupt();
    unreachable;
}

/// Returns a copy of the information given by the
/// bootloader
pub inline fn get_boot_info() BootInfo {
    return boot_info;
}

/// General Out Of Memory panic \
/// In the future, maybe it can be used to do some
/// specific subroutine and allows to recover the
/// system execution. For now, it will just generate
/// a kernel panic.
pub fn oom_panic() noreturn {
    @panic("OOM");
}
var panicked: bool = false;
pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    if (panicked) {
        std.log.info("", .{});
        std.log.info("!--------------------------------------------------!", .{});
        std.log.info("!                   DOUBLE PANIC                   !", .{});
        std.log.info("!--------------------------------------------------!", .{});
        std.log.info("\nError: {s}\n", .{msg});
        system.assembly.halt();
    }

    panicked = true;

    std.log.info("", .{});
    std.log.info("!--------------------------------------------------!", .{});
    std.log.info("!                   KERNEL PANIC                   !", .{});
    std.log.info("!--------------------------------------------------!", .{});
    std.log.info("\nError: {s}\n", .{msg});

    var dalloc = mem.vmm.get_debug_allocator_controller();
    if (dalloc != null) {
        _ = dalloc.?.deinit();
    }

    std.log.info("\nStack Trace in stderr", .{});
    debug.dumpStackTrace(@frameAddress());

    panicked = false;
    system.assembly.halt();
}
