# combinatorics.zig

An incomplete port of Julia's [combinatorics library](https://github.com/JuliaMath/Combinatorics.jl) along with miscellaneous related tools.

__WARNING__ This library is very immature, untested and may have bugs.  Use at your own risk.

This library provides itertors over set permutations and combinations.  It also provides an [`NChooseK`](src/misc.zig) iterator.  `Combination` set sizes are limited to 127.  `Permutations` and `nthperm` set sizes are limited to 34.  For larger set sizes use `nthpermBig`, `PermutationsBig`, `NChooseKBig` and `CombinationsBig`.  


# usage


## get source 

### via [gyro](https://github.com/mattnite/gyro) package manager

- in console
  - `$ gyro add --src github travisstaloch/combinatorics.zig`
- in build.zig
  - `const pkgs = @import("gyro").pkgs;`
  - `pkgs.addAllTo(exe/lib/tests);`

### otherwise 

copy relevent files from src/ into your project or `git submodule` the entire project.


## run tests
To test this project
```console
zig build test
```

Or with gyro
```console
gyro build test
```


## examples
look at the tests in [permutations.zig](src/permutations.zig), [combinations.zig](src/combinations.zig) and [misc.zig](src/misc.zig).  Tests are usually found at the bottom of the files or directly after the thing they're testing.  


# todo
- export a c api
- support larger sets by using big integers
  - [x] nthpermBig and PermutationsBig
  - [x] NChooseKBig and CombinationsBig