const std = @import("std");
const builtin = @import("builtin");
const Build = std.Build;
const Target = std.Target;
const Step = Build.Step;

pub fn build(b: *std.Build) void {
    const target_arch = b.option(Target.Cpu.Arch, "tarch", "Target archtecture") orelse builtin.cpu.arch;

    var core_target = Target.Query{
        .cpu_arch = target_arch,
        .os_tag = .freestanding,
        .abi = .none,
        .ofmt = .elf,
    };

    //const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    switch (target_arch) {
        .x86_64 => {
            const Feature = std.Target.x86.Feature;

            core_target.cpu_features_sub.addFeature(@intFromEnum(Feature.mmx));
            core_target.cpu_features_sub.addFeature(@intFromEnum(Feature.sse));
            core_target.cpu_features_sub.addFeature(@intFromEnum(Feature.sse2));
            core_target.cpu_features_sub.addFeature(@intFromEnum(Feature.avx));
            core_target.cpu_features_sub.addFeature(@intFromEnum(Feature.avx2));

            core_target.cpu_features_add.addFeature(@intFromEnum(Feature.soft_float));
        },
        .aarch64 => {
            const features = std.Target.aarch64.Feature;
            core_target.cpu_features_sub.addFeature(@intFromEnum(features.fp_armv8));
            core_target.cpu_features_sub.addFeature(@intFromEnum(features.crypto));
            core_target.cpu_features_sub.addFeature(@intFromEnum(features.neon));
        },
        else => std.debug.panic("Unsuported archtecture {s}!", .{@tagName(target_arch)}),
    }

    // Kernel library
    const kernel_lib = b.addModule("lib", .{
        .root_source_file = b.path("lib/root.zig"),
        .target = b.resolveTargetQuery(core_target),
        .optimize = optimize,
    });

    // kernel module
    const kernel_mod = b.addModule("kernel", .{
        .root_source_file = b.path("src/main.zig"),
        .target = b.resolveTargetQuery(core_target),
        .optimize = optimize,
        .red_zone = false,
    });

    kernel_mod.code_model = switch (target_arch) {
        .aarch64 => .small,
        .x86_64 => .kernel,
        else => unreachable,
    };
    //kernel_mod.omit_frame_pointer = false;
    //kernel_mod.strip = false;
    kernel_mod.single_threaded = true;

    const target_system_impl = b.dependency("system", .{}).module("system");
    kernel_mod.addImport("system", target_system_impl);

    // TODO add dependences dinamically
    const lumi_pci = b.dependency("lumiPCI", .{}).module("lumiPCI");
    const lumi_ahci = b.dependency("lumiAHCI", .{}).module("lumiAHCI");
    const lumi_disk = b.dependency("lumiDisk", .{}).module("lumiDisk");
    const lumi_fat = b.dependency("lumiFAT", .{}).module("lumiFAT");

    kernel_mod.addImport("lumiPCI_module", lumi_pci);
    kernel_mod.addImport("lumiAHCI_module", lumi_ahci);
    kernel_mod.addImport("lumiDisk_module", lumi_disk);
    kernel_mod.addImport("lumiFAT_module", lumi_fat);

    kernel_mod.addImport("lib", kernel_lib);

    // kernel executable
    const kernel_exe = b.addExecutable(.{
        .name = "kernel",
        .root_module = kernel_mod,
        .use_llvm = true,
    });
    kernel_exe.entry = .{ .symbol_name = "__boot_entry__" };
    switch (target_arch) {
        .aarch64 => kernel_exe.setLinkerScript(b.path("linkage/aarch64.ld")),
        .x86_64 => kernel_exe.setLinkerScript(b.path("linkage/x86_64.ld")),
        else => unreachable,
    }

    const linktest = b.dependency("linkageTest", .{}).artifact("linkageTest");
    kernel_exe.linkLibrary(linktest);

    const install_kernel_step = b.addInstallArtifact(kernel_exe, .{});
    b.getInstallStep().dependOn(&install_kernel_step.step);
}
