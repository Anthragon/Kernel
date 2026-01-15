const std = @import("std");
const builtin = @import("builtin");
const Build = std.Build;
const Target = std.Target;
const Step = Build.Step;

pub fn build(b: *std.Build) void {
    const target_arch = b.option(Target.Cpu.Arch, "tarch", "Target archtecture") orelse builtin.cpu.arch;

    const optimize = b.standardOptimizeOption(.{});

    var core_target = Target.Query{
        .cpu_arch = target_arch,
        .os_tag = .freestanding,
        .abi = .none,
        .ofmt = .elf,
    };
    switch (target_arch) {
        .x86_64 => {
            const Feature = std.Target.x86.Feature;

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
    const target_query = b.resolveTargetQuery(core_target);

    // Kernel library
    const kernel_lib = b.addModule("lib", .{
        .root_source_file = b.path("lib/root.zig"),
        .target = target_query,
        .optimize = optimize,
    });

    // kernel module
    const kernel_mod = b.addModule("kernel", .{
        .root_source_file = b.path("src/main.zig"),
        .target = target_query,
        .optimize = optimize,
        .red_zone = false,
    });

    kernel_mod.code_model = switch (target_arch) {
        .aarch64 => .small,
        .x86_64 => .kernel,
        else => unreachable,
    };
    kernel_mod.omit_frame_pointer = false;
    kernel_mod.strip = false;
    kernel_mod.single_threaded = true;

    const target_system_impl = b.dependency("system", .{}).module("system");
    kernel_mod.addImport("system", target_system_impl);

    kernel_mod.addImport("lib", kernel_lib);

    // kernel executable
    const kernel_exe = b.addExecutable(.{
        .name = "kernel",
        .root_module = kernel_mod,
        .use_llvm = true,
    });
    const kernel_install = b.addInstallArtifact(kernel_exe, .{});

    b.default_step.dependOn(&kernel_install.step);
}
