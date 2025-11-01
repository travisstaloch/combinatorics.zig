const std = @import("std");

const bigint = std.math.big.int;

const fact_table_size_128 = 35;
const fact_table_size_64 = 21;

const fact_table64 =
    blk: {
        var tbl64: [fact_table_size_64]u64 = undefined;
        tbl64[0] = 1;
        var n: u64 = 1;
        while (n < fact_table_size_64) : (n += 1) {
            tbl64[n] = tbl64[n - 1] * n;
        }
        break :blk tbl64;
    };

const fact_table128 =
    blk: {
        var tbl128: [fact_table_size_128]u128 = undefined;
        tbl128[0] = 1;
        var n: u128 = 1;
        while (n < fact_table_size_128) : (n += 1) {
            tbl128[n] = tbl128[n - 1] * n;
        }
        break :blk tbl128;
    };

fn factorial(comptime T: type, n: anytype) !T {
    const TI = @typeInfo(T);
    return try switch (TI) {
        .int => if (TI.int.bits <= 64)
            factorialLookup(T, n, fact_table64, fact_table_size_64)
        else if (TI.int.bits <= 128)
            factorialLookup(T, n, fact_table128, fact_table_size_128)
        else
            @compileError("factorial not implemented for integer type " ++ @typeName(T)),
        else => @compileError("factorial not implemented for non-integer type " ++ @typeName(T)),
    };
}

fn factorialBig(n: anytype, allocator: std.mem.Allocator) !bigint.Managed {
    if (n > std.math.maxInt(usize)) return error.NTooBig;

    var result = try bigint.Managed.init(allocator);
    errdefer result.deinit();
    if (n < fact_table_size_128) {
        try result.set(fact_table128[n]);
    } else {
        var index = @as(usize, n);
        try result.set(fact_table128[fact_table_size_128 - 1]);
        var a = try bigint.Managed.init(allocator);
        defer a.deinit();
        while (index >= fact_table_size_128) : (index -= 1) {
            try a.set(index);
            try result.ensureMulCapacity(a.toConst(), result.toConst());
            try result.mul(&a, &result);
        }
    }
    return result;
}

fn factorialLookup(comptime T: type, n: anytype, table: anytype, limit: anytype) !T {
    if (n < 0) return error.Domain;
    if (n > limit) return error.Overflow;
    if (n >= table.len) return error.OutOfBoundsAccess;
    const f = table[@intCast(n)];
    return @intCast(f);
}

test "factorial" {
    inline for (.{
        .{ i8, 5, 120 },
        .{ u8, 5, 120 },
        .{ i16, 7, 5040 },
        .{ u16, 8, 40320 },
        .{ i32, 12, 479001600 },
        .{ u32, 12, 479001600 },
        .{ i64, 20, 2432902008176640000 },
        .{ u64, 20, 2432902008176640000 },
        .{ isize, 20, 2432902008176640000 },
        .{ usize, 20, 2432902008176640000 },
        .{ i128, 33, 8683317618811886495518194401280000000 },
        .{ u128, 34, 295232799039604140847618609643520000000 },
    }) |s| {
        const T = s[0];
        const max = s[1];
        const expected = s[2];
        const actual = try factorial(T, @as(usize, max));
        try std.testing.expectEqual(@as(T, expected), actual);
    }
}

test "factorialBig" {
    // from table
    {
        var f = try factorialBig(34, std.testing.allocator);
        defer f.deinit();
        try std.testing.expectEqual(fact_table128[fact_table_size_128 - 1], try f.toInt(u128));
    }

    // beyond table
    {
        const expected_factorials = .{
            .{ 35, 10333147966386144929666651337523200000000 },
            .{ 36, 371993326789901217467999448150835200000000 },
            .{ 37, 13763753091226345046315979581580902400000000 },
            .{ 38, 523022617466601111760007224100074291200000000 },
            .{ 39, 20397882081197443358640281739902897356800000000 },
            .{ 40, 815915283247897734345611269596115894272000000000 },
            .{ 41, 33452526613163807108170062053440751665152000000000 },
            .{ 42, 1405006117752879898543142606244511569936384000000000 },
            .{ 43, 60415263063373835637355132068513997507264512000000000 },
            .{ 44, 2658271574788448768043625811014615890319638528000000000 },
            .{ 45, 119622220865480194561963161495657715064383733760000000000 },
        };

        inline for (expected_factorials) |n_ex| {
            const N = n_ex[0];
            const EXPECTED = n_ex[1];
            var f = try factorialBig(N, std.testing.allocator);
            defer f.deinit();
            var expected = try bigint.Managed.initSet(std.testing.allocator, EXPECTED);
            defer expected.deinit();
            try std.testing.expect(expected.toConst().eql(f.toConst()));
        }
    }
}

// fn bench_factorialBig(allr: std.mem.Allocator) Ca.BenchmarkError(Error)!void {
//     var f = try factorialBig(55, allr);
//     defer f.deinit();
//     var expected = try bigint.Managed.initSet(
//         allr,
//         12696403353658275925965100847566516959580321051449436762275840000000000000,
//     );
//     defer expected.deinit();
//     const order = f.order(expected);
//     try std.testing.expect(order == .eq);
// }

// test "bench factorialBig" {
//     try Ca.benchmark(Error, bench_factorialBig, .us, std.debug.print);
// }

/// for sets of length 35 and less
pub fn nthperm(a: anytype, n: u128) !void {
    if (a.len == 0) return;

    var f = try factorial(u128, a.len);
    if (n > f) return error.ArgumentBounds;

    var i: usize = 0;
    var nmut = @as(u128, n);
    while (i < a.len) : (i += 1) {
        f = f / (a.len - i);
        var j = nmut / f;
        nmut -= j * f;
        j += i;
        const jidx: usize = @intCast(j);
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
    {
        const init = "ABCA";
        var buf = init.*;

        for (expecteds, 0..) |expected, i| {
            @memcpy(&buf, init);
            try nthperm(&buf, @intCast(i));
            try std.testing.expectEqualStrings(expected, &buf);
        }

        // n > (1 << buf.len) should error
        try std.testing.expectError(
            error.ArgumentBounds,
            nthperm(&buf, std.math.maxInt(u6)),
        );
    }

    {
        const init = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghi";
        try std.testing.expectEqual(35, init.len);
        var buf = init.*;
        try std.testing.expectError(error.OutOfBoundsAccess, nthperm(&buf, 1));
        // std.debug.print("init len {}\n", .{init.len});
        try nthperm(buf[0 .. buf.len - 1], 1 << init.len * 2);
    }
}

/// for sets of any size
pub fn nthpermBig(a: anytype, n: usize, allocator: std.mem.Allocator) !void {
    if (a.len == 0) return;

    var f = try factorialBig(a.len, allocator);
    var temp = try bigint.Managed.initSet(allocator, n);
    defer {
        f.deinit();
        temp.deinit();
    }
    if (f.toConst().order(temp.toConst()) != .gt) return error.ArgumentBounds;

    var nmut = try bigint.Managed.initSet(allocator, n);
    var j = try bigint.Managed.init(allocator);
    defer {
        nmut.deinit();
        j.deinit();
    }
    var i: usize = 0;
    while (i < a.len) : (i += 1) {
        // f = f / (a.len - i);
        try temp.set(a.len - i);
        try f.divTrunc(&temp, &f, &temp);
        // var j = nmut / f;
        if (f.eqlZero()) break;
        // std.log.debug("f {}", .{f});
        try j.divTrunc(&temp, &nmut, &f);

        // nmut -= j * f;
        try temp.set(try j.toInt(usize));
        try temp.ensureMulCapacity(temp.toConst(), f.toConst());
        try temp.mul(&temp, &f);
        try nmut.sub(&nmut, &temp);
        // j += i;
        try temp.set(i);
        try j.add(&j, &temp);
        const jidx = try j.toInt(usize);
        if (jidx >= a.len) return error.OutOfBoundsAccess;
        const elt = a[jidx];
        var d = jidx;
        while (d >= i + 1) : (d -= 1)
            a[d] = a[d - 1];
        a[i] = elt;
    }
}

const initial_state_big = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghij";

test "nthpermBig" {
    try std.testing.expectEqual(fact_table_size_128 + 1, initial_state_big.len);
    var buf = initial_state_big.*;
    try nthpermBig(&buf, std.math.maxInt(usize) - 1, std.testing.allocator);
    try std.testing.expectEqualStrings("ABCDEFGHIJKLMNOWbdTSjUYVaPhZfQRXgeci", &buf);

    // n > (1 << buf.len) should error
    try std.testing.expectError(
        error.ArgumentBounds,
        nthpermBig(buf[0..10], std.math.maxInt(usize), std.testing.allocator),
    );
}

// pub const Error = error{ OutOfBoundsAccess, ArgumentBounds, NTooBig } ||
//     std.math.big.int.Managed.ConvertError;
// const Ca = @import("CountingAllocator.zig");

// fn bench_nthpermBig(allr: std.mem.Allocator) Ca.BenchmarkError(Error)!void {
//     var xs: [256]u8 = undefined;
//     for (xs) |*x, i| x.* = @intCast(u8, i); // xs == 0..255
//     try nthpermBig(&xs, std.math.maxInt(usize) - 1, allr);
// }

// test "nthpermBig bench" {
//     try Ca.benchmark(Error, bench_nthpermBig, .us, std.debug.print);
// }

/// for sets of length 35 and less
pub fn Permutations(comptime T: type) type {
    return struct {
        i: usize,
        initial_state: []const T,
        /// must be at least as long as initial state.
        /// initial_state will be copied to this buffer each time next() is called.
        buf: []T,
        const Self = @This();

        pub fn init(initial_state: []const T, buf: []T) Self {
            return .{ .i = 0, .initial_state = initial_state, .buf = buf };
        }

        pub fn next(self: *Self) ?[]const T {
            @memcpy(self.buf[0..self.initial_state.len], self.initial_state);
            nthperm(self.buf[0..self.initial_state.len], @intCast(self.i)) catch return null;
            self.i += 1;
            return self.buf[0..self.initial_state.len];
        }
    };
}

test "Permutations iterator" {
    var buf: [4]u8 = undefined;
    var it = Permutations(u8).init("ABCA", &buf);
    var i: u8 = 0;
    while (it.next()) |actual| : (i += 1) {
        const expected = expecteds[i];
        try std.testing.expectEqualStrings(expected, actual);
    }
}

/// for sets of any size,
pub fn PermutationsBig(comptime T: type) type {
    return struct {
        i: usize,
        initial_state: []const T,
        buf: []T,
        allocator: std.mem.Allocator,
        const Self = @This();

        pub fn init(initial_state: []const T, buf: []T, allocator: std.mem.Allocator) Self {
            return .{ .i = 0, .initial_state = initial_state, .buf = buf, .allocator = allocator };
        }

        pub fn next(self: *Self) !?[]const T {
            @memcpy(self.buf, self.initial_state);
            try nthpermBig(self.buf, @intCast(self.i), self.allocator);
            self.i += 1;
            return self.buf;
        }
    };
}

const expecteds_big: []const []const u8 = &.{
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghij",
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghji",
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefgihj",
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefgijh",
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefgjhi",
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefgjih",
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefhgij",
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefhgji",
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefhigj",
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefhijg",
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefhjgi",
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefhjig",
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefighj",
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefigjh",
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefihgj",
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefihjg",
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefijgh",
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefijhg",
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefjghi",
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefjgih",
};

test "PermutationsBig iterator" {
    var buf = initial_state_big.*;

    var it = PermutationsBig(u8).init(initial_state_big, &buf, std.testing.allocator);
    var i: u8 = 0;
    while (try it.next()) |actual| : (i += 1) {
        const expected = expecteds_big[i];
        try std.testing.expectEqualStrings(expected, actual);
        if (i >= expecteds_big.len - 1) break;
    }
}
