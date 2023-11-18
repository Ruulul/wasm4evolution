const std = @import("std");
const w4 = @import("wasm4.zig");

const global_state = @import("global_state.zig");
const game_logic = @import("game_logic.zig");

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
    game_logic.setup();
}

export fn start() void {}

export fn update() void {
    global_state.seed +%= 1;
    w4.draw_colors.* = 0x2;
    if (!started) {
        w4.text("Press Z to start!", 10, 10);
    } else {
        if (global_state.seed % (60 / global_state.fps) == 0) {
            iterations += 1;
            game_logic.loop();
        }
        w4.draw_colors.* = 0x40;
        w4.rect(-1, -1, 130, 130);
        w4.draw_colors.* = 0x4;
        w4.text( "Gen", 135, 10);
        w4.textPrint(1, "{}", 135, 20, .{ generation }) catch {
            w4.text("Xe?", 135, 20);
        };
        w4.textPrint(3, "Current: {} i", 10, 135, .{ iterations / 100 }) catch {
            w4.text("Current: Infinite!", 10, 130);
        };
        w4.textPrint(3, "Best: {} i", 10, 145, .{ best_score / 100 }) catch {
            w4.text("Best: Infinite!", 10, 140);
        };
        w4.draw_colors.* = 0x3;
        for (global_state.foods[0..global_state.foods_len]) |food| w4.rect(food.x, food.y, 1, 1);
        w4.draw_colors.* = 0x2;
        for (global_state.creatures[0..global_state.creatures_len]) |creature| w4.rect(creature.x, creature.y, 1, 1);
    }
    if (!started and w4.gamepad_1.* & w4.button_2 != 0) setup();
}
