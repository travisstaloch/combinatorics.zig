const std = @import("std");

const nck = @import("misc.zig").NChooseK;

// TODO: benchmark this against previous version from 78b055
pub fn Combinations(comptime T: type) type {
    return struct {
        nck: Nck,
        initial_state: []const T,
        buf: []T,
        const Self = @This();
        const Nck = nck(usize);

        pub fn init(initial_state: []const T, buf: []u8, k: usize) !Self {
            if (k > initial_state.len or k > buf.len) return error.ArgumentBounds;
            return Self{
                .nck = try Nck.init(initial_state.len, k),
                .initial_state = initial_state,
                .buf = buf,
            };
        }

        fn next(self: *Self) ?[]T {
            return if (self.nck.next()) |nckbits| blk: {
                var bits = nckbits;
                std.mem.copy(T, self.buf, self.initial_state[0..self.nck.k]);
                var i: usize = 0;
                while (i < self.nck.k) : (i += 1) {
                    const idx = @ctz(usize, bits);
                    bits &= ~(@as(usize, 1) << @intCast(u6, idx));
                    self.buf[i] = self.initial_state[idx];
                }
                break :blk self.buf[0..self.nck.k];
            } else null;
        }
    };
}

const expecteds_by_len: []const []const []const u8 = &.{
    &.{ "A", "B", "C", "A" },
    &.{ "AB", "AC", "BC", "AA", "BA", "CA" },
    &.{ "ABC", "ABA", "ACA", "BCA" },
    &.{"ABCA"},
};

test "iterate" {
    for (expecteds_by_len) |expectedslen, len| {
        const initial_state = "ABCA";
        var buf = initial_state.*;
        var it = try Combinations(u8).init(initial_state, &buf, len + 1);

        for (expectedslen) |expected| {
            const actual = it.next().?;
            try std.testing.expectEqualStrings(expected, actual);
        }
    }
}

test "edge cases" {
    const initial_state = "ABCA";
    var buf = initial_state.*;

    // k = 0
    {
        var it = try Combinations(u8).init(initial_state, &buf, 0);
        try std.testing.expectEqual(it.next(), null);
    }

    // over sized k
    {
        try std.testing.expectError(
            error.ArgumentBounds,
            Combinations(u8).init(initial_state, &buf, initial_state.len + 100),
        );
    }

    // zero sized initial_state, or too small
    {
        try std.testing.expectError(
            error.ArgumentBounds,
            Combinations(u8).init("", &buf, initial_state.len),
        );
        try std.testing.expectError(
            error.ArgumentBounds,
            Combinations(u8).init("A", &buf, initial_state.len),
        );
    }

    // buffer too small
    {
        var buf2: [1]u8 = undefined;
        try std.testing.expectError(
            error.ArgumentBounds,
            Combinations(u8).init(initial_state, &buf2, initial_state.len),
        );
    }
}
