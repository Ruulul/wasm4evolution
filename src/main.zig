const std = @import("std");
const w4 = @import("wasm4.zig");
const Creature = @import("Creature.zig");

const creature_count = 300;
const CreatureAoS = std.MultiArrayList(Creature);

var global_buffer: [30_000]u8 = undefined;
var fba: std.heap.FixedBufferAllocator = undefined;
var creatures: CreatureAoS = undefined;
var rand: std.rand.Xoshiro256 = undefined;

export fn _start() void {}
export fn start() void {
    fba = std.heap.FixedBufferAllocator.init(&global_buffer);
    const allocator = fba.allocator();

    var seed: u64 = undefined;
    print_number(u64, seed, "seed");
    rand = std.rand.DefaultPrng.init(seed);
    const random = rand.random();

    w4.trace("creating creatures");
    creatures = CreatureAoS{};
    creatures.ensureTotalCapacity(allocator, creature_count) catch w4.trace("failed to ensure capacity");

    for (0..creature_count) |_| {
        creatures.appendAssumeCapacity(.{
            .x = random.intRangeAtMost(Creature.Position, 0, 160),
            .y = random.intRangeAtMost(Creature.Position, 0, 160),
        });
    }
    w4.trace("finished positioning");
    print_number(usize, creatures.len, "creatures len");
}

export fn update() void {
    w4.draw_colors.* = 0x2;

    var slice = creatures.slice();
    for (slice.items(.x), slice.items(.y)) |x, y| w4.rect(x, y, 1, 1);
}

fn print_number(comptime T: type, value: T, log: ?[]const u8) void {
    var str: [std.math.log10(std.math.maxInt(T)) + 1]u8 = undefined;
    if (log) |helpful_text| w4.trace(helpful_text);
    var len = std.fmt.formatIntBuf(&str, value, 10, .upper, .{});
    w4.trace(str[0..len]);
}
