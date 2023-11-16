const std = @import("std");
const w4 = @import("wasm4.zig");
const Creature = @import("Creature.zig");
const getRandomGenome = @import("genome.zig").getRandomGenome;
const Position = Creature.Position;

const fps = 6;

pub const max_entity_count = 300;
const Creatures = [max_entity_count]Creature;
const Food = struct {
    x: Position,
    y: Position,
};
const Foods  = [max_entity_count]Food;
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
var global_buffer: [30_000]u8 = undefined;
var fba: std.heap.FixedBufferAllocator = std.heap.FixedBufferAllocator.init(&global_buffer);
pub var creatures: Creatures = undefined;
pub var creatures_len: usize = 0;
pub var foods: Foods = undefined;
pub var foods_len: usize = 0;
var rand: std.rand.Xoshiro256 = undefined;

var started: bool = false;
var seed: u64 = 0;

fn setup() void {
    started = true;

    rand = std.rand.DefaultPrng.init(seed);
    const random = rand.random(); 
    creatures_len = 0;
    foods_len = 0;

    for (creatures[0..100]) |*creature| {
        creature.* = Creature.init(
            random.int(Position),
            random.int(Position),
            getRandomGenome(random),
        );
        creature.energy +|= random.int(u8);
        creatures_len += 1;
    }
    for (foods[0..200]) |*food| {
        food.* = .{
            .x = random.int(Position),
            .y = random.int(Position)
        };
        foods_len += 1;
    }
} 

export fn start() void {}

var last_gamepad_state: u8 = 0;
export fn update() void {
    seed +%= 1;
    defer last_gamepad_state = w4.gamepad_1.*;

    w4.draw_colors.* = 0x2;
    if (!started) {
        w4.text("Press Z to start!", 10, 10);
    } else {
        if (creatures_len == 0) setup();
        w4.draw_colors.* = 0x40;
        w4.rect(-1, -1, 130, 130);
        w4.draw_colors.* = 0x4;
        for (foods[0..foods_len]) |food| w4.rect(food.x, food.y, 1, 1);
        w4.draw_colors.* = 0x2;
        var i: usize = 0;
        while (i < creatures_len) {
            w4.rect(creatures[i].x, creatures[i].y, 1, 1);
            if (seed % (60 / fps) == 0) creatures[i].iterate(rand.random());
            if (creatures[i].energy == 0) {
                const dead = creatures[i];
                creatures[i] = creatures[creatures_len - 1];
                creatures_len -= 1;
                foods[foods_len] = .{
                    .x = dead.x,
                    .y = dead.y,
                };
                foods_len += 1;
                continue;
            }
            i += 1;
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