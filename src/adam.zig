const std = @import("std");
const root = @import("root");
const lib = @import("lib");
const threading = root.threading;
const modules = root.modules;

const debug = root.debug;
const log = std.log.scoped(.adam);

const allocator = root.mem.heap.kernel_buddy_allocator;

// Adam is a better term for the first father of all tasks
// than root was! - Terry A. Davis

const builtin_modules = .{
    @import("lumiPCI_module"),
    @import("lumiDisk_module"),
    @import("lumiAHCI_module"),
    @import("lumiFAT_module"),
};

pub fn _start(args: ?*anyopaque) callconv(.c) noreturn {
    _ = args;

    const boot_info = root.get_boot_info();

    log.info("\nHello, Adam!", .{});

    // Running the build-in core drivers

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

    log.info("{} built in modules registred!", .{builtin_modules.len});
    log.info("initializing {} build in modules...", .{builtin_modules.len});

    while (modules.has_waiting_modules()) {
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

        log.info("Initialization done; Module {s} status: {s}", .{ module.name, @tagName(module.status) });
    }

    log.info("Mounting boot partition as root file system:", .{});
    switch (boot_info.boot_device) {
        .mbr => |_| @panic("Not implemented!"),
        .gpt => |gpt| {
            log.info("    Disk's uuid: {f}", .{gpt.disk_uuid});
            log.info("    Part's uuid: {f}", .{gpt.part_uuid});

            const disk_buf = std.fmt.allocPrintSentinel(allocator, "{f}", .{gpt.disk_uuid}, 0) catch root.oom_panic();
            const part_buf = std.fmt.allocPrintSentinel(allocator, "{f}", .{gpt.part_uuid}, 0) catch root.oom_panic();
            defer {
                allocator.free(disk_buf);
                allocator.free(part_buf);
            }

            const boot_node = root.fs.mount_disk_by_identifier_part_by_identifier(disk_buf.ptr, part_buf.ptr);
            root.fs.chroot(boot_node);
        },
        //else => unreachable,
    }

    const setup_query = root.fs.get_node("setup.toml");
    if (!setup_query.isok()) std.debug.panic("bruh {s}", .{@tagName(setup_query.@"error")});
    const setup_file: *lib.common.FsNode = setup_query.unwrap().?;

    const file_content = setup_file.readAll(allocator) catch unreachable;
    defer allocator.free(file_content);
    var toml = lib.Toml.parseToml(allocator, file_content) catch unreachable;
    defer toml.deinit();

    const fstab_nullable = toml.content.get("mount");
    if (fstab_nullable) |fstab| {
        if (fstab != .Array) std.debug.panic("{s}: Expected `mount` to be Array, found {s}", .{
            setup_file.name,
            @tagName(fstab),
        });

        for (fstab.Array) |i| {
            if (i != .Table) std.debug.panic("{s}: Expected table contents to be '{{ disk: String, part: String, path: String }}', found {s}", .{ setup_file.name, @tagName(i) });
            if (!i.Table.contains("disk") or i.Table.get("disk").? != .String or !i.Table.contains("part") or i.Table.get("part").? != .String or !i.Table.contains("path") or i.Table.get("path").? != .String)
                std.debug.panic("{s}: Expected table contents to be '{{ disk: String, part: String, path: String }}', found Invalid Table", .{setup_file.name});

            const entry_disk: [:0]const u8 = std.mem.sliceTo(i.Table.get("disk").?.String, 0);
            const entry_part: [:0]const u8 = std.mem.sliceTo(i.Table.get("part").?.String, 0);
            const entry_path: [:0]const u8 = std.mem.sliceTo(i.Table.get("path").?.String, 0);

            const entry_node = root.fs.mount_disk_by_identifier_part_by_identifier(
                entry_disk,
                entry_part,
            );

            if (std.mem.eql(u8, entry_path, "/")) {
                root.fs.chroot(entry_node);
            } else _ = root.fs.set_mount_point(entry_node, entry_path.ptr);
        }
    }

    _random_infodump();
    log.info("Entering in sleep mode... zzz\n", .{});

    // Adam should never return as it indicates
    // that the system is alive
    // TODO implement a proper sleep function
    // that will allow the system to enter a low power state
    // and wake up on an event
    while (true) {}
    unreachable;
}

fn _random_infodump() void {
    const lsblk: *const fn () callconv(.c) void = @ptrCast((root.capabilities.get_node("Devices.MassStorage.lsblk") orelse unreachable).data.callable);
    const lspci: *const fn () callconv(.c) void = @ptrCast((root.capabilities.get_node("Devices.PCI.lspci") orelse unreachable).data.callable);

    log.info("\nStage 2: Adam's debug info:\n", .{});
    threading.procman.lstasks();
    log.info("", .{});
    modules.lsmodules();
    log.info("", .{});
    lsblk();
    log.info("", .{});
    lspci();
    //log.info("", .{});
    //root.capabilities.lscaps();
    log.info("", .{});
    root.fs.lsroot();
}
