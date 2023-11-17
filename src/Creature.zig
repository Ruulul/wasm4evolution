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
iterations: u32 = 0,
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
    self.energy -|= global_state.energy_loss_per_iteration;
    self.iterations +|= 1;
    if (self.energy == 0 and self.chomps >= global_state.chomps_to_be_selected) {
        const fitness_info = global_state.GenomeWithFitness{
            .fitness = self.iterations,
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
                } else if (fitness_info.fitness == fitting_genome.*.?.fitness and global_state.rand.random().boolean()) {
                    fitting_genome.* = fitness_info;
                }
            }
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
            .food_fwrd => if (self.seeFood(self.forward)) |distance| 
              1.0/@as(f32, @floatFromInt(distance))
            else 
              0,
            .food_lateral => blk: {
                const from_left = @as(f32, @floatFromInt(self.seeFood(self.forward.rotate(-1)) orelse 0));
                const from_right = @as(f32, @floatFromInt(self.seeFood(self.forward.rotate(1)) orelse 0));
                break :blk if (from_right > from_left) 
                    if (from_right != 0) 1.0/from_right else 0
                
                else 
                    if (from_right != 0) -1.0/from_left else 0;
            },
            .own_energy => @as(f32, @floatFromInt(self.energy)) / 100,
        };
    }
}
fn seeFood(self: Creature, direction: Direction) ?usize {
  var position = struct {
      x: Position,
      y: Position,
  }{ .x = self.x, .y = self.y };
  return for (1..global_state.fov + 1) |distance| {
    switch (direction) {
          .up => position.y -%= 1,
          .down => position.y +%= 1,
          .right => position.x +%= 1,
          .left => position.x -%= 1,
      }
      if (
        IterateOnFood
          .init(position.x, position.y)
          .peek()
        ) |_| break distance;
  } else null;
}
fn act(self: *Creature) void {
    const random = global_state.rand.random();
    _ = random;
    self.moves();
    for (self.brain.neurons.slice()) |neuron| {
        switch (neuron.type_tag) {
            .motor => {
                const neuron_kind: MotorNeuron = @enumFromInt(neuron.type_tag.getNeuronId());
                switch (neuron_kind) {
                    .eat => if (neuron.read()) self.eat(),
                    .rotate => if (neuron.read()) {
                        self.forward = self.forward.rotate(@as(i32, @intFromFloat(neuron.value)));
                    },
                    .reproduce => if (neuron.read()) self.replicates(),
                    inline else => {},
                }
            },
            inline else => {},
        }
    }
}
fn eat(self: *Creature) void {
    var iterator = IterateOnFood.init(self.x, self.y);
    if (iterator.peek()) |_| {
        self.energy +|= global_state.food_energy;
        self.chomps += 1;
    }
    while (iterator.next()) |i| {
        global_state.foods[i] = global_state.foods[global_state.foods_len - 1];
        global_state.foods_len -= 1;
    }
}
fn moves(self: *Creature) void {
    const random = global_state.rand.random();
    var strongest_move: f32 = 0;
    var strongest_direction: Direction = undefined;
    for (self.brain.neurons.slice()) |neuron| {
        switch (neuron.type_tag) {
            .motor => {
                const neuron_kind: MotorNeuron = @enumFromInt(neuron.type_tag.getNeuronId());
                switch (neuron_kind) {
                    .go_x => if (neuron.readAbs()) {
                        if (strongest_move > @abs(neuron.value)) continue;
                        strongest_move = @abs(neuron.value);
                        strongest_direction = Direction.up.rotate(if (neuron.value > 0) @as(i8, 1) else @as(i8, -1));
                    },
                    .go_y => if (neuron.readAbs()) {
                        if (strongest_move > @abs(neuron.value)) continue;
                        strongest_move = @abs(neuron.value);
                        strongest_direction = Direction.right.rotate(if (neuron.value > 0) @as(i8, 1) else @as(i8, -1));
                    },
                    .go_rnd => if (neuron.read()) {
                        if (strongest_move > neuron.value) continue;
                        strongest_move = neuron.value;
                        strongest_direction = random.enumValue(Direction);
                    },
                    .go_fwrd => if (neuron.read()) {
                        if (strongest_move > neuron.value) continue;
                        strongest_move = neuron.value;
                        strongest_direction = self.forward;
                    },
                    inline else => {},
                }
            },
            inline else => {},
        }
    }
    if (strongest_move > 0) self.go(strongest_direction);
}
fn replicates(self: *Creature) void {
    const random = global_state.rand.random();
    if (self.energy < std.math.maxInt(@TypeOf(self.energy)) / 2) return;
    if (global_state.creatures_len == global_state.max_creature_count) return;
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
