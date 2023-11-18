const std = @import("std");
const w4 = @import("wasm4.zig");
const Creature = @import("Creature.zig");
const genome_file = @import("genome.zig");
const getRandomGenome = genome_file.getRandomGenome;
const mutates = genome_file.mutates;
const Position = Creature.Position;

const global_state = @import("global_state.zig");
const fps = global_state.fps;

var started: bool = false;
var generation: usize = 0;
var iterations: u32 = 0;
var best_score: u32 = 0;

pub fn setup() void {
    if (iterations > best_score) {
        best_score = iterations;
        w4.pallete.* = .{
            0xff8e80,
            0xc53a9d,
            0x4a2480,
            0x051f39,
        }; // https://lospec.com/palette-list/lava-gb
    } else w4.pallete.* = .{
        0xe9efec,
        0xa0a08b,
        0x555568,
        0x211e20,
    }; // https://lospec.com/palette-list/2bit-demichrome
    iterations = 0;
    started = true;
    generation += 1;
    w4.print(1, "generation {} with {} genomes in the genome pool", .{
        generation,
        global_state.most_fitting_genomes_len,
    }) catch {};
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

export fn start() void {}

pub fn loop() void {
    if (global_state.creatures_len == 0) setup();
    if (global_state.seed % global_state.spawn_food_interval == 0 and
        global_state.foods_len < global_state.max_food_count) spawnFood();
    var i: usize = 0;
    while (i < global_state.creatures_len) : (i += 1) global_state.creatures[i].iterate();
    
}

export fn update() void {
    global_state.seed +%= 1;
    w4.draw_colors.* = 0x2;
    if (!started) {
        w4.text("Press Z to start!", 10, 10);
    } else {
        if (global_state.seed % (60 / fps) == 0) {
            iterations += 1;
            loop();
        }
        w4.draw_colors.* = 0x40;
        w4.rect(-1, -1, 130, 130);
        w4.draw_colors.* = 0x4;
        w4.text( "Gen", 135, 10);
        w4.textPrint(1, "{}", 135, 20, .{ generation }) catch {
            w4.text("Xe?", 135, 20);
        };
        w4.textPrint(3, "Current: {} i", 10, 135, .{ iterations / 1_000 }) catch {
            w4.text("Current: Infinite!", 10, 130);
        };
        w4.textPrint(3, "Best: {} i", 10, 145, .{ best_score / 1_000 }) catch {
            w4.text("Best: Infinite!", 10, 140);
        };
        w4.draw_colors.* = 0x3;
        for (global_state.foods[0..global_state.foods_len]) |food| w4.rect(food.x, food.y, 1, 1);
        w4.draw_colors.* = 0x2;
        for (global_state.creatures[0..global_state.creatures_len]) |creature| w4.rect(creature.x, creature.y, 1, 1);
    }
    if (!started and w4.gamepad_1.* & w4.button_2 != 0) setup();
}

fn spawnFood() void {
    global_state.foods[global_state.foods_len] = global_state.Food{
        .x = global_state.rand.random().int(Position),
        .y = global_state.rand.random().int(Position),
    };
    global_state.foods_len += 1;
}
