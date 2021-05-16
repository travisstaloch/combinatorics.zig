const std = @import("std");

const bigint = std.math.big.int;

const fact_table_size_128 = 35;
const fact_table_size_64 = 21;

const fact_table64 =
    comptime blk: {
    var tbl64: [fact_table_size_64]u64 = undefined;
    tbl64[0] = 1;
    var n: u64 = 1;
    while (n < fact_table_size_64) : (n += 1) {
        tbl64[n] = tbl64[n - 1] * n;
    }
    break :blk tbl64;
};

const fact_table128 =
    comptime blk: {
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
        .Int => if (TI.Int.bits <= 64)
            factorialLookup(T, n, fact_table64, fact_table_size_64)
        else if (TI.Int.bits <= 128)
            factorialLookup(T, n, fact_table128, fact_table_size_128)
        else
            @compileError("factorial not implemented for integer type " ++ @typeName(T)),
        else => @compileError("factorial not implemented for type " ++ @typeName(T)),
    };
}

fn factorialBig(n: anytype, allocator: *std.mem.Allocator) !bigint.Managed {
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
            try result.mul(a.toConst(), result.toConst());
        }
    }
    return result;
}

fn factorialLookup(comptime T: type, n: anytype, table: anytype, limit: anytype) !T {
    if (n < 0) return error.Domain;
    if (n > limit) return error.Overflow;
    const TI = @typeInfo(T);
    const TUnsigned = std.meta.Int(.unsigned, std.math.min(TI.Int.bits, 64));
    const f = table[@intCast(TUnsigned, n)];
    return @intCast(T, f);
}

test "factorial" {
    inline for (.{
        .{ i8, 5 },
        .{ u8, 5 },
        .{ i16, 7 },
        .{ u16, 8 },
        .{ i32, 12 },
        .{ u32, 12 },
        .{ i64, 20 },
        .{ u64, 20 },
        .{ isize, 20 },
        .{ usize, 20 },
        .{ i128, 33 },
        .{ u128, 34 },
    }) |s| {
        const T = s[0];
        const max = s[1];
        const f = try factorial(T, @as(usize, max));
    }
}

test "factorialBig" {
    // from table
    {
        var f = try factorialBig(34, std.testing.allocator);
        defer f.deinit();
        try std.testing.expectEqual(fact_table128[fact_table_size_128 - 1], try f.to(u128));
    }
    // beyond table
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

    inline for (expected_factorials) |n_expected_fact| {
        const N = n_expected_fact[0];
        const EXPECTED = n_expected_fact[1];
        var f = try factorialBig(N, std.testing.allocator);
        defer f.deinit();
        var expected = try bigint.Managed.initSet(std.testing.allocator, EXPECTED);
        defer expected.deinit();
        try std.testing.expect(expected.toConst().eq(f.toConst()));
    }
}

pub fn nthperm(a: anytype, n: u6) !void {
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
        try nthperm(&buf, @intCast(u6, i));
        try std.testing.expectEqualStrings(expected, &buf);
    }

    // n > (1 << buf.len) should error
    try std.testing.expectError(
        error.ArgumentBounds,
        nthperm(&buf, std.math.maxInt(u6)),
    );
}

pub fn nthpermBig(a: anytype, n: usize, allocator: *std.mem.Allocator) !void {
    if (a.len == 0) return;

    var f = try factorialBig(a.len, allocator);

    var temp = try bigint.Managed.initSet(allocator, n);
    defer {
        f.deinit();
        temp.deinit();
    }
    if (f.toConst().order(temp.toConst()) != .gt) return error.ArgumentBounds;

    var i: usize = 0;

    var nmut = try bigint.Managed.initSet(allocator, n);
    var j = try bigint.Managed.init(allocator);
    defer {
        nmut.deinit();
        j.deinit();
    }
    while (i < a.len) : (i += 1) {
        // f = f / (a.len - i);
        try temp.set(a.len - i);
        try f.divTrunc(&temp, f.toConst(), temp.toConst());
        // var j = nmut / f;
        try j.divTrunc(&temp, nmut.toConst(), f.toConst());

        // nmut -= j * f;
        try temp.set(try j.to(usize));
        try temp.ensureMulCapacity(temp.toConst(), f.toConst());
        try temp.mul(temp.toConst(), f.toConst());
        try nmut.sub(nmut.toConst(), temp.toConst());
        // j += i;
        try temp.set(i);
        try j.add(j.toConst(), temp.toConst());
        const jidx = try j.to(usize);
        if (jidx >= a.len) return error.OutOfBoundsAccess;
        const elt = a[jidx];
        var d = jidx;
        while (d >= i + 1) : (d -= 1)
            a[d] = a[d - 1];
        a[i] = elt;
    }
}

test "nthpermBig" {
    const initial_state = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghij";
    try std.testing.expectEqual(fact_table_size_128 + 1, initial_state.len);
    var buf = initial_state.*;
    try nthpermBig(&buf, std.math.maxInt(usize) - 1, std.testing.allocator);
    try std.testing.expectEqualStrings("ABCDEFGHIJKLMNOWbdTSjUYVaPhZfQRXgeci", &buf);

    // n > (1 << buf.len) should error
    try std.testing.expectError(
        error.ArgumentBounds,
        nthpermBig(buf[0..10], std.math.maxInt(usize), std.testing.allocator),
    );
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
            nthperm(self.buf, @intCast(u6, self.i)) catch return null;
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
