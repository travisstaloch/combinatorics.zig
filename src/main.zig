pub const permutations = @import("permutations.zig");
pub const combinations = @import("combinations.zig");
pub const misc = @import("misc.zig");

// TODO: export a c api

test "all" {
    comptime {
        _ = permutations;
        _ = combinations;
        _ = misc;
    }
}
