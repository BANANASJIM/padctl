//! Stateful adapter between the pure DualSense Edge USB codec and UHID.
//!
//! The box has a stable address before the native pump starts, so every
//! control/output callback and the primary OutputDevice vtable can share one
//! context without putting protocol policy in the generic UhidDevice.

const std = @import("std");
const state = @import("../core/state.zig");
const uinput = @import("uinput.zig");
const uhid = @import("uhid.zig");
const codec = @import("dualsense_edge_usb.zig");
const identity_mod = @import("edge_identity.zig");

pub const EdgeRuntime = struct {
    pub const ControlSnapshot = struct {
        get_report: u32,
        set_report: u32,
    };

    identity: identity_mod.StableIdentity,
    encoder: codec.InputEncoder,
    /// Bound immediately after the pre-CREATE pump and CREATE2 succeed.
    /// Pump callbacks do not dereference this field.
    device: ?*uhid.UhidDevice = null,
    control_get_count: std.atomic.Value(u32) = std.atomic.Value(u32).init(0),
    control_set_count: std.atomic.Value(u32) = std.atomic.Value(u32).init(0),

    pub fn init(identity: identity_mod.StableIdentity, touch: codec.TouchSynthesis) EdgeRuntime {
        return .{
            .identity = identity,
            .encoder = codec.InputEncoder.init(touch),
        };
    }

    pub fn bindDevice(self: *EdgeRuntime, device: *uhid.UhidDevice) void {
        self.device = device;
    }

    pub fn nativePumpConfig(self: *EdgeRuntime) uhid.NativePumpConfig {
        return .{
            .control_handler = .{
                .ctx = self,
                .get_report = getFeatureReport,
                .set_report = rejectSetReport,
            },
            .output_handler = .{
                .ctx = self,
                .decode = decodeRumble,
            },
        };
    }

    pub fn outputDevice(self: *EdgeRuntime) uinput.OutputDevice {
        return .{ .ptr = self, .vtable = &output_vtable };
    }

    /// Read-only integration evidence that kernel feature ioctls traversed
    /// this production runtime rather than a test-owned responder.
    pub fn controlSnapshot(self: *const EdgeRuntime) ControlSnapshot {
        return .{
            .get_report = self.control_get_count.load(.acquire),
            .set_report = self.control_set_count.load(.acquire),
        };
    }

    fn getFeatureReport(
        context: *anyopaque,
        request: uhid.GetReportRequest,
        reply_data: []u8,
    ) uhid.GetReportResult {
        const self: *EdgeRuntime = @ptrCast(@alignCast(context));
        _ = self.control_get_count.fetchAdd(1, .release);
        if (request.report_type != .feature) return .{ .err = uhid.UHID_PROTOCOL_ERROR };
        const report = codec.featureReport(request.report_number, self.identity.edge, reply_data) catch
            return .{ .err = uhid.UHID_PROTOCOL_ERROR };
        return .{ .size = report.len };
    }

    fn rejectSetReport(context: *anyopaque, _: uhid.SetReportRequest) u16 {
        const self: *EdgeRuntime = @ptrCast(@alignCast(context));
        _ = self.control_set_count.fetchAdd(1, .release);
        return uhid.UHID_PROTOCOL_ERROR;
    }

    fn decodeRumble(_: *anyopaque, report: uhid.OutputReport) ?uhid.RumbleCommand {
        return codec.decodeOutputReport(report) catch null;
    }

    const output_vtable = uinput.OutputDevice.VTable{
        .emit = emit,
        .poll_ff = pollFf,
        // Ownership remains in DeviceInstance.Owner.uhid. DeviceInstance
        // closes/joins that UHID pump before freeing this adapter box.
        .close = closeNonOwning,
    };

    fn emit(context: *anyopaque, gamepad: state.GamepadState) uinput.EmitError!void {
        const self: *EdgeRuntime = @ptrCast(@alignCast(context));
        const device = self.device orelse return error.DeviceGone;
        const report = self.encoder.encode(gamepad);
        try device.emitRaw(&report);
        device.state_snapshot = gamepad;
    }

    fn pollFf(_: *anyopaque) uinput.PollFfError!?uinput.FfEvent {
        return null;
    }

    fn closeNonOwning(_: *anyopaque) void {}
};
