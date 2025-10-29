# combinatorics.zig

An incomplete port of Julia's [combinatorics library](https://github.com/JuliaMath/Combinatorics.jl) along with miscellaneous related tools.

__WARNING__ This library is very immature, untested and may have bugs.  Use at your own risk.

This library provides itertors over set permutations and combinations.  It also provides an [`NChooseK`](src/misc.zig) iterator.  `Combination` set sizes are limited to 127.  `Permutations` and `nthperm` set sizes are limited to 34.  For larger set sizes use `nthpermBig`, `PermutationsBig`, `NChooseKBig` and `CombinationsBig`.  


# use

```
$ zig fetch --save git+https://github.com/travisstaloch/combinatorics.zig
```
```zig
// build.zig
const mod = b.createModule(.{
    .root_source_file = b.path("src/root.zig"),
    .target = target,
    .imports = &.{
        .{
            .name = "combinatorics",
            .module = b.dependency("combinatorics", .{ .target = target, .optimize = optimize }).module("combinatorics"),
        },
    },
});
```

## run tests
To test this project
```console
zig build test
```

## examples
look at the tests in [permutations.zig](src/permutations.zig), [combinations.zig](src/combinations.zig) and [misc.zig](src/misc.zig).  Tests are usually found at the bottom of the files or directly after the thing they're testing.  


# todo
- export a c api
- support larger sets by using big integers
  - [x] nthpermBig and PermutationsBig
  - [x] NChooseKBig and CombinationsBig
