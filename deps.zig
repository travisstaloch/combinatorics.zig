const std = @import("std");
pub const pkgs = struct {
    pub fn addAllTo(artifact: *std.build.LibExeObjStep) void {
        @setEvalBranchQuota(1_000_000);
        inline for (comptime std.meta.declarations(exports)) |decl| {
            if (decl.is_pub) {
                artifact.addPackage(@field(exports, decl.name));
            }
        }
    }
};

pub const exports = struct {
    pub const combinatorics = std.build.Pkg{
        .name = "combinatorics",
        .source = .{ .path = "src/main.zig" },
        .dependencies = &.{},
    };
};
pub const base_dirs = struct {};
