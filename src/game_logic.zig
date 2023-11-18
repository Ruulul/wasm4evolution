const std = @import("std");

const global_state = @import("global_state.zig");
const Creature = @import("Creature.zig");
const Position = Creature.Position;

const genome_file = @import("genome.zig");
const getRandomGenome = genome_file.getRandomGenome;
const mutates = genome_file.mutates;

pub fn setup() void {
    global_state.rand = std.rand.DefaultPrng.init(global_state.seed);
    const random = global_state.rand.random();
    global_state.creatures_len = 0;
    global_state.foods_len = 0;

    for (global_state.creatures[0..global_state.initial_creature_count], 0..) |*creature, i| {
        const most_fitting_genome_from_previous_generation =
            if (global_state.most_fitting_genomes[i % global_state.max_fitting_genomes]) |info|
            info.genome
        else
            null;
        creature.* = Creature.init(
            random.int(Position),
            random.int(Position),
            if (most_fitting_genome_from_previous_generation) |genome|
                mutates(genome, random)
            else
                getRandomGenome(random),
        );
        global_state.creatures_len += 1;
    }
    for (global_state.foods[0..global_state.initial_food_count]) |*food| {
        food.* = .{ .x = random.int(Position), .y = random.int(Position) };
        global_state.foods_len += 1;
    }
}

pub fn loop(extSetup: *const fn () void) void {
    if (global_state.creatures_len == 0) extSetup();
    if (global_state.seed % global_state.spawn_food_interval == 0 and
        global_state.foods_len < global_state.max_food_count) spawnFood();
    var i: usize = 0;
    while (i < global_state.creatures_len) : (i += 1) global_state.creatures[i].iterate();
}

fn spawnFood() void {
    global_state.foods[global_state.foods_len] = global_state.Food{
        .x = global_state.rand.random().int(Position),
        .y = global_state.rand.random().int(Position),
    };
    global_state.foods_len += 1;
}
