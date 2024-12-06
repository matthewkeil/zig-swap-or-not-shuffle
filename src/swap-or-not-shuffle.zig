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
    InvalidSeedLength,
    InvalidActiveIndicesLength,
    InvalidNumberOfRounds,
};

fn hashFixed(data: []const u8) ![Sha256.digest_length]u8 {
    var sha256 = Sha256.init(.{});
    sha256.update(data);
    return sha256.finalResult();
}

/// A helper struct to manage the buffer used during shuffling.
const ShufflingManager = struct {
    buf: [TOTAL_SIZE]u8,

    pub fn init(seed: []const u8) !ShufflingManager {
        if (seed.len != SEED_SIZE) {
            return ShufflingErrorCode.InvalidSeedLength;
        }
        // TODO: @matthewkeil is there a way to avoid this copy here?
        var buf: [TOTAL_SIZE]u8 = [_]u8{0} ** TOTAL_SIZE;
        std.mem.copy(u8, buf[0..SEED_SIZE], seed);
        return ShufflingManager{ .buf = buf };
    }

    pub fn setRound(self: *ShufflingManager, round: u8) void {
        self.buf[SEED_SIZE] = round;
    }

    pub fn rawPivot(self: *const ShufflingManager) u64 {
        return std.mem.readInt(u64, hashFixed(self.buf[0..PIVOT_VIEW_SIZE]), .little);
    }

    pub fn mixInPosition(self: *ShufflingManager, position: usize) void {
        std.mem.copy(u8, self.buf[PIVOT_VIEW_SIZE..], @bitCast(position));
    }

    pub fn hash(self: *const ShufflingManager) [32]u8 {
        return hashFixed(self.buf[0..]);
    }
};

// pub fn shuffleList(
//     allocator: *std.mem.Allocator,
//     input: []const u32,
//     seed: []const u8,
//     rounds: i32,
//     forwards: bool,
// ) ![]u32 {
//     if (rounds < 0 or rounds > @as(i32, std.meta.maxValue(u8))) {
//         return ShufflingErrorCode.InvalidNumberOfRounds;
//     }

//     var list = try allocator.alloc(u32, input.len);
//     std.mem.copy(u32, list, input);

//     if (list.len <= 1) return list;

//     if (list.len > @as(usize, std.meta.maxValue(u32))) {
//         return ShufflingErrorCode.InvalidActiveIndicesLength;
//     }

//     var manager = try ShufflingManager.init(seed);

//     var currentRound: u8 = if (forwards) 0 else @truncate(u8, rounds - 1);

//     while (true) {
//         manager.setRound(currentRound);

//         const pivot = @mod(manager.rawPivot(), list.len);
//         var mirror = (pivot + 1) >> 1;

//         manager.mixInPosition(pivot >> 8);
//         var source = manager.hash();
//         var byteV = source[(pivot & 0xff) >> 3];

//         for (var i: usize = 0; i < mirror; i += 1) {
//             const j = pivot - i;

//             if ((j & 0xff) == 0xff) {
//                 manager.mixInPosition(j >> 8);
//                 source = manager.hash();
//             }

//             if ((j & 0x07) == 0x07) {
//                 byteV = source[(j & 0xff) >> 3];
//             }

//             const bitV = (byteV >> (j & 0x07)) & 0x01;
//             if (bitV == 1) {
//                 const temp = list[i];
//                 list[i] = list[j];
//                 list[j] = temp;
//             }
//         }

//         mirror = (pivot + list.len + 1) >> 1;
//         const end = list.len - 1;

//         manager.mixInPosition(end >> 8);
//         source = manager.hash();
//         byteV = source[(end & 0xff) >> 3];

//         for (var i = pivot + 1; i < mirror; i += 1) {
//             const j = end - (i - (pivot + 1));

//             if ((j & 0xff) == 0xff) {
//                 manager.mixInPosition(j >> 8);
//                 source = manager.hash();
//             }

//             if ((j & 0x07) == 0x07) {
//                 byteV = source[(j & 0xff) >> 3];
//             }

//             const bitV = (byteV >> (j & 0x07)) & 0x01;
//             if (bitV == 1) {
//                 const temp = list[i];
//                 list[i] = list[j];
//                 list[j] = temp;
//             }
//         }

//         if (forwards) {
//             currentRound += 1;
//             if (currentRound == @truncate(u8, rounds)) break;
//         } else {
//             if (currentRound == 0) break;
//             currentRound -= 1;
//         }
//     }

//     return list;
// }
