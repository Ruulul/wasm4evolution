const std = @import("std");
const w4 = @import("wasm4.zig");
const Creature = @import("Creature.zig");

const creature_count = 300;
const Creatures = [creature_count]Creature;

var global_buffer: [48_000]u8 = undefined;
var fba: std.heap.FixedBufferAllocator = std.heap.FixedBufferAllocator.init(&global_buffer);
var creatures: Creatures = undefined;
var rand: std.rand.Xoshiro256 = undefined;

var started: bool = false;
var seed: u64 = 0;

fn setup() void {
    started = true;

    rand = std.rand.DefaultPrng.init(seed);
    const random = rand.random();    

    for (0..creature_count) |i| {
        creatures[i] = Creature.init(
            random.int(u7),
            random.int(u7),
            Creature.getRandomDNA(random),
        );
    }
} 

export fn start() void {}

var last_gamepad_state: u8 = 0;
export fn update() void {
    seed +%= 1;
    w4.draw_colors.* = 0x2;
    defer last_gamepad_state = w4.gamepad_1.*;

    if (!started) {
        w4.text("Press Z to start!", 10, 10);
    } else {
        w4.draw_colors.* = 0x2;
        for (0..creature_count) |i| {
            var creature = &creatures[i];
            //printBrain(creature);
            w4.rect(creature.x, creature.y, 1, 1);
            creature.iterate(rand.random());
        }
    }
    if ((last_gamepad_state ^ w4.gamepad_1.*) & w4.button_2 != 0) setup();
}

fn printBrain(creature: *const Creature) void {
    for (creature.brain.neurons.slice(), 0..) |neuron, i| {
        if (neuron.value <= 0 ) continue;
        w4.print(50, "neuron {} (type {s}) got excited", .{ i, @tagName(neuron.type_tag) });
    }
}