const std = @import("std");
const w4 = @import("wasm4.zig");
const Creature = @import("Creature.zig");
const genome_file = @import("genome.zig");
const getRandomGenome = genome_file.getRandomGenome;
const mutates = genome_file.mutates;
const Position = Creature.Position;

const global_state = @import("global_state.zig");
const fps = 60;

var started: bool = false;

fn setup() void {
    started = true;
    w4.trace("new generation");

    global_state.rand = std.rand.DefaultPrng.init(global_state.seed);
    const random = global_state.rand.random(); 
    global_state.creatures_len = 0;
    global_state.foods_len = 0;

    for (global_state.creatures[0..200], 0..) |*creature, i| {
        const most_fitting_genome_from_previous_generation = 
            if (global_state.most_fitting_genomes[i % global_state.max_fitting_genomes]) |info|
                info.genome
            else null;
        creature.* = Creature.init(
            random.int(Position),
            random.int(Position),
            if (most_fitting_genome_from_previous_generation) |genome|
                mutates(genome, random) 
            else getRandomGenome(random),
        );
        creature.energy +|= random.int(u8);
        global_state.creatures_len += 1;
    }
    for (global_state.foods[0..100]) |*food| {
        food.* = .{
            .x = random.int(Position),
            .y = random.int(Position)
        };
        global_state.foods_len += 1;
    }
} 

export fn start() void {}

export fn update() void {
    global_state.seed +%= 1;

    w4.draw_colors.* = 0x2;
    if (!started) {
        w4.text("Press Z to start!", 10, 10);
    } else {
        if (global_state.creatures_len == 0) setup();
        w4.draw_colors.* = 0x40;
        w4.rect(-1, -1, 130, 130);
        w4.draw_colors.* = 0x4;
        for (global_state.foods[0..global_state.foods_len]) |food| w4.rect(food.x, food.y, 1, 1);
        w4.draw_colors.* = 0x2;
        var i: usize = 0;
        while (i < global_state.creatures_len) {
            w4.rect(global_state.creatures[i].x, global_state.creatures[i].y, 1, 1);
            if (global_state.seed % (60 / fps) == 0) global_state.creatures[i].iterate(global_state.rand.random());
            if (global_state.creatures[i].energy == 0) {
                const dead = global_state.creatures[i];
                global_state.creatures[i] = global_state.creatures[global_state.creatures_len - 1];
                global_state.creatures_len -= 1;
                global_state.foods[global_state.foods_len] = .{
                    .x = dead.x,
                    .y = dead.y,
                };
                global_state.foods_len += 1;
                continue;
            }
            i += 1;
        }
    }
    if (!started and w4.gamepad_1.* & w4.button_2 != 0) setup();
}

fn printBrain(creature: *const Creature) void {
    for (creature.brain.neurons.slice(), 0..) |neuron, i| {
        if (neuron.value <= 0 ) continue;
        w4.print(50, "neuron {} (type {s}) got excited", .{ i, @tagName(neuron.type_tag) });
    }
}