const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const toml_dep = b.dependency("toml", .{ .target = target, .optimize = optimize });
    const toml_mod = toml_dep.module("toml");

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addImport("toml", toml_mod);

    const exe = b.addExecutable(.{
        .name = "padctl",
        .root_module = exe_mod,
    });
    exe.linkSystemLibrary("usb-1.0");
    exe.linkLibC();
    b.installArtifact(exe);

    const debug_exe = b.addExecutable(.{
        .name = "padctl-debug",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/padctl-debug.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(debug_exe);

    const capture_exe = b.addExecutable(.{
        .name = "padctl-capture",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/padctl-capture.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(capture_exe);

    const test_step = b.step("test", "Run unit tests");

    const test_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    test_mod.addImport("toml", toml_mod);

    const unit_tests = b.addTest(.{ .root_module = test_mod });
    test_step.dependOn(&b.addRunArtifact(unit_tests).step);

    const spike_exe = b.addExecutable(.{
        .name = "toml-spike",
        .root_module = b.createModule(.{
            .root_source_file = b.path("spike/toml_spike.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    spike_exe.root_module.addImport("toml", toml_mod);

    const spike_step = b.step("spike", "Run TOML spike");
    spike_step.dependOn(&b.addRunArtifact(spike_exe).step);
}
