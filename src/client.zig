const std = @import("std");
const net = std.x.net;
const print = std.debug.print;

const Connection = net.tcp.Connection;

pub const Client = struct {
    connection: Connection,

    pub fn deinit(self: Client) void {
        print("removed!\n", .{});
        self.connection.deinit();
    }

    /// event loop calls this function if any bytes received
    pub fn onData(self: Client, buf: []u8) !void {
        _ = self;
        print("{s}", .{ buf });
    }
};
