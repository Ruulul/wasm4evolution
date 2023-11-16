const std = @import("std");
const w4 = @import("wasm4.zig");
const Creature = @import("Creature.zig");

const fps = 6;

const max_entity_count = 300;
const Creatures = std.BoundedArray(Creature, max_entity_count);
const Food = struct {
    x: Creature.Position,
    y: Creature.Position,
};
const Foods  = std.BoundedArray(Food, max_entity_count);
const IteratorCreaturesOnPosition = struct {
    index: usize = 0,
    x: Creature.Position,
    y: Creature.Position,
    fn init(x: Creature.Position, y: Creature.Position) IteratorCreaturesOnPosition {
        return .{ .x = x, .y = y };
    }
    fn next(self: *IteratorCreaturesOnPosition) ?usize {
        if (self.index >= creatures.len) return null;
        return for (self.index..creatures.len) |index| {
            const creature = creatures.get(index);
            if (creature.x == self.x and creature.y == self.y) {
                self.index = index + 1;
                break index;
            }
        } else null;
    }
};

var global_buffer: [30_000]u8 = undefined;
var fba: std.heap.FixedBufferAllocator = std.heap.FixedBufferAllocator.init(&global_buffer);
var creatures: Creatures = undefined;
var foods: Foods = undefined;
var rand: std.rand.Xoshiro256 = undefined;

var started: bool = false;
var seed: u64 = 0;

fn setup() void {
    started = true;

    rand = std.rand.DefaultPrng.init(seed);
    const random = rand.random();    

    creatures = Creatures.init(30) catch unreachable;
    foods = Foods.init(30) catch unreachable;
    for (creatures.slice(), foods.slice()) |*creature, *food| {
        creature.* = Creature.init(
            random.int(Creature.Position),
            random.int(Creature.Position),
            Creature.getRandomGenome(random),
        );
        food.* = .{
            .x = random.int(Creature.Position),
            .y = random.int(Creature.Position)
        };
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
        w4.draw_colors.* = 0x4;
        for (foods.slice()) |food| w4.rect(food.x, food.y, 1, 1);
        w4.draw_colors.* = 0x2;
        for (creatures.slice()) |*creature| {
            w4.rect(creature.x, creature.y, 1, 1);
            if (seed % (60 / fps) == 0) creature.iterate(rand.random());
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