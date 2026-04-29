// UHID test cleanup: SIGTERM handler sends UHID_DESTROY; opens use O_NONBLOCK to avoid D-state on dead firmware.
//
// When a test process is killed before calling uhidDestroy(), the kernel UHID device persists and
// subsequent open(/dev/hidrawN) calls block in D-state until reboot. This helper installs a
// SIGTERM/SIGINT handler that sends UHID_DESTROY on all registered fds before the process exits.

const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;
const builtin = @import("builtin");

const UHID_DESTROY: u32 = 1;
const UHID_EVENT_SIZE: usize = 4380;
const REGISTRY_CAP = 8;
const SENTINEL: i32 = -1;

// Fixed-size registry. Each slot holds a registered uhid fd or SENTINEL.
// Written from normal test code (registerUhidFd / unregisterUhidFd) and read
// from the signal handler — atomic i32 is the only safe primitive here.
var registry: [REGISTRY_CAP]std.atomic.Value(i32) = blk: {
    var arr: [REGISTRY_CAP]std.atomic.Value(i32) = undefined;
    for (&arr) |*slot| slot.* = std.atomic.Value(i32).init(SENTINEL);
    break :blk arr;
};

var handler_installed = std.atomic.Value(bool).init(false);

// Static UHID_DESTROY payload (opcode 1, rest zero). Initialized once before
// handlers are installed; the signal handler reads it without modification.
var destroy_buf: [UHID_EVENT_SIZE]u8 = [_]u8{0} ** UHID_EVENT_SIZE;

fn signalHandler(sig: i32) callconv(.c) void {
    for (&registry) |*slot| {
        const fd = slot.swap(SENTINEL, .acquire);
        if (fd == SENTINEL) continue;
        // async-signal-safe: only write() and close()
        _ = linux.write(@intCast(fd), &destroy_buf, UHID_EVENT_SIZE);
        _ = linux.close(@intCast(fd));
    }
    // Reset to default handler and re-raise so the process exits with the correct signal.
    const sig_u8: u8 = @intCast(sig);
    posix.sigaction(sig_u8, &.{
        .handler = .{ .handler = posix.SIG.DFL },
        .mask = posix.sigemptyset(),
        .flags = 0,
    }, null);
    _ = linux.kill(linux.getpid(), sig);
}

/// Install SIGTERM + SIGINT cleanup handlers. Safe to call from multiple tests;
/// installs exactly once per process. No-op outside test builds.
pub fn ensureSignalHandlersInstalled() void {
    if (!builtin.is_test) return;
    if (handler_installed.swap(true, .acq_rel)) return;
    // Write opcode into global buffer before any signal can fire.
    std.mem.writeInt(u32, destroy_buf[0..4], UHID_DESTROY, .little);
    const sa = posix.Sigaction{
        .handler = .{ .handler = signalHandler },
        .mask = posix.sigemptyset(),
        .flags = 0,
    };
    posix.sigaction(posix.SIG.TERM, &sa, null);
    posix.sigaction(posix.SIG.INT, &sa, null);
}

/// Register an open uhid fd with the cleanup registry. Call immediately after
/// a successful open("/dev/uhid"). Silently drops if the registry is full.
pub fn registerUhidFd(fd: i32) void {
    for (&registry) |*slot| {
        if (slot.cmpxchgStrong(SENTINEL, fd, .acq_rel, .acquire) == null) return;
    }
}

/// Remove an fd from the cleanup registry. Call immediately before the normal
/// uhidDestroy + close sequence.
pub fn unregisterUhidFd(fd: i32) void {
    for (&registry) |*slot| {
        _ = slot.cmpxchgStrong(fd, SENTINEL, .acq_rel, .acquire);
    }
}
