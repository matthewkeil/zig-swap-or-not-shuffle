const std = @import("std");
const swapOrNotShuffle = @import("swap-or-not-shuffle");
const yaml = @import("yaml");

const SPEC_TEST_DIR = "../../spec-tests";
const SHUFFLING_TESTS_DIR = "phase0/shuffling/core/shuffle";
const TEST_SUITES = .{ "minimal", "mainnet" };

const FileMeta = struct {
    filepath: []const u8,
    filename: []const u8,
};

const ShuffleMapping = struct {
    seed: []const u8,
    count: u32,
    mapping: []u32,
};

const TestCase = struct {
    meta: FileMeta,
    mapping: ShuffleMapping,
};

/// Checks if a filename has a YAML extension (.yaml or .yml)
fn isYamlFile(filename: []const u8) bool {
    return (std.mem.endsWith(u8, filename, ".yaml") or
        std.mem.endsWith(u8, filename, ".yml"));
}

fn parseTestCaseYaml() ShuffleMapping {
    const mapping: ShuffleMapping = .{ .seed = "", .count = 0, .mapping = {} };
    return mapping;
}

fn collectTestCases(yamlFiles: *std.ArrayList(FileMeta), dirPath: []const u8) !void {
    const directory = try std.fs.cwd().openDir(dirPath, .{});
    defer directory.close();

    var it = directory.iterate();
    while (try it.next()) |entry| {
        const entryPath = std.fmt.allocPrint(yamlFiles.allocator(), "{}/{}", dirPath, entry.name) catch continue;

        if (entry.kind == .File and isYamlFile(entry.name)) {
            const mapping = parseTestCaseYaml();

            try yamlFiles.append(TestCase{
                .meta = FileMeta{
                    .filepath = entryPath,
                    .filename = entry.name,
                },
                .mapping = mapping,
            });
        } else if (entry.kind == .Directory and !std.mem.eql(u8, entry.name, ".") and !std.mem.eql(u8, entry.name, "..")) {
            try collectTestCases(yamlFiles, entryPath);
        }
    }
}

test "spec tests" {
    const gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const testCases = std.ArrayList(TestCase).init(allocator);

    for (TEST_SUITES) |suite| {
        const directory = SPEC_TEST_DIR ++ "/" ++ suite ++ "/" ++ SHUFFLING_TESTS_DIR;
        collectTestCases(testCases, directory);
    }

    for (testCases.items, 0..) |testCase, i| {
        std.log.info("TestCase {} - filename: {}, filepath: {}", .{ i, testCase.meta.filename, testCase.meta.filepath });
    }
}
