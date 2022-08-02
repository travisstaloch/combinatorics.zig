const std = @import("std");

const CountingAllocator = @This();

const Allocator = std.mem.Allocator;

const Timed = struct {
    num: usize = 0,
    time: usize = 0,
};

allocator: Allocator,
parent_allocator: *Allocator,
bytes_used: usize = 0,
max_bytes_used: usize = 0,
allocs: Timed = .{},
frees: Timed = .{},
shrinks: Timed = .{},
expands: Timed = .{},
failures: Timed = .{},
timer: std.time.Timer,
total_time: usize = 0,

pub fn init(parent_allocator: *Allocator, timer: std.time.Timer) CountingAllocator {
    return CountingAllocator{
        .allocator = Allocator{
            .allocFn = alloc,
            .resizeFn = resize,
        },
        .parent_allocator = parent_allocator,
        .timer = timer,
    };
}

fn alloc(allocator: *Allocator, len: usize, ptr_align: u29, len_align: u29, ra: usize) error{OutOfMemory}![]u8 {
    const self = @fieldParentPtr(CountingAllocator, "allocator", allocator);
    self.timer.reset();
    defer self.total_time += self.timer.read();
    const result = self.parent_allocator.allocFn(self.parent_allocator, len, ptr_align, len_align, ra);
    if (result) |buff| {
        self.allocs.time += self.timer.read();
        self.allocs.num += 1;
        self.bytes_used += len;
        self.max_bytes_used = std.math.max(self.bytes_used, self.max_bytes_used);
    } else |err| {
        self.failures.time += self.timer.read();
        self.failures.num += 1;
    }
    return result;
}

fn resize(allocator: *Allocator, buf: []u8, buf_align: u29, new_len: usize, len_align: u29, ra: usize) error{OutOfMemory}!usize {
    const self = @fieldParentPtr(CountingAllocator, "allocator", allocator);
    self.timer.reset();
    defer self.total_time += self.timer.read();
    if (self.parent_allocator.resizeFn(self.parent_allocator, buf, buf_align, new_len, len_align, ra)) |resized_len| {
        if (new_len == 0) {
            // free
            self.frees.time += self.timer.read();
            self.frees.num += 1;
            self.bytes_used -= buf.len;
        } else if (new_len <= buf.len) {
            // shrink
            self.shrinks.time += self.timer.read();
            self.shrinks.num += 1;
            self.bytes_used -= buf.len - new_len;
        } else {
            // expand
            self.expands.time += self.timer.read();
            self.expands.num += 1;
            self.bytes_used += new_len - buf.len;
            self.max_bytes_used = std.math.max(self.bytes_used, self.max_bytes_used);
        }
        return resized_len;
    } else |e| {
        std.debug.assert(new_len > buf.len);
        self.failures.time += self.timer.read();
        self.failures.num += 1;
        return e;
    }
}

fn printTimed(
    timed: Timed,
    name: []const u8,
    precision: Precision,
    comptime printfn: fn (comptime fmt: []const u8, args: anytype) void,
) void {
    printfn("{s: <15}{}:{}{s} (avg {d:.1}{s})\n", .{
        name,
        timed.num,
        timed.time / precision.divisor(),
        precision.toString(),
        if (timed.num != 0)
            @intToFloat(f32, timed.time / precision.divisor()) / @intToFloat(f32, timed.num)
        else
            0,
        precision.toString(),
    });
}

pub fn printSummary(
    ca: CountingAllocator,
    precision: Precision,
    comptime printfn: fn (comptime fmt: []const u8, args: anytype) void,
) void {
    printfn("\n{s: <15}{}\n", .{ "bytes_used", ca.bytes_used });
    printfn("{s: <15}{}\n", .{ "max_bytes_used", ca.max_bytes_used });
    printTimed(ca.allocs, "allocs", precision, printfn);
    printTimed(ca.frees, "frees", precision, printfn);
    printTimed(ca.shrinks, "shrinks", precision, printfn);
    printTimed(ca.expands, "expands", precision, printfn);
    printTimed(ca.failures, "failures", precision, printfn);
    printfn("total_time {}{s}\n", .{ ca.total_time / precision.divisor(), precision.toString() });
}

const TestingError = error{
    TestUnexpectedResult,
    TestExpectedEqual,
    TestExpectedError,
    TestUnexpectedError,
    TestExpectedFmt,
    TestExpectedApproxEqAbs,
    TestExpectedApproxEqRel,
};

pub fn BenchmarkError(comptime Error: type) type {
    return std.mem.Allocator.Error ||
        std.time.Timer.Error ||
        TestingError ||
        Error;
}

pub const Precision = enum {
    s,
    ms,
    us,
    ns,
    pub fn divisor(precision: Precision) usize {
        return switch (precision) {
            .s => std.time.ns_per_s,
            .ms => std.time.ns_per_ms,
            .us => std.time.ns_per_us,
            .ns => 1,
        };
    }
    pub fn toString(precision: Precision) []const u8 {
        return switch (precision) {
            .s => "s",
            .ms => "ms",
            .us => "μs",
            .ns => "ns",
        };
    }
};

pub fn benchmark(
    comptime Error: type,
    f: fn (*std.mem.Allocator) BenchmarkError(Error)!void,
    precision: Precision,
    printfn: fn (comptime fmt: []const u8, args: anytype) void,
) !void {
    var timer = try std.time.Timer.start();
    var counting_allr = CountingAllocator.init(std.testing.allocator, timer);
    try f(&counting_allr.allocator);
    counting_allr.printSummary(precision, printfn);
}
