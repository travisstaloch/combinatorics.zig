const permutations = @import("permutations.zig");
const combinations = @import("combinations.zig");
const misc = @import("misc.zig");

// TODO: export a c api

test "all" {
    comptime {
        _ = permutations;
        _ = combinations;
        _ = misc;
    }
}

pub usingnamespace permutations;
pub usingnamespace combinations;
pub usingnamespace misc;
