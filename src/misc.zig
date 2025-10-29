const std = @import("std");

/// There are n choose k ways to choose k elements from a set of n elements.
/// This iterator produces a binary representation of which k elements are chosen
/// calling `next()` on `NChooseK(u8).init(3,2)` will produce {0b011, 0b101, 0b110, null}
pub fn NChooseK(comptime T: type) type {
    // this method is known as 'Gosper's Hack': http://programmingforinsomniacs.blogspot.com/2018/03/
    return struct {
        /// n: total number of elements in set
        n: TLog2,
        /// k: number of elements to choose (number of set bits at any point after calling `next()`)
        k: TLog2,
        set: T,
        limit: T,

        const Self = @This();
        const TSigned = std.meta.Int(.signed, @typeInfo(T).int.bits);
        const TLog2 = std.math.Log2Int(T);

        pub fn init(n: TLog2, k: TLog2) !Self {
            if (n == 0 or k > n) return error.ArgumentBounds;
            return Self{
                .k = k,
                .n = n,
                .set = (@as(T, 1) << @intCast(k)) - 1,
                .limit = @as(T, 1) << @intCast(n),
            };
        }

        pub fn next(self: *Self) ?T {
            // save and return the set at this point otherwise initial set is skipped
            const result = self.set;
            // prevent overflow when converting to signed
            if (self.set >= std.math.maxInt(TSigned)) return null;
            // compute next set value
            // c is equal to the rightmost 1-bit in set.
            const c = self.set & @as(T, @bitCast(-@as(TSigned, @bitCast(self.set))));
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
    for (expecteds_bycount, 0..) |expecteds, count_| {
        const count: u6 = @intCast(count_);
        var it = try NChooseK(usize).init(count + 2, count + 1);
        for (expecteds) |expected| {
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
            try std.testing.expect(@popCount(x) == 1);
        }
    }
}

const bigint = std.math.big.int;

pub const NChooseKBig = struct {
    /// n: total number of elements in set
    n: usize,
    /// k: number of elements to choose (number of set bits at any point after calling `next()`)
    k: usize,
    set: bigint.Managed,
    limit: bigint.Managed,

    pub fn init(allocator: std.mem.Allocator, n: usize, k: usize) !NChooseKBig {
        if (n == 0 or k > n) return error.ArgumentBounds;
        // set = 1 <<  k - 1;
        var set = try bigint.Managed.initSet(allocator, 1);
        try set.shiftLeft(&set, k);
        try set.addScalar(&set, -1);

        // limit = 1 <<  n;
        var limit = try bigint.Managed.initSet(allocator, 1);
        try limit.shiftLeft(&limit, n);
        return NChooseKBig{
            .k = k,
            .n = n,
            .set = set,
            .limit = limit,
        };
    }

    pub fn deinit(self: *NChooseKBig) void {
        self.set.deinit();
        self.limit.deinit();
    }

    pub fn next(self: *NChooseKBig, result: *bigint.Managed) !?void {
        // TODO: figure out how to eliminate some allocations

        // save for return at end the set at this point otherwise initial set is skipped
        result.* = try self.set.clone();
        // int c = set & -set; // c is equal to the rightmost 1-bit in set.
        var c = try self.set.clone();
        defer c.deinit();
        for (c.limbs[0..c.len()], 0..) |limb, i| {
            // prevent overflow here. 1 << 63 is std.math.maxInt(isize) + 1.
            // if we try to negate this value, overflow will happen.
            // in this case we know the leftmost 1-bit is just 1 << 63
            const x = if (limb == 1 << 63)
                1 << 63
            else
                limb & @as(usize, @bitCast(-@as(isize, @bitCast(limb))));
            if (x > 0) {
                try c.set(0);
                c.limbs[i] = x;
                c.setLen(i + 1);
                break;
            }
        }

        try c.bitAnd(&self.set, &c);

        // this check for c == 0 may not be necessary.
        // going to leave this here commented out incase of future problems.
        // if (c.eqZero()) {
        //     result.deinit();
        //     return null;
        // }

        // const r = self.set + c;
        // Find the rightmost 1-bit that can be moved left into a 0-bit. Move it left one.
        var r = try bigint.Managed.init(self.set.allocator);
        defer r.deinit();
        try r.add(&self.set, &c);
        // set = (((r ^ set) >> 2) / c) | r;
        var tmp = try bigint.Managed.init(self.set.allocator);
        defer tmp.deinit();
        // Xor’ng r and set returns a cluster of 1-bits representing the bits that were changed between set and r
        try tmp.bitXor(&r, &self.set);
        try tmp.shiftRight(&tmp, 2);
        var rem = try bigint.Managed.init(self.set.allocator);
        // rem must be able to hold this many limbs or else divFloor below may fail
        try rem.ensureCapacity(tmp.len() + 1);
        defer rem.deinit();
        // work around for result location bug (i think?) make a copy of tmp
        // WARNING: do not remove tmp2. strange things will happen.  the following division will produce
        // something very strange, 101010.... when dividing 111111... by 1.  possibly garbage.
        var tmp2 = try tmp.clone();
        defer tmp2.deinit();
        try tmp.divFloor(&rem, &tmp2, &c);
        try self.set.bitOr(&tmp, &r);
        const order = result.order(self.limit);

        if (order == .gt or order == .eq) {
            result.deinit();
            return null;
        }
    }
};

test "basic big" {
    const expecteds_bycount = [_][]const usize{
        &.{ 0b01, 0b10 }, // n,k: 2,1
        &.{ 0b011, 0b101, 0b110 }, // 3,2
        &.{ 0b0111, 0b1011, 0b1101, 0b1110 }, // 4,3
        &.{ 0b01111, 0b10111, 0b11011, 0b11101, 0b11110 }, // 5,4
        &.{ 0b011111, 0b101111, 0b110111, 0b111011, 0b111101, 0b111110 }, // 6,5
    };
    for (expecteds_bycount, 0..) |expecteds, count| {
        var it = try NChooseKBig.init(std.testing.allocator, count + 2, count + 1);
        defer it.deinit();
        for (expecteds) |expected| {
            var actual: bigint.Managed = undefined;
            _ = (try it.next(&actual)).?;
            defer actual.deinit();

            try std.testing.expectEqual(expected, try actual.toInt(usize));
        }
        var dummy: bigint.Managed = undefined;
        try std.testing.expectEqual(@as(?void, null), try it.next(&dummy));
    }
}

test "256" {
    const count = 256;
    var it = try NChooseKBig.init(std.testing.allocator, count, count - 1);
    defer it.deinit();
    var i: usize = 0;
    var n: bigint.Managed = undefined;
    while (try it.next(&n)) |_| : (i += 1) {
        n.deinit();
    }
    try std.testing.expectEqual(@as(usize, count), i);
}

pub const Error = error{ OutOfBoundsAccess, ArgumentBounds, NTooBig } ||
    std.math.big.int.Managed.ConvertError;

// fn bench_NChooseKBig(allr: std.mem.Allocator) Ca.BenchmarkError(Error)!void {
//     return error.NotImplemented;
// }

// test "bench NChooseKBig" {
//     try Ca.benchmark(Error, bench_NChooseKBig, .us, std.debug.print);
// }
