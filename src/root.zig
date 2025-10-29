pub const permutations = @import("permutations.zig");
pub const combinations = @import("combinations.zig");
const misc = @import("misc.zig");

// TODO: export a c api

test {
    _ = permutations;
    _ = combinations;
    _ = misc;
}
