const std = @import("std");
const posix = std.posix;

/// Per-managed-instance monotonic-ns atomics used by PR-ε.2 watchdog to detect
/// kernel-side D-state hangs in hidraw write/ioctl paths. Pure observability;
/// nothing in this struct triggers recovery.
pub const WedgeAtomics = struct {
    last_inbound_ns: u64 = 0,
    last_outbound_ns: u64 = 0,
    write_in_flight_since_ns: u64 = 0,

    pub fn nowNs() u64 {
        const ts = posix.clock_gettime(.MONOTONIC) catch return 0;
        const sec: u64 = @intCast(ts.sec);
        const nsec: u64 = @intCast(ts.nsec);
        return sec *| std.time.ns_per_s +| nsec;
    }

    pub fn bumpInbound(self: *WedgeAtomics) void {
        @atomicStore(u64, &self.last_inbound_ns, nowNs(), .release);
    }

    pub fn bumpOutbound(self: *WedgeAtomics) void {
        @atomicStore(u64, &self.last_outbound_ns, nowNs(), .release);
    }

    pub fn beginWrite(self: *WedgeAtomics) void {
        @atomicStore(u64, &self.write_in_flight_since_ns, nowNs(), .release);
    }

    pub fn endWrite(self: *WedgeAtomics) void {
        @atomicStore(u64, &self.write_in_flight_since_ns, 0, .release);
    }

    pub fn loadInbound(self: *const WedgeAtomics) u64 {
        return @atomicLoad(u64, &self.last_inbound_ns, .acquire);
    }

    pub fn loadOutbound(self: *const WedgeAtomics) u64 {
        return @atomicLoad(u64, &self.last_outbound_ns, .acquire);
    }

    pub fn loadInFlight(self: *const WedgeAtomics) u64 {
        return @atomicLoad(u64, &self.write_in_flight_since_ns, .acquire);
    }
};
