const std = @import("std");

const SPEC_TEST_DIR = "../../spec-tests/tests";
const SHUFFLING_TESTS_DIR = "phase0/shuffling/core/shuffle";
const TEST_SUITES = [_][]const u8{ "minimal", "mainnet" };

pub const FileMeta = struct {
    filepath: []const u8,
    filename: []const u8,
};

pub const ShuffleMapping = struct {
    seed: []const u8,
    count: u32,
    mapping: []u32,
};

pub const TestCase = struct {
    meta: FileMeta,
    mapping: ShuffleMapping,
};

/// Checks if a filename has a YAML extension (.yaml or .yml)
fn isYamlFile(filename: []const u8) bool {
    return (std.mem.endsWith(u8, filename, ".yaml") or
        std.mem.endsWith(u8, filename, ".yml"));
}

fn parseTestCaseYaml() ShuffleMapping {
    return ShuffleMapping{
        .seed = "example_seed",
        .count = 0,
        .mapping = &[_]u32{},
    };
}

pub fn getSpecsInFolder(
    yamlFiles: *std.ArrayList(TestCase),
    dirPath: []const u8,
) !void {
    // std.log.err("dirPath: {s}", .{dirPath});
    var directory = try std.fs.openDirAbsolute(dirPath, .{ .iterate = true });
    defer directory.close();

    var it = directory.iterate();
    while (try it.next()) |entry| {
        const entryPath = try std.fmt.allocPrint(yamlFiles.allocator, "{s}/{s}", .{ dirPath, entry.name });
        defer yamlFiles.allocator.free(entryPath);

        if (entry.kind == .file and isYamlFile(entry.name)) {
            const mapping = parseTestCaseYaml();

            try yamlFiles.append(TestCase{
                .meta = FileMeta{
                    .filepath = entryPath,
                    .filename = entry.name,
                },
                .mapping = mapping,
            });
        }
        // else if (entry.kind == .directory and !std.mem.eql(u8, entry.name, ".") and !std.mem.eql(u8, entry.name, "..")) {
        //     try collectTestCases(yamlFiles, entryPath);
        // }
    }
}
