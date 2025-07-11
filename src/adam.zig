const std = @import("std");
const root = @import("root");
const threading = root.threading;
const modules = root.modules;

const debug = root.debug;

// Adam is a better term for the first father of all tasks
// than root was! - Terry A. Davis

const builtin_modules = .{
    @import("elvaAHCI_module"),
    @import("elvaDisk_module"),
    @import("elvaFAT_module"),
};

pub fn _start(args: ?*anyopaque) callconv(.c) noreturn {
    _ = args;

    debug.print("\nHello, Adam!\n", .{});

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

    debug.print("{} built in modules registred!\n", .{ builtin_modules.len });

    threading.procman.lstasks();
    modules.lsmodules();

    debug.print("Entering in sleep mode... zzz\n\n", .{});

    // Adam should never return as it indicates
    // that the system is alive
    // TODO implement a proper sleep function
    // that will allow the system to enter a low power state
    // and wake up on an event
    while (true) {

        if (modules.has_waiting_modules()) {
            const module = modules.get_next_waiting_module().?;
            debug.print("Initializing module {s}...\n", .{module.name});

            const res = module.init();

            if (res) {
                debug.err("Module {s} initialized successfully!\n", .{module.name});
                module.status = .Active;
            } else {
                debug.err("Module {s} failed to initialize!\n", .{module.name});
                module.status = .Failed;
            }
            
            debug.print("Initialization done; Module {s} status: {s}\n", .{module.name, @tagName(module.status)});
        }

    }
    unreachable;
}
