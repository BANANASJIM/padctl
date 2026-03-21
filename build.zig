const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // -Dlibusb=false disables libusb linkage for musl cross-compile
    const use_libusb = b.option(bool, "libusb", "Link libusb-1.0 (default: true)") orelse true;

    const toml_dep = b.dependency("toml", .{ .target = target, .optimize = optimize });
    const toml_mod = toml_dep.module("toml");

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addImport("toml", toml_mod);

    const exe = b.addExecutable(.{ .name = "padctl", .root_module = exe_mod });
    if (use_libusb) {
        exe.linkSystemLibrary("usb-1.0");
    } else {
        exe.addIncludePath(b.path("compat"));
    }
    exe.linkLibC();
    b.installArtifact(exe);

    // src library module: shared by padctl-debug binary and tests
    const src_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    src_mod.addImport("toml", toml_mod);

    const debug_mod = b.createModule(.{
        .root_source_file = b.path("tools/padctl-debug.zig"),
        .target = target,
        .optimize = optimize,
    });
    debug_mod.addImport("src", src_mod);

    const debug_exe = b.addExecutable(.{ .name = "padctl-debug", .root_module = debug_mod });
    if (use_libusb) {
        debug_exe.linkSystemLibrary("usb-1.0");
    } else {
        debug_exe.addIncludePath(b.path("compat"));
    }
    debug_exe.linkLibC();
    b.installArtifact(debug_exe);

    const capture_analyse_mod = b.createModule(.{
        .root_source_file = b.path("src/capture/analyse.zig"),
        .target = target,
        .optimize = optimize,
    });
    const capture_toml_gen_mod = b.createModule(.{
        .root_source_file = b.path("src/capture/toml_gen.zig"),
        .target = target,
        .optimize = optimize,
    });
    capture_toml_gen_mod.addImport("analyse", capture_analyse_mod);

    const io_hidraw_mod = b.createModule(.{
        .root_source_file = b.path("src/io/hidraw.zig"),
        .target = target,
        .optimize = optimize,
    });
    io_hidraw_mod.link_libc = true;

    const capture_mod = b.createModule(.{
        .root_source_file = b.path("tools/padctl-capture.zig"),
        .target = target,
        .optimize = optimize,
    });
    capture_mod.addImport("analyse", capture_analyse_mod);
    capture_mod.addImport("toml_gen", capture_toml_gen_mod);
    capture_mod.addImport("hidraw_mod", io_hidraw_mod);
    const capture_exe = b.addExecutable(.{ .name = "padctl-capture", .root_module = capture_mod });
    capture_exe.linkLibC();
    b.installArtifact(capture_exe);

    // test: Layer 0 + Layer 1 (CI); refAllDecls in main.zig pulls in debug/render.zig tests
    const unit_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    unit_mod.addImport("toml", toml_mod);
    unit_mod.addImport("analyse", capture_analyse_mod);
    unit_mod.addImport("toml_gen", capture_toml_gen_mod);
    const unit_tests = b.addTest(.{ .root_module = unit_mod });
    if (use_libusb) {
        unit_tests.linkSystemLibrary("usb-1.0");
    } else {
        unit_tests.addIncludePath(b.path("compat"));
    }
    unit_tests.linkLibC();
    const test_step = b.step("test", "Run Layer 0 + Layer 1 tests (CI)");
    test_step.dependOn(&b.addRunArtifact(unit_tests).step);

    // capture L0 tests (analyse pure functions)
    const capture_tests = b.addTest(.{ .root_module = capture_analyse_mod });
    test_step.dependOn(&b.addRunArtifact(capture_tests).step);

    // test-integration: Layer 2 (UHID, requires privilege)
    const integration_step = b.step("test-integration", "Run Layer 2 integration tests (UHID, local)");
    _ = integration_step;

    // test-e2e: Layer 3 (real hardware)
    const e2e_step = b.step("test-e2e", "Run Layer 3 end-to-end tests (real hardware)");
    _ = e2e_step;

    // spike
    const spike_mod = b.createModule(.{
        .root_source_file = b.path("spike/toml_spike.zig"),
        .target = target,
        .optimize = optimize,
    });
    spike_mod.addImport("toml", toml_mod);
    const spike_exe = b.addExecutable(.{ .name = "toml-spike", .root_module = spike_mod });
    const spike_step = b.step("spike", "Run TOML spike");
    spike_step.dependOn(&b.addRunArtifact(spike_exe).step);
}
