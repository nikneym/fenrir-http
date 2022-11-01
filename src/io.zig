const std = @import("std");
const builtin = @import("builtin");

pub const Reactor = switch (builtin.os.tag) {
    .linux => @import("io/reactor_linux.zig").Reactor,
    else => @compileError("Unsupported OS"),
};
