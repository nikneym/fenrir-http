const std = @import("std");
const os = std.os;
const mem = std.mem;
const print = std.debug.print;
const event = @import("event.zig");

const Loop = event.Loop;
const Allocator = std.mem.Allocator;
const Address = std.net.Address;

pub const io_mode = .evented;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var loop = try Loop.init(allocator);
    defer loop.deinit();

    try loop.run();
}
