const std = @import("std");

const fact_table_size = 35;
const BigInt = std.math.big.int.Mutable;

const fact_table128 =
    comptime blk: {
    var tbl128: [fact_table_size]u128 = undefined;
    tbl128[0] = 1;
    var n: u128 = 1;
    while (n < fact_table_size) : (n += 1) {
        tbl128[n] = tbl128[n - 1] * n;
    }
    break :blk tbl128;
};

pub fn factorialLookup(comptime T: type, n: usize, table: anytype, lim: usize) !T {
    if (n > lim) return error.Overflow;
    const f = table[n];
    return @intCast(T, f);
}

pub fn nthperm(comptime T: type, a: []T, k: u128) !void {
    const n = @intCast(u128, a.len);
    if (n == 0) return;

    var f = try factorialLookup(u128, @intCast(usize, n), &fact_table128, fact_table_size);

    if (!(0 <= k and k <= f)) return error.ArgumentBounds;

    var i: usize = 0;

    var kk = @as(u128, k);
    while (i < n) : (i += 1) {
        f = f / (n - i);
        var j = kk / f;
        kk -= j * f;
        j += i;
        const jidx = @intCast(usize, j);
        if (jidx >= a.len) return error.OutOfBoundsAccess;
        const elt = a[jidx];
        var d = jidx;
        while (d >= i + 1) : (d -= 1)
            a[d] = a[d - 1];
        a[i] = elt;
    }
}

const expecteds: []const []const u8 = &.{
    "ABCA",
    "ABAC",
    "ACBA",
    "ACAB",
    "AABC",
    "AACB",
    "BACA",
    "BAAC",
    "BCAA",
    "BCAA",
    "BAAC",
    "BACA",
    "CABA",
    "CAAB",
    "CBAA",
    "CBAA",
    "CAAB",
    "CABA",
    "AABC",
    "AACB",
    "ABAC",
    "ABCA",
    "ACAB",
    "ACBA",
};

test "nthperm" {
    const init = "ABCA";
    var buf: [4]u8 = undefined;

    for (expecteds) |expected, i| {
        std.mem.copy(u8, &buf, init);
        try nthperm(u8, &buf, i);
        try std.testing.expectEqualStrings(expected, &buf);
    }
}

pub fn Permutations(comptime T: type) type {
    return struct {
        i: usize,
        initial_state: []const u8,
        buf: []T,
        const Self = @This();

        pub fn init(initial_state: []const T, buf: []T) Self {
            return .{ .i = 0, .initial_state = initial_state, .buf = buf };
        }

        pub fn next(self: *Self) ?[]const T {
            std.mem.copy(u8, self.buf, self.initial_state);
            nthperm(u8, self.buf, self.i) catch return null;
            self.i += 1;
            return self.buf;
        }
    };
}

test "iterator" {
    var buf: [4]u8 = undefined;
    var it = Permutations(u8).init("ABCA", &buf);
    var i: u8 = 0;
    while (it.next()) |actual| : (i += 1) {
        const expected = expecteds[i];
        try std.testing.expectEqualStrings(expected, actual);
    }
}

// TODO: reenable this test after support larger sets by using big ints
test "edge cases" {
    if (true) return error.SkipZigTest;
    const initial_state = comptime blk: {
        var res: [fact_table_size + 1]u8 = undefined;
        for (res) |*r, i| r.* = i + 32;
        break :blk res;
    };
    var buf: [fact_table_size + 1]u8 = undefined;
    std.mem.copy(u8, &buf, &initial_state);
    try nthperm(u8, &buf, std.math.maxInt(u128));
}
