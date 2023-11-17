const std = @import("std");
const Genome = @import("genome.zig").Genome;
pub const Creature = @import("Creature.zig");
pub const Position = Creature.Position;

pub const max_entity_count = 300;
pub const Creatures = [max_entity_count]Creature;
pub const Food = struct {
    x: Position,
    y: Position,
};
pub const Foods  = [max_entity_count]Food;

pub var global_buffer: [30_000]u8 = undefined;
pub var fba: std.heap.FixedBufferAllocator = std.heap.FixedBufferAllocator.init(&global_buffer);
pub var creatures: Creatures = undefined;
pub var creatures_len: usize = 0;
pub var foods: Foods = undefined;
pub var foods_len: usize = 0;

pub const GenomeWithFitness = struct {
    genome: Genome,
    fitness: u64,
};
pub const max_fitting_genomes = 10;
pub var most_fitting_genomes = [_]?GenomeWithFitness{ null} ** max_fitting_genomes;
pub var most_fitting_genomes_len: usize = 0;

pub var rand: std.rand.Xoshiro256 = undefined;
pub var seed: u64 = 0;

pub fn IteratorOnPosition (comptime array: anytype, comptime curr_len: *usize) type {
    return struct {
        index: usize = 0,
        x: Creature.Position,
        y: Creature.Position,
        pub fn init(x: Creature.Position, y: Creature.Position) IteratorOnPosition(array, curr_len) {
            return .{ .x = x, .y = y };
        }
        pub fn next(self: *IteratorOnPosition(array, curr_len)) ?usize {
            if (self.index >= curr_len.*) return null;
            return for (self.index..curr_len.*) |index| {
                const item = array[index];
                if (item.x == self.x and item.y == self.y) {
                    self.index = index + 1;
                    break index;
                }
            } else null;
        }
    };
}