const std = @import("std");

/// hidraw nodes are root:input mode 0660; a user not in the `input` group (or
/// before udev `uaccess` applies) gets EACCES on open. scan, doctor, and
/// `config test` all hit this, so the remedy is shared here to stay identical.
pub fn writeInputGroupHint(writer: anytype) void {
    writer.writeAll("hint: sudo usermod -aG input $USER && re-login (or replug to apply udev rules)\n") catch {};
}

const testing = std.testing;

test "perm_hint: writeInputGroupHint emits the usermod remedy" {
    var buf: std.ArrayList(u8) = .{};
    defer buf.deinit(testing.allocator);
    writeInputGroupHint(buf.writer(testing.allocator));
    try testing.expect(std.mem.indexOf(u8, buf.items, "usermod -aG input $USER") != null);
    try testing.expect(std.mem.indexOf(u8, buf.items, "re-login") != null);
}
