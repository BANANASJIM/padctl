const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "padctl",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
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
    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    test_step.dependOn(&b.addRunArtifact(unit_tests).step);
}
