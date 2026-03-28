const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // -Dlibusb=false disables libusb linkage for musl cross-compile
    const use_libusb = b.option(bool, "libusb", "Link libusb-1.0 (default: true)") orelse true;
    const use_wasm = b.option(bool, "wasm", "Link wasm3 runtime (default: true)") orelse true;
    const coverage = b.option(bool, "test-coverage", "Run tests with kcov coverage") orelse false;

    const wasm3_c_flags: []const []const u8 = &.{ "-std=c99", "-DDEBUG=0", "-Dd_m3HasWASI=0" };

    const build_opts = b.addOptions();
    build_opts.addOption(bool, "use_wasm", use_wasm);

    const toml_dep = b.dependency("toml", .{ .target = target, .optimize = optimize });
    const toml_mod = toml_dep.module("toml");

    // src module: shared by padctl, padctl-debug, and integration tests
    const src_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .sanitize_c = .trap,
    });
    src_mod.addImport("toml", toml_mod);
    src_mod.addImport("build_options", build_opts.createModule());
    if (use_wasm) addWasm3(b, src_mod, wasm3_c_flags);

    const exe = b.addExecutable(.{ .name = "padctl", .root_module = src_mod });
    if (use_libusb) {
        exe.linkSystemLibrary("usb-1.0");
    } else {
        exe.addIncludePath(b.path("compat"));
    }
    exe.linkLibC();
    b.installArtifact(exe);

    const debug_mod = b.createModule(.{
        .root_source_file = b.path("tools/padctl-debug.zig"),
        .target = target,
        .optimize = optimize,
        .sanitize_c = .trap,
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
        .sanitize_c = .trap,
    });
    io_hidraw_mod.link_libc = true;

    const capture_mod = b.createModule(.{
        .root_source_file = b.path("tools/padctl-capture.zig"),
        .target = target,
        .optimize = optimize,
        .sanitize_c = .trap,
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
        .sanitize_c = .trap,
    });
    unit_mod.addImport("toml", toml_mod);
    unit_mod.addImport("analyse", capture_analyse_mod);
    unit_mod.addImport("toml_gen", capture_toml_gen_mod);
    unit_mod.addImport("build_options", build_opts.createModule());
    if (use_wasm) addWasm3(b, unit_mod, wasm3_c_flags);
    const unit_tests = b.addTest(.{ .root_module = unit_mod });
    if (use_libusb) {
        unit_tests.linkSystemLibrary("usb-1.0");
    } else {
        unit_tests.addIncludePath(b.path("compat"));
    }
    unit_tests.linkLibC();
    if (coverage) unit_tests.setExecCmd(&.{ "kcov", "--include-path=src/", "kcov-output", null });
    const test_step = b.step("test", "Run Layer 0 + Layer 1 tests (CI)");
    test_step.dependOn(&b.addRunArtifact(unit_tests).step);

    // test-tsan: ThreadSanitizer-enabled test run (local dev)
    const tsan_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .sanitize_c = .trap,
        .sanitize_thread = true,
    });
    tsan_mod.addImport("toml", toml_mod);
    tsan_mod.addImport("analyse", capture_analyse_mod);
    tsan_mod.addImport("toml_gen", capture_toml_gen_mod);
    tsan_mod.addImport("build_options", build_opts.createModule());
    if (use_wasm) addWasm3(b, tsan_mod, wasm3_c_flags);
    const tsan_tests = b.addTest(.{ .root_module = tsan_mod });
    if (use_libusb) {
        tsan_tests.linkSystemLibrary("usb-1.0");
    } else {
        tsan_tests.addIncludePath(b.path("compat"));
    }
    tsan_tests.linkLibC();
    const tsan_step = b.step("test-tsan", "Run tests with ThreadSanitizer");
    tsan_step.dependOn(&b.addRunArtifact(tsan_tests).step);

    // test-safe: ReleaseSafe test run (catches UB under optimization)
    const safe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = .ReleaseSafe,
        .sanitize_c = .trap,
    });
    safe_mod.addImport("toml", toml_mod);
    safe_mod.addImport("analyse", capture_analyse_mod);
    safe_mod.addImport("toml_gen", capture_toml_gen_mod);
    safe_mod.addImport("build_options", build_opts.createModule());
    if (use_wasm) addWasm3(b, safe_mod, wasm3_c_flags);
    const safe_tests = b.addTest(.{ .root_module = safe_mod });
    if (use_libusb) {
        safe_tests.linkSystemLibrary("usb-1.0");
    } else {
        safe_tests.addIncludePath(b.path("compat"));
    }
    safe_tests.linkLibC();
    const safe_step = b.step("test-safe", "Run tests with ReleaseSafe (optimized + safety checks)");
    safe_step.dependOn(&b.addRunArtifact(safe_tests).step);

    // check-fmt: verify code formatting
    const fmt_step = b.step("check-fmt", "Check code formatting");
    const fmt = b.addFmt(.{ .paths = &.{ "src/", "tools/" }, .check = true });
    fmt_step.dependOn(&fmt.step);

    // check-all: single CI gate (test + safe + fmt; tsan excluded — crashes on some CI runners)
    const check_all = b.step("check-all", "Run all checks (test + safe + fmt)");
    check_all.dependOn(test_step);
    check_all.dependOn(safe_step);
    check_all.dependOn(fmt_step);

    // fuzz: continuous fuzzing (zig build fuzz --fuzz)
    const fuzz_step = b.step("fuzz", "Fuzz test (use: zig build fuzz --fuzz)");
    fuzz_step.dependOn(&b.addRunArtifact(unit_tests).step);

    // capture L0 tests (analyse pure functions)
    const capture_tests = b.addTest(.{ .root_module = capture_analyse_mod });
    if (coverage) capture_tests.setExecCmd(&.{ "kcov", "--include-path=src/", "kcov-output", null });
    test_step.dependOn(&b.addRunArtifact(capture_tests).step);

    // test-integration: Layer 2 (UHID, requires privilege)
    const integration_step = b.step("test-integration", "Run Layer 2 integration tests (UHID, local)");
    const integ_mod = b.createModule(.{
        .root_source_file = b.path("src/test/uhid_integration_test.zig"),
        .target = target,
        .optimize = optimize,
        .sanitize_c = .trap,
    });
    integ_mod.addImport("toml", toml_mod);
    integ_mod.addImport("src", src_mod);
    const integ_tests = b.addTest(.{ .root_module = integ_mod });
    if (use_libusb) {
        integ_tests.linkSystemLibrary("usb-1.0");
    } else {
        integ_tests.addIncludePath(b.path("compat"));
    }
    integ_tests.linkLibC();
    integration_step.dependOn(&b.addRunArtifact(integ_tests).step);

    // uhid_all_devices: L2 config-driven UHID simulation for all device configs
    const alldev_mod = b.createModule(.{
        .root_source_file = b.path("src/test/uhid_all_devices_test.zig"),
        .target = target,
        .optimize = optimize,
        .sanitize_c = .trap,
    });
    alldev_mod.addImport("toml", toml_mod);
    alldev_mod.addImport("src", src_mod);
    const alldev_tests = b.addTest(.{ .root_module = alldev_mod });
    if (use_libusb) {
        alldev_tests.linkSystemLibrary("usb-1.0");
    } else {
        alldev_tests.addIncludePath(b.path("compat"));
    }
    alldev_tests.linkLibC();
    integration_step.dependOn(&b.addRunArtifact(alldev_tests).step);

    // test-e2e: Layer 3 (UHID+uinput full pipeline, requires privilege)
    const e2e_step = b.step("test-e2e", "Run Layer 3 end-to-end tests (UHID+uinput, local)");
    const e2e_mod = b.createModule(.{
        .root_source_file = b.path("src/test/full_pipeline_e2e_test.zig"),
        .target = target,
        .optimize = optimize,
        .sanitize_c = .trap,
    });
    e2e_mod.addImport("src", src_mod);
    const e2e_tests = b.addTest(.{ .root_module = e2e_mod });
    if (use_libusb) {
        e2e_tests.linkSystemLibrary("usb-1.0");
    } else {
        e2e_tests.addIncludePath(b.path("compat"));
    }
    e2e_tests.linkLibC();
    e2e_step.dependOn(&b.addRunArtifact(e2e_tests).step);

    // spike (only available when spike/toml_spike.zig exists)
    if (std.fs.cwd().access("spike/toml_spike.zig", .{})) |_| {
        const spike_mod = b.createModule(.{
            .root_source_file = b.path("spike/toml_spike.zig"),
            .target = target,
            .optimize = optimize,
        });
        spike_mod.addImport("toml", toml_mod);
        const spike_exe = b.addExecutable(.{ .name = "toml-spike", .root_module = spike_mod });
        const spike_step = b.step("spike", "Run TOML spike");
        spike_step.dependOn(&b.addRunArtifact(spike_exe).step);
    } else |_| {}
}

fn addWasm3(b: *std.Build, mod: *std.Build.Module, c_flags: []const []const u8) void {
    mod.addCSourceFiles(.{
        .root = b.path("third_party/wasm3/source"),
        .files = &.{
            "m3_api_libc.c",
            "m3_api_meta_wasi.c",
            "m3_api_tracer.c",
            "m3_bind.c",
            "m3_code.c",
            "m3_compile.c",
            "m3_core.c",
            "m3_env.c",
            "m3_exec.c",
            "m3_function.c",
            "m3_info.c",
            "m3_module.c",
            "m3_parse.c",
        },
        .flags = c_flags,
    });
    mod.addIncludePath(b.path("third_party/wasm3/source"));
}
