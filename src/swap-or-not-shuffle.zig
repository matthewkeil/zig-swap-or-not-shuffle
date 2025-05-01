const std = @import("std");
const Sha256 = std.crypto.hash.sha2.Sha256;

pub const SHUFFLE_ROUNDS_MINIMAL: u32 = 10;
pub const SHUFFLE_ROUNDS_MAINNET: u32 = 90;

const SEED_SIZE: usize = 32;
const ROUND_SIZE: usize = 1;
const POSITION_WINDOW_SIZE: usize = 4;
const PIVOT_VIEW_SIZE = SEED_SIZE + ROUND_SIZE;
const TOTAL_SIZE = SEED_SIZE + ROUND_SIZE + POSITION_WINDOW_SIZE;

pub const ShufflingErrorCode = error{
    InvalidActiveIndicesLength,
};

fn hashFixed(data: []const u8) [Sha256.digest_length]u8 {
    var sha256 = Sha256.init(.{});
    sha256.update(data);
    return sha256.finalResult();
}

/// A helper struct to manage the buffer used during shuffling.
const ShufflingManager = struct {
    buf: [TOTAL_SIZE]u8,

    pub fn init(seed: [SEED_SIZE]u8) ShufflingManager {
        // TODO: @matthewkeil is there a way to avoid this copy here?
        var buf: [TOTAL_SIZE]u8 = [_]u8{0} ** TOTAL_SIZE;
        std.mem.copyForwards(u8, buf[0..SEED_SIZE], &seed);
        return ShufflingManager{ .buf = buf };
    }

    pub fn setRound(self: *ShufflingManager, round: u8) void {
        self.buf[SEED_SIZE] = round;
    }

    pub fn rawPivot(self: *const ShufflingManager) u64 {
        return std.mem.readInt(u64, hashFixed(self.buf[0..PIVOT_VIEW_SIZE])[0..8], .little);
    }

    pub fn mixInPosition(self: *ShufflingManager, position: usize) void {
        var position_bytes: [POSITION_WINDOW_SIZE]u8 = undefined;
        std.mem.writeInt(u32, &position_bytes, @intCast(position), .little);
        std.mem.copyForwards(u8, self.buf[PIVOT_VIEW_SIZE..], &position_bytes);
    }

    pub fn hash(self: *const ShufflingManager) [32]u8 {
        return hashFixed(self.buf[0..]);
    }
};

pub fn innerShuffleList(
    input: []u32,
    seed: [SEED_SIZE]u8,
    rounds: u8,
    forwards: bool,
) ShufflingErrorCode![]u32 {
    if (input.len <= 1) return input;

    if (input.len > @as(usize, std.math.maxInt(u32))) {
        return ShufflingErrorCode.InvalidActiveIndicesLength;
    }

    var manager = ShufflingManager.init(seed);

    var currentRound: u8 = if (forwards) 0 else @truncate(rounds - 1);

    while (true) {
        manager.setRound(currentRound);

        const pivot = @mod(manager.rawPivot(), input.len);
        var mirror = (pivot + 1) >> 1;

        manager.mixInPosition(pivot >> 8);
        var source = manager.hash();
        var byteV = source[(pivot & 0xff) >> 3];

        var i: usize = 0;
        while (i < mirror) {
            const j = pivot - i;

            if ((j & 0xff) == 0xff) {
                manager.mixInPosition(j >> 8);
                source = manager.hash();
            }

            if ((j & 0x07) == 0x07) {
                byteV = source[(j & 0xff) >> 3];
            }

            const bitV = (byteV >> (@as(u3, @truncate(j)) & 0x07)) & 0x01;
            if (bitV == 1) {
                const temp = input[i];
                input[i] = input[j];
                input[j] = temp;
            }

            i += 1;
        }

        mirror = (pivot + input.len + 1) >> 1;
        const end = input.len - 1;

        manager.mixInPosition(end >> 8);
        source = manager.hash();
        byteV = source[(end & 0xff) >> 3];

        i = pivot + 1;
        while (i < mirror) {
            const j = end - (i - (pivot + 1));

            if ((j & 0xff) == 0xff) {
                manager.mixInPosition(j >> 8);
                source = manager.hash();
            }

            if ((j & 0x07) == 0x07) {
                byteV = source[(j & 0xff) >> 3];
            }

            const bitV = (byteV >> (@as(u3, @truncate(j)) & 0x07)) & 0x01;
            if (bitV == 1) {
                const temp = input[i];
                input[i] = input[j];
                input[j] = temp;
            }

            i += 1;
        }

        if (forwards) {
            currentRound += 1;
            if (currentRound == rounds) break;
        } else {
            if (currentRound == 0) break;
            currentRound -= 1;
        }
    }

    return input;
}

pub fn unshuffleList(input: []u32, seed: [32]u8, rounds: u8) ShufflingErrorCode![]u32 {
    return innerShuffleList(input, seed, rounds, false);
}

test "unshuffleList" {
    // calculated using the reference implementation (@chainsafe/swap-or-not-shuffle)
    var input = [_]u32{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 };
    const seed = [_]u8{0} ** SEED_SIZE;
    const rounds = 10;
    const expected = [_]u32{
        9, 5, 7, 4, 1,
        3, 0, 8, 2, 6,
    };

    const result = try unshuffleList(&input, seed, rounds);
    try std.testing.expectEqualSlices(u32, &expected, result);
}
