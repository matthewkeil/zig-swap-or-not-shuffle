const std = @import("std");
const yaml = @import("yaml");
const swapOrNotShuffle = @import("swap-or-not-shuffle");
const specTestUtils = @import("./utils/collectSpectTests.zig");
const TestCase = specTestUtils.TestCase;
const collectTestCases = specTestUtils.collectTestCases;

test "spec tests" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var testCases = std.ArrayList(TestCase).init(allocator);
    defer testCases.deinit();

    const CWD = try std.fs.cwd().realpathAlloc(allocator, ".");
    defer allocator.free(CWD);

    for (TEST_SUITES) |suite| {
        const directory = try std.fs.path.resolve(allocator, &.{
            CWD,
            std.fs.path.dirname(@src().file) orelse ".",
            SPEC_TEST_DIR,
            suite,
            SHUFFLING_TESTS_DIR,
        });
        defer allocator.free(directory);
        try collectTestCases(&testCases, directory);
    }

    for (testCases.items, 0..) |testCase, i| {
        std.log.debug("TestCase {d} - filename: {s}, filepath: {s}", .{ i, testCase.meta.filename, testCase.meta.filepath });
    }
}
