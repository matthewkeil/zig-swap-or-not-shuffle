const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseFast });

    const swap_or_not = b.addStaticLibrary(.{
        .name = "swap-or-not-shuffle",
        .root_source_file = b.path("src/swap-or-not-shuffle.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(swap_or_not);
    const swapOrNotShuffleModule = b.addModule("swap-or-not-shuffle", .{ .root_source_file = b.path("src/swap-or-not-shuffle.zig") });

    const lib_spec_tests = b.addTest(.{
        .root_source_file = b.path("test/spec/test.spec.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib_spec_tests.root_module.addImport("swap-or-not-shuffle", swapOrNotShuffleModule);
    const yamlDep = b.dependency("yaml", .{
        .target = target,
        .optimize = optimize,
    });
    lib_spec_tests.root_module.addImport("yaml", yamlDep.module("yaml"));

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(b.getInstallStep());
    const run_lib_unit_tests = b.addRunArtifact(lib_spec_tests);
    test_step.dependOn(&run_lib_unit_tests.step);
}
