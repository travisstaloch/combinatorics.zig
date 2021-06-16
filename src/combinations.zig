const std = @import("std");

const misc = @import("misc.zig");
const NChooseK = misc.NChooseK;
const NChooseKBig = misc.NChooseKBig;

// TODO: benchmark this against previous version from 78b055
pub fn Combinations(comptime Element: type, comptime Set: type) type {
    return struct {
        nck: Nck,
        initial_state: []const Element,
        buf: []Element,
        const Self = @This();
        const Nck = NChooseK(Set);
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

pub fn CombinationsBig(comptime Element: type) type {
    return struct {
        nck: Nck,
        initial_state: []const Element,
        buf: []Element,
        const Self = @This();
        const Nck = NChooseKBig;

        pub fn init(allocator: *std.mem.Allocator, initial_state: []const Element, buf: []u8, k: usize) !Self {
            if (k > initial_state.len or k > buf.len or initial_state.len > std.math.maxInt(usize)) return error.ArgumentBounds;
            return Self{
                .nck = try Nck.init(allocator, initial_state.len, k),
                .initial_state = initial_state,
                .buf = buf,
            };
        }

        fn next(self: *Self) !?[]Element {
            return if (try self.nck.next()) |*bits| blk: {
                defer bits.deinit();
                std.mem.copy(Element, self.buf, self.initial_state[0..self.nck.k]);
                var i: usize = 0;
                while (i < self.nck.k) : (i += 1) {
                    var idx: usize = 0;
                    for (bits.limbs[0..bits.len()]) |limb| {
                        idx += @ctz(usize, limb);
                        if (limb != 0) break;
                    }

                    // bits &= ~(1 << idx);
                    // unset bit at idx

                    const limb_idx = idx / 64;
                    const limb_offset = idx % 64;
                    bits.limbs[limb_idx] &= ~(@as(usize, 1) << @intCast(u6, limb_offset));
                    self.buf[i] = self.initial_state[idx];
                }
                break :blk self.buf[0..self.nck.k];
            } else null;
        }
    };
}

test "big iterate" {
    for (expecteds_by_len) |expectedslen, len| {
        const initial_state = "ABCA";
        var buf = initial_state.*;
        var it = try CombinationsBig(u8).init(std.testing.allocator, initial_state, &buf, len + 1);
        defer it.nck.deinit();

        for (expectedslen) |expected| {
            var actual = (try it.next()).?;
            try std.testing.expectEqualStrings(expected, actual);
        }
    }
}

test "big set size 127" {
    // make sure all combos match normal Combinations iterator
    const initial_state_big = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz" ++
        "a".* ** 23;
    try std.testing.expectEqual(127, initial_state_big.len);
    {
        var buf = initial_state_big.*;
        var buf2 = initial_state_big.*;
        var it = try CombinationsBig(u8).init(std.testing.allocator, initial_state_big, &buf, initial_state_big.len - 1);
        var it2 = try Combinations(u8, u128).init(initial_state_big, &buf2, initial_state_big.len - 1);
        defer it.nck.deinit();
        while (try it.next()) |actual| {
            const expected = it2.next().?;
            try std.testing.expectEqualStrings(expected, actual);
        }
    }
}

test "big set size 256" {
    const initial_state_big = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz" ** 2 ++
        "a".* ** 48;
    try std.testing.expectEqual(256, initial_state_big.len);
    {
        var buf = initial_state_big.*;
        var it = try CombinationsBig(u8).init(std.testing.allocator, initial_state_big, &buf, initial_state_big.len - 1);
        defer it.nck.deinit();
        var i: usize = 0;
        while (try it.next()) |actual| : (i += 1) {}
        try std.testing.expectEqual(@as(usize, 256), i);
    }
}

test "big set size 256 choose 2" {
    const expecteds: []const []const u8 = &.{
        &.{ 0, 1 },
        &.{ 0, 2 },
        &.{ 1, 2 },
        &.{ 0, 3 },
        &.{ 1, 3 },
        &.{ 2, 3 },
        &.{ 0, 4 },
        &.{ 1, 4 },
        &.{ 2, 4 },
        &.{ 3, 4 },
    };
    var xs: [256]u8 = undefined;
    const k = 2;
    var buf: [k]u8 = undefined;
    for (xs) |*x, i| x.* = @intCast(u8, i); // xs == 0..255
    var it = try CombinationsBig(u8).init(std.testing.allocator, &xs, &buf, k);
    defer it.nck.deinit();
    var i: usize = 0;
    for (expecteds) |expected| {
        const actual = (try it.next()).?;
        try std.testing.expectEqualSlices(u8, expected, actual);
        i += 1;
    }
    while (try it.next()) |_| : (i += 1) {}
    // binomial(256,2 ) == 32640
    try std.testing.expectEqual(@as(usize, 32640), i);
}
