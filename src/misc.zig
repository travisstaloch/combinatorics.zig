const std = @import("std");

/// There are n choose k ways to choose k elements from a set of n elements.
/// This iterator produces a binary representation of which k elements are chosen
/// calling `next()` on `NChooseK(u8).init(3,2)` will produce {0b011, 0b101, 0b110, null}
pub fn NChooseK(comptime T: type) type {
    return struct {
        n: TLog2,
        k: TLog2,
        set: T,
        limit: T,

        const Self = @This();
        const TSigned = std.meta.Int(.signed, @typeInfo(T).Int.bits);
        const TLog2 = std.math.Log2Int(T);

        /// n: total number of elements in set
        /// k: number of elements to choose (number of set bits at any point after calling `next()`)
        pub fn init(n: TLog2, k: TLog2) !Self {
            if (n == 0 or k > n) return error.ArgumentBounds;
            return Self{
                .k = k,
                .n = n,
                .set = (@as(T, 1) << @intCast(TLog2, k)) - 1,
                .limit = @as(T, 1) << @intCast(TLog2, n),
            };
        }

        pub fn next(self: *Self) ?T {
            // save and return the set at this point otherwise initial set is skipped
            const result = self.set;
            // prevent overflow when converting to signed
            if (self.set >= std.math.maxInt(TSigned)) return null;
            // compute next set value
            const c = self.set & @bitCast(T, -@bitCast(TSigned, self.set));
            if (c == 0) return null;
            const r = self.set + c;
            self.set = @divFloor(((r ^ self.set) >> 2), c) | r;
            return if (result >= self.limit) null else result;
        }
    };
}

test "basic" {
    const expecteds_bycount = [_][]const usize{
        &.{ 0b01, 0b10 }, // n,k: 2,1
        &.{ 0b011, 0b101, 0b110 }, // 3,2
        &.{ 0b0111, 0b1011, 0b1101, 0b1110 }, // 4,3
        &.{ 0b01111, 0b10111, 0b11011, 0b11101, 0b11110 }, // 5,4
        &.{ 0b011111, 0b101111, 0b110111, 0b111011, 0b111101, 0b111110 }, // 6,5
    };
    for (expecteds_bycount) |expecteds, count_| {
        const count = @intCast(u6, count_);
        var it = try NChooseK(usize).init(count + 2, count + 1);
        for (expecteds) |expected, i| {
            const actual = it.next().?;
            try std.testing.expectEqual(expected, actual);
        }
        try std.testing.expectEqual(@as(?usize, null), it.next());
    }
}

test "edge cases" {
    // n == 0
    try std.testing.expectError(error.ArgumentBounds, NChooseK(usize).init(0, 1));
    // k > n
    try std.testing.expectError(error.ArgumentBounds, NChooseK(usize).init(1, 2));

    // sanity check various types making sure x is always valid
    const Ts = [_]type{ u3, u8, u16, u64, u65, u128 };
    inline for (Ts) |T| {
        var it = try NChooseK(T).init(std.math.log2_int(T, std.math.maxInt(T)), 1);
        while (it.next()) |x| {
            try std.testing.expect(@popCount(T, x) == 1);
        }
    }
}
