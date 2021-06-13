const std = @import("std");

const nck = @import("misc.zig").NChooseK;

// TODO: benchmark this against previous version from 78b055
pub fn Combinations(comptime Element: type, comptime Set: type) type {
    return struct {
        nck: Nck,
        initial_state: []const Element,
        buf: []Element,
        const Self = @This();
        const Nck = nck(Set);
        const SetLog2 = std.math.Log2Int(Set);

        pub fn init(initial_state: []const Element, buf: []u8, k: SetLog2) !Self {
            if (k > initial_state.len or k > buf.len or initial_state.len > std.math.maxInt(SetLog2)) return error.ArgumentBounds;
            return Self{
                .nck = try Nck.init(@intCast(SetLog2, initial_state.len), k),
                .initial_state = initial_state,
                .buf = buf,
            };
        }

        fn next(self: *Self) ?[]Element {
            return if (self.nck.next()) |nckbits| blk: {
                var bits = nckbits;
                std.mem.copy(Element, self.buf, self.initial_state[0..@intCast(usize, self.nck.k)]);
                var i: usize = 0;
                while (i < self.nck.k) : (i += 1) {
                    const idx = @ctz(Set, bits);
                    bits &= ~(@as(Set, 1) << @intCast(SetLog2, idx));
                    self.buf[i] = self.initial_state[idx];
                }
                break :blk self.buf[0..@intCast(usize, self.nck.k)];
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
        var it = try Combinations(u8, usize).init(initial_state, &buf, @intCast(u6, len + 1));

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
        var it = try Combinations(u8, usize).init(initial_state, &buf, 0);
        try std.testing.expectEqual(it.next(), null);
    }

    // over sized k
    {
        try std.testing.expectError(
            error.ArgumentBounds,
            Combinations(u8, usize).init(initial_state, &buf, initial_state.len + 1),
        );
    }

    // zero sized initial_state, or too small
    {
        try std.testing.expectError(
            error.ArgumentBounds,
            Combinations(u8, usize).init("", &buf, initial_state.len),
        );
        try std.testing.expectError(
            error.ArgumentBounds,
            Combinations(u8, usize).init("A", &buf, initial_state.len),
        );
    }

    // buffer too small
    {
        var buf2: [1]u8 = undefined;
        try std.testing.expectError(
            error.ArgumentBounds,
            Combinations(u8, usize).init(initial_state, &buf2, initial_state.len),
        );
    }
}

test "set size 127" {
    const initial_state_large = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz" ++
        "a".* ** 23;
    try std.testing.expectEqual(127, initial_state_large.len);
    {
        var buf = initial_state_large.*;
        var it = try Combinations(u8, u128).init(initial_state_large, &buf, initial_state_large.len - 1);
        while (it.next()) |c| {}
    }
    {
        const init_too_large = initial_state_large ++ "a";
        var buf = init_too_large.*;
        try std.testing.expectError(error.ArgumentBounds, Combinations(u8, u128).init(
            init_too_large,
            &buf,
            initial_state_large.len - 1,
        ));
    }
}
