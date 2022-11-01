const std = @import("std");
const io = @import("io.zig");
const net = std.x.net;
const print = std.debug.print;

const Allocator = std.mem.Allocator;
const Reactor = io.Reactor;
const Listener = net.tcp.Listener;
const Address = net.ip.Address;
const Connection = net.tcp.Connection;
const Client = @import("client.zig").Client;

const localhost = std.x.os.IPv4.localhost;

const Self = @This();

pub const Loop = struct {
    allocator: Allocator,
    reactor: Reactor,
    server: Listener,

    pub inline fn init(allocator: Allocator) !Loop {
        var server = try Listener.init(.ip, .{
            .nonblocking = true,
            .close_on_exec = true,
        });
        errdefer server.deinit();

        try server.setFastOpen(true);
        try server.setReuseAddress(true);
        try server.setReusePort(true);
        try server.bind(Address.initIPv4(localhost, 8080));
        try server.listen(128);

        return Loop{
            .allocator = allocator,
            .reactor = try Reactor.init(),
            .server = server,
        };
    }

    pub inline fn deinit(self: Loop) void {
        self.server.deinit();
        self.reactor.deinit();
    }

    inline fn accept(self: Loop) !void {
        const connection = try self.server.accept(.{
            .nonblocking = true,
            .close_on_exec = true,
        });

        var ptr = try self.allocator.create(Client);
        ptr.* = .{
            .connection = connection,
        };

        try self.reactor.add(
            connection.client.socket.fd,
            @ptrToInt(ptr),
            .{ .readable = true, .writable = true },
        );
    }

    inline fn kill(self: Loop, client: *Client) void {
        defer self.allocator.destroy(client);
        self.reactor.remove(client.connection.client.socket.fd) catch unreachable;

        // call client's deinitializer for possible cleanups
        client.deinit();
    }

    inline fn runServerEvents(self: Loop, event: Reactor.Event) !void {
        if (event.is_readable)
            try self.accept();
    }

    inline fn runClientEvents(self: Loop, client: *Client, event: Reactor.Event, buf: []u8) !void {
        if (event.is_error)
            return self.kill(client);

        if (event.is_readable) {
            const len = try client.connection.client.read(buf, 0);
            if (len == 0) return self.kill(client);

            // drop the received buffer to client's callback
            client.onData(buf[0..len]) catch return self.kill(client);
        }

        if (event.is_writable) {
            print("able to write\n", .{});
        }
    }

    pub inline fn run(self: Loop) !void {
        const server_ptr = @ptrToInt(&self.server);
        try self.reactor.add(
            self.server.socket.fd,
            server_ptr,
            .{ .readable = true },
        );

        var buf: [8192]u8 = undefined;
        var event: ?Reactor.Event = null;

        while (true) {
            var poller = async self.reactor.poll(&event);

            while (event) |e| : (resume poller) {
                var is_server = e.data == server_ptr;
                if (is_server) {
                    try self.runServerEvents(e);
                    continue;
                }

                try self.runClientEvents(@intToPtr(*Client, e.data), e, &buf);
                buf = undefined;
            }
        }
    }
};
