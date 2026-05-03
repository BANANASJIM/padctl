// Package root set at repo root so @embedFile("../../...") paths in src/ resolve correctly.
const main = @import("src/main.zig");
comptime {
    _ = main;
}
