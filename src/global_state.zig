const std = @import("std");
const config = @import("config.zig");
pub usingnamespace config;
const Genome = @import("genome.zig").Genome;
pub const Creature = @import("Creature.zig");
pub const Position = Creature.Position;

pub const Creatures = [config.max_creature_count]Creature;
pub const Food = struct {
    x: Position,
    y: Position,
};
pub const Foods = [config.max_food_count]Food;

pub var creatures: Creatures = undefined;
pub var creatures_len: usize = 0;
pub var foods: Foods = undefined;
pub var foods_len: usize = 0;

pub const GenomeWithFitness = struct {
    genome: Genome,
    fitness: u64,
};
pub var most_fitting_genomes = [_]?GenomeWithFitness{null} ** config.max_fitting_genomes;
pub var most_fitting_genomes_len: usize = 0;

pub const GameFile = struct {
    count: usize = 0,
    genomes: [config.max_fitting_genomes]GenomeWithFitness = undefined,
    pub fn set() GameFile {
        var file = GameFile{};
        for (most_fitting_genomes[0..most_fitting_genomes_len], 0..) |genome, i| file.genomes[i] = genome.?;
        return file;
    }
};

pub var rand: std.rand.Xoshiro256 = undefined;
pub var seed: u64 = 0;

pub fn IteratorOnPosition(comptime array: anytype, comptime curr_len: *usize) type {
    return struct {
        index: usize = 0,
        x: Creature.Position,
        y: Creature.Position,
        pub fn init(x: Creature.Position, y: Creature.Position) IteratorOnPosition(array, curr_len) {
            return .{ .x = x, .y = y };
        }
        pub fn next(self: *IteratorOnPosition(array, curr_len)) ?usize {
            const last_idx = self.peek() orelse return null;
            self.index = last_idx + 1;
            return last_idx;
        }
        pub fn peek(self: IteratorOnPosition(array, curr_len)) ?usize {
            if (self.index >= curr_len.*) return null;
            return for (self.index..curr_len.*) |index| {
                const item = array[index];
                if (item.x == self.x and item.y == self.y) break index;
            } else null;
        }
    };
}
