const std = @import("std");
const w4 = @import("wasm4.zig");
const Creature = @import("Creature.zig");

const creature_count = 300;
const CreatureAoS = std.MultiArrayList(Creature);

var global_buffer: [30_000]u8 = undefined;
var fba: std.heap.FixedBufferAllocator = undefined;
var creatures: ?CreatureAoS = null;
var rand: std.rand.Xoshiro256 = undefined;

var started: bool = false;
var seed: u64 = 0;

fn setup() void {
    started = true;
    const allocator = fba.allocator();

    rand = std.rand.DefaultPrng.init(seed);
    const random = rand.random();    

    if (creatures == null) creatures = CreatureAoS{};
    creatures.?.shrinkRetainingCapacity(0);
    creatures.?.ensureTotalCapacity(allocator, creature_count) catch w4.trace("failed to ensure capacity");

    for (0..creature_count) |_| {
        var new_creature: Creature = .{
            .x = random.intRangeAtMost(Creature.Position, 0, 160),
            .y = random.intRangeAtMost(Creature.Position, 0, 160),
        };
        random.bytes(&new_creature.dna);
        creatures.?.appendAssumeCapacity(new_creature);
    }
} 

export fn start() void {
    fba = std.heap.FixedBufferAllocator.init(&global_buffer);
}

var last_gamepad_state: u8 = 0;
export fn update() void {
    seed +%= 1;
    w4.draw_colors.* = 0x2;
    defer last_gamepad_state = w4.gamepad_1.*;

    if (!started) {
        w4.text("Press Z to start!", 10, 10);
    } else {
        w4.draw_colors.* = 0x2;
        const slice = creatures.?.slice();
        for (slice.items(.x), slice.items(.y)) |x, y| {
            w4.rect(x, y, 1, 1);
        }
    }
    if ((last_gamepad_state ^ w4.gamepad_1.*) & w4.button_2 != 0) setup();
}

fn print_number(comptime T: type, value: T, log: ?[]const u8) void {
    var str: [std.math.log10(std.math.maxInt(T)) + 1]u8 = undefined;
    if (log) |helpful_text| w4.trace(helpful_text);
    var len = std.fmt.formatIntBuf(&str, value, 10, .upper, .{});
    w4.trace(str[0..len]);
}
