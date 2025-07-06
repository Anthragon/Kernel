const std = @import("std");
const root = @import("root");
const threading = root.threading;
const modules = root.modules;

const debug = root.debug;

// Adam is a better term for the first father of all tasks
// than root was! - Terry A. Davis

const modahci = @import("elvaAHCI_module");

pub fn _start(args: ?*anyopaque) callconv(.c) noreturn {
    _ = args;

    debug.print("Hello, Adam!\n", .{});

    // Running the build-in core drivers

    // TODO implement loading modules list from 
    // build options
    _ = modules.register_module(
        modahci.module_name,
        modahci.module_version,
        modahci.module_author,
        modahci.module_liscence,

        modahci.init,
        modahci.deinit,
    );

    threading.procman.lstasks();
    modules.lsmodules();

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
