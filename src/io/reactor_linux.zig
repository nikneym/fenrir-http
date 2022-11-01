const std = @import("std");
const os = std.os;
const linux = std.os.linux;

// Epoll based event notification
pub const Reactor = struct {
    pub const Event = struct {
        data: usize,
        is_error: bool,
        is_readable: bool,
        is_writable: bool,
    };

    pub const Interest = struct {
        readable: bool = false,
        writable: bool = false,
    };

    fd: os.fd_t,

    pub inline fn init() !Reactor {
        return Reactor{
            .fd = try os.epoll_create1(linux.EPOLL.CLOEXEC),
        };
    }

    pub inline fn deinit(self: Reactor) void {
        os.close(self.fd);
    }

    /// adds a file descriptor to watch list.
    pub inline fn add(self: Reactor, fd: os.fd_t, identifier: usize, interest: Reactor.Interest) !void {
        var flags: u32 = 0;
        if (interest.readable) flags |= linux.EPOLL.IN;
        if (interest.writable) flags |= linux.EPOLL.OUT;

        const event = &linux.epoll_event{
            .events = flags,
            .data = .{ .ptr = identifier },
        };

        return os.epoll_ctl(self.fd, linux.EPOLL.CTL_ADD, fd, event);
    }

    /// update flags and data of a file descriptor from watch list.
    pub inline fn update(self: Reactor, fd: os.fd_t, identifier: usize, interest: Reactor.Interest) !void {
        var flags: u32 = 0;
        if (interest.readable) flags |= linux.EPOLL.IN;
        if (interest.writable) flags |= linux.EPOLL.OUT;

        const event = &linux.epoll_event{
            .events = flags,
            .data = .{ .ptr = identifier },
        };

        return os.epoll_ctl(self.fd, linux.EPOLL.CTL_MOD, fd, event);
    }

    /// removes a file descriptor from watch list.
    pub inline fn remove(self: Reactor, fd: os.fd_t) !void {
        return os.epoll_ctl(self.fd, linux.EPOLL.CTL_DEL, fd, null);
    }

    /// poll for possible events. modifies the value of `event` in order to notify the caller.
    pub fn poll(self: Reactor, event: *?Reactor.Event) callconv(.Async) void {
        defer { suspend event.* = null; }
        var events: [128]linux.epoll_event = undefined;

        const num_events = os.epoll_wait(self.fd, &events, 0);
        for (events[0..num_events]) |e| {
            const is_error = e.events & linux.EPOLL.ERR != 0;
            const is_readable = e.events & linux.EPOLL.IN != 0;
            const is_writable = e.events & linux.EPOLL.OUT != 0;

            suspend {
                event.* = .{
                    .data = e.data.ptr,
                    .is_error = is_error,
                    .is_readable = is_readable,
                    .is_writable = is_writable,
                };
            }
        }
    }
};
