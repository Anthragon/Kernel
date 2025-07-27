const std = @import("std");
const root = @import("root");
const threading = root.threading;
const modules = root.modules;

const debug = root.debug;
const log = std.log.scoped(.adam);

// Adam is a better term for the first father of all tasks
// than root was! - Terry A. Davis

const builtin_modules = .{
    @import("elvaAHCI_module"),
    @import("elvaDisk_module"),
    @import("elvaFAT_module"),
};

pub fn _start(args: ?*anyopaque) callconv(.c) noreturn {
    _ = args;

    log.info("\nHello, Adam!", .{});

    // Running the build-in core drivers

    // TODO implement loading modules list from 
    // build options

    inline for (builtin_modules) |mod| {
        _ = modules.register_module(
            mod.module_name,
            mod.module_version,
            mod.module_author,
            mod.module_liscence,
            mod.module_uuid,

            mod.init,
            mod.deinit,
        );
    }

    log.info("{} built in modules registred!", .{ builtin_modules.len });

    threading.procman.lstasks();
    modules.lsmodules();

    log.info("Entering in sleep mode... zzz\n", .{});

    // Adam should never return as it indicates
    // that the system is alive
    // TODO implement a proper sleep function
    // that will allow the system to enter a low power state
    // and wake up on an event
    while (true) {

        if (modules.has_waiting_modules()) {
            const module = modules.get_next_waiting_module().?;
            log.info("Initializing module {s}...", .{module.name});

            const res = module.init();

            if (res) {
                log.debug("Module {s} initialized successfully!", .{module.name});
                module.status = .Active;
            } else {
                log.debug("Module {s} failed to initialize!", .{module.name});
                module.status = .Failed;
            }
            
            log.info("Initialization done; Module {s} status: {s}", .{module.name, @tagName(module.status)});
        }

    }
    unreachable;
}
