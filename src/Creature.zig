const w4 = @import("wasm4.zig");
const std = @import("std");
const Brain = @import("Brain.zig");
const neuron_file = @import("neuron.zig");
const SensorNeuron = neuron_file.SensorNeuron;
const MotorNeuron = neuron_file.MotorNeuron;
const genome_file = @import("genome.zig");
const Genome = genome_file.Genome;

const global_state = @import("global_state.zig");
const IterateOnPosition = global_state.IteratorOnPosition;
const IterateOnFood = IterateOnPosition(&global_state.foods, &global_state.foods_len);

pub const Creature = @This();
pub const Position = u7;
pub const Direction = enum {
    up,
    down,
    left,
    right,
    pub fn rotate(dir: Direction, x: anytype) Direction {
        const sign = std.math.sign(x);
        return switch (dir) {
            .up => switch (sign) {
                -1 => .left,
                0 => .up,
                1 => .right,
                else => unreachable,
            },
            .down => switch (sign) {
                -1 => .right,
                0 => .down,
                1 => .left,
                else => unreachable,
            },
            .left => switch (sign) {
                -1 => .down,
                0 => .left,
                1 => .up,
                else => unreachable,
            },
            .right => switch (sign) {
                -1 => .up,
                0 => .right,
                1 => .down,
                else => unreachable,
            },
        };
    }
};

x: Position = undefined,
y: Position = undefined,
energy: u8 = global_state.initial_energy,
forward: Direction = .right,
genome: Genome = undefined,
//iterations: u32 = 0,
chomps: u32 = 0,
brain: Brain = undefined,

pub fn init(x: Position, y: Position, genome: Genome) Creature {
    var self: Creature = .{};
    self.x = x;
    self.y = y;
    self.genome = genome;
    self.brain = Brain.init(genome);
    self.forward = global_state.rand.random().enumValue(Direction);
    return self;
}
pub fn iterate(self: *Creature) void {
    const random = global_state.rand.random();
    self.energy -|= global_state.energy_loss_per_iteration;
    //self.iterations +|= 1;
    if (self.energy == 0 and self.chomps > global_state.chomps_to_be_selected) {
        w4.print(0, "creature {} met criteria", .{self.index()});
        const fitness_info = global_state.GenomeWithFitness{
            .fitness = self.chomps,
            .genome = self.genome,
        };
        if (global_state.most_fitting_genomes_len < global_state.max_fitting_genomes) {
            global_state.most_fitting_genomes[global_state.most_fitting_genomes_len] = fitness_info;
            global_state.most_fitting_genomes_len += 1;
        } else {
            for (&global_state.most_fitting_genomes) |*fitting_genome| {
                if (fitness_info.fitness > fitting_genome.*.?.fitness) {
                    fitting_genome.* = fitness_info;
                    break;
                }
                if (fitness_info.fitness == fitting_genome.*.?.fitness) {
                    if (random.boolean()) fitting_genome.* = fitness_info;
                    break;
                } else continue;
            } else w4.print(0, "but creature {} wasnt selected", .{self.index()});
        }
    }
    if (self.energy == 0) {
        const self_index = self.index();
        global_state.creatures[self_index] = global_state.creatures[global_state.creatures_len - 1];
        global_state.creatures_len -= 1;
        return if (global_state.creatures_len > 0) global_state.creatures[self_index].iterate();
    }
    self.senses();
    self.brain.think();
    self.act();
}
fn senses(self: *Creature) void {
    const random = global_state.rand.random();
    for (self.brain.neurons.slice()) |*neuron| {
        if (neuron.type_tag != .sensor) continue;
        neuron.value = switch (@as(SensorNeuron, @enumFromInt(neuron.type_tag.getNeuronId()))) {
            .pos_x => @as(f32, @floatFromInt(self.x)) / @as(f32, @floatFromInt(std.math.maxInt(Position))),
            .pos_y => @as(f32, @floatFromInt(self.y)) / @as(f32, @floatFromInt(std.math.maxInt(Position))),
            .rand => random.float(f32),
            .oscillator => @bitCast(@as(u32, @bitCast(neuron.value)) +% 1),
            .food_below => blk: {
                var iterator = IterateOnFood.init(self.x, self.y);
                if (iterator.next()) |_| break :blk 1;
                break :blk 0;
            },
            .food_fwrd => blk: {
                var position = struct {
                    x: Position,
                    y: Position,
                }{ .x = self.x, .y = self.y };
                for (1..10) |distance| {
                    var iterator = IterateOnFood.init(position.x, position.y);
                    if (iterator.next()) |_| break :blk 1.0 / @as(f32, @floatFromInt(distance));
                    switch (self.forward) {
                        .up => position.y -%= 1,
                        .down => position.y +%= 1,
                        .right => position.x +%= 1,
                        .left => position.x -%= 1,
                    }
                }
                break :blk 0;
            },
            .food_lateral => blk: {
                var position: struct {
                    x: Position,
                    y: Position,
                } = undefined;
                const from_left = blk_left: {
                    position = .{ .x = self.x, .y = self.y };
                    for (1..10) |distance| {
                        var iterator = IterateOnFood.init(position.x, position.y);
                        if (iterator.next()) |_| break :blk_left 1.0 / @as(f32, @floatFromInt(distance));
                        switch (self.forward.rotate(-1)) {
                            .up => position.y -%= 1,
                            .down => position.y +%= 1,
                            .right => position.x +%= 1,
                            .left => position.x -%= 1,
                        }
                    }
                    break :blk_left 0;
                };
                const from_right = blk_right: {
                    position = .{ .x = self.x, .y = self.y };
                    for (1..10) |distance| {
                        var iterator = IterateOnFood.init(position.x, position.y);
                        if (iterator.next()) |_| break :blk_right 1.0 / @as(f32, @floatFromInt(distance));
                        switch (self.forward.rotate(1)) {
                            .up => position.y -%= 1,
                            .down => position.y +%= 1,
                            .right => position.x +%= 1,
                            .left => position.x -%= 1,
                        }
                    }
                    break :blk_right 0;
                };
                break :blk if (from_right > from_left)
                    from_right
                else
                    -from_left;
            },
            .own_energy => @as(f32, @floatFromInt(self.energy)) / 100,
        };
    }
}
fn act(self: *Creature) void {
    const random = global_state.rand.random();
    for (self.brain.neurons.slice()) |neuron| {
        switch (neuron.type_tag) {
            .motor => {
                const neuron_kind: MotorNeuron = @enumFromInt(neuron.type_tag.getNeuronId());
                switch (neuron_kind) {
                    .go_x => if (neuron.value != 0 and @abs(neuron.value) < random.float(f32)) {
                        self.go(Direction.up.rotate(if (neuron.value > 0) @as(i8, 1) else @as(i8, -1)));
                    },
                    .go_y => if (neuron.value != 0 and @abs(neuron.value) < random.float(f32)) {
                        self.go(Direction.right.rotate(if (neuron.value > 0) @as(i8, 1) else @as(i8, -1)));
                    },
                    .go_rnd => if (neuron.value > 0 and neuron.value < random.float(f32)) self.go(random.enumValue(Direction)),
                    .go_fwrd => if (neuron.value > 0 and neuron.value < random.float(f32)) self.go(self.forward),
                    .eat => if (neuron.value > 0 and neuron.value < random.float(f32)) self.eat(),
                    .rotate => if (neuron.value > 0 and neuron.value < random.float(f32)) {
                        self.forward = self.forward.rotate(@as(i32, @intFromFloat(neuron.value)));
                    },
                    .reproduce => if (neuron.value > 0 and neuron.value < random.float(f32)) self.replicates(),
                }
            },
            inline else => {},
        }
    }
}
fn eat(self: *Creature) void {
    var iterator = IterateOnFood.init(self.x, self.y);
    if (iterator.peek()) |_| {
        w4.trace("chomp");
        self.energy +|= global_state.food_energy;
        self.chomps += 1;
    }
    while (iterator.next()) |i| {
        global_state.foods[i] = global_state.foods[global_state.foods_len - 1];
        global_state.foods_len -= 1;
    }
}
fn replicates(self: *Creature) void {
    const random = global_state.rand.random();
    if (self.energy < std.math.maxInt(@TypeOf(self.energy)) / 2) return;
    if (global_state.creatures_len == global_state.max_creature_count) return;
    w4.trace("replicatin");
    self.energy = self.energy / 2 - global_state.energy_loss_per_replication;
    var self_copy = genome_file.mutates(self.genome, random);
    var offspring = self.*;
    offspring.genome = self_copy;
    offspring.forward = offspring.forward.rotate(random.int(i8));
    offspring.go(offspring.forward);
    global_state.creatures[global_state.creatures_len] = offspring;
    global_state.creatures_len += 1;
}
fn go(self: *Creature, direction: Direction) void {
    self.energy -|= global_state.energy_loss_per_movement;
    switch (direction) {
        .down => self.y +%= 1,
        .up => self.y -%= 1,
        .right => self.x +%= 1,
        .left => self.x -%= 1,
    }
    self.forward = direction;
}
fn index(self: *const Creature) usize {
    return (@intFromPtr(self) - @intFromPtr(global_state.creatures[0..])) / @sizeOf(Creature);
}
