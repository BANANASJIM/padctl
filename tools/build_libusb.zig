const std = @import("std");

pub fn build(b: *std.Build, dep: *std.Build.Dependency, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Step.Compile {
    const lib = b.addLibrary(.{
        .name = "usb",
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .sanitize_c = .off,
        }),
    });
    lib.addCSourceFiles(.{
        .root = dep.path("libusb"),
        .files = &.{
            "core.c",            "descriptor.c",       "hotplug.c",          "io.c",             "strerror.c", "sync.c",
            "os/events_posix.c", "os/threads_posix.c", "os/linux_netlink.c", "os/linux_usbfs.c",
        },
        .flags = &.{"-std=c11"},
    });
    lib.addIncludePath(b.path("third_party/libusb"));
    lib.addIncludePath(dep.path("libusb"));
    return lib;
}

pub fn descriptorTest(b: *std.Build, dep: *std.Build.Dependency, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Step.Compile {
    const exe = b.addExecutable(.{
        .name = "libusb-descriptor-security-test",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    exe.addCSourceFile(.{ .file = b.path("tests/libusb_descriptor_security.c"), .flags = &.{"-std=c11"} });
    exe.addIncludePath(b.path("third_party/libusb"));
    exe.addIncludePath(dep.path("libusb"));
    return exe;
}
