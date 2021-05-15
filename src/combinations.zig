const std = @import("std");

pub fn Combinations(comptime T: type) type {
    return struct {
        n: usize,
        t: usize,
        s: []usize,
        initial_state: []const T,
        buf: []T,
        pub const Self = @This();

        // pub fn format(self: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        //     try writer.print("n: {}, t: {}, s: {any}, buf: {s} initial_state {s}", .{ self.n, self.t, self.s, self.buf, self.initial_state });
        // }

        pub fn init(initial_state: []const T, buf: []u8, s: []usize, t: usize) !Self {
            if (t > s.len) return error.OutOfBounds;
            for (s[0..t]) |*se, i| se.* = std.math.min(t - 1, i + 1);
            return Self{ .n = s.len, .t = t, .s = s, .initial_state = initial_state, .buf = buf };
        }

        fn next(c: *Self) ?[]T {
            std.mem.copy(T, c.buf, c.initial_state[0..c.t]);
            return if (nextImpl(c)) |_| blk: {
                for (c.s[0..c.t]) |ind, j| c.buf[j] = c.initial_state[ind - 1];
                break :blk c.buf[0..c.t];
            } else null;
        }

        fn nextImpl(c: *Self) ?[]const usize {
            if (c.t == 0) { //# special case to generate 1 result for t==0
                return if (c.s.len == 0) &[1]usize{0} else null;
            }
            var i = c.t;
            while (i > 0) : (i -= 1) {
                c.s[i - 1] += 1;
                if (c.s[i - 1] > (c.n - (c.t - i)))
                    continue;
                var j = i;
                while (j < c.t) : (j += 1)
                    c.s[j] = c.s[j - 1] + 1;
                break;
            }
            return if (c.s[0] > c.n - c.t + 1) null else c.s;
        }
    };
}

const expecteds_by_len: []const []const []const u8 = &.{
    &.{ "A", "B", "C", "A" },
    &.{ "AB", "AC", "AA", "BC", "BA", "CA" },
    &.{ "ABC", "ABA", "ACA", "BCA" },
    &.{"ABCA"},
};

test "iterate" {
    for (expecteds_by_len) |expectedslen, len| {
        const initial_state = "ABCA";
        var buf = initial_state.*;

        var s: [4]usize = undefined;
        var it = try Combinations(u8).init(initial_state, &buf, &s, len + 1);
        for (expectedslen) |expected| {
            const actual = it.next().?;
            try std.testing.expectEqualStrings(expected, actual);
        }
    }
}

test "edge cases" {
    const initial_state = "ABCA";
    var buf = initial_state.*;
    var s: [4]usize = undefined;
    // zero sized
    {
        var it = try Combinations(u8).init(initial_state, &buf, &s, 0);
        try std.testing.expectEqual(it.next(), null);
    }
    // over sized
    {
        try std.testing.expectError(error.OutOfBounds, Combinations(u8).init(initial_state, &buf, &s, s.len + 100));
    }
}
