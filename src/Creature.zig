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
      }
    };
  }
};

x: Position = undefined,
y: Position = undefined,
energy: u8 = 200,
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
  return self;
}
pub fn iterate(self: *Creature, random: std.rand.Random) void {
  self.energy -|= 1;
  self.iterations +|= 1;
  if (self.energy == 0 and self.chomps > 2) {
    w4.trace("met selection criteria");
    const fitness_info = global_state.GenomeWithFitness{
      .fitness = self.iterations,
      .genome = self.genome,
    };
    if (global_state.most_fitting_genomes_len < global_state.max_fitting_genomes) {
      global_state.most_fitting_genomes[global_state.most_fitting_genomes_len] = fitness_info;
      global_state.most_fitting_genomes_len += 1;
    } else {
      for (&global_state.most_fitting_genomes) |*fitting_genome| {
        if (self.iterations > fitting_genome.*.?.fitness) {
          fitting_genome.* = fitness_info;
          break;
        } 
        if (self.iterations == fitting_genome.*.?.fitness) {
          if (random.boolean()) fitting_genome.* = fitness_info;
          break;
        } else continue;
      }
    }
    return;
  }
  self.senses(random);
  self.brain.think();
  self.act(random);
}
fn senses(self: *Creature, random: std.rand.Random) void {
  for (self.brain.neurons.slice()) |*neuron| {
    if (neuron.type_tag != .sensor) continue;
    neuron.value = switch (@as(SensorNeuron, @enumFromInt(neuron.type_tag.getNeuronId()))) {
      .pos_x => @as(f32, @floatFromInt(self.x)) 
      / @as(f32, @floatFromInt(std.math.maxInt(Position))),
      .pos_y => @as(f32, @floatFromInt(self.y))
      / @as(f32, @floatFromInt(std.math.maxInt(Position))),
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
        } { .x = self.x, .y = self.y };
        for (1..10) |distance| {
          var iterator = IterateOnFood.init(position.x, position.y);
          if (iterator.next()) |_| break :blk 1.0/@as(f32, @floatFromInt(distance));
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
        var position : struct {
          x: Position,
          y: Position,
        } = undefined;
        const from_left = blk_left: {
          position = .{ .x = self.x, .y = self.y };
          for (1..10) |distance| {
            var iterator = IterateOnFood.init(position.x, position.y);
            if (iterator.next()) |_| break :blk_left 1.0/@as(f32, @floatFromInt(distance));
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
            if (iterator.next()) |_| break :blk_right 1.0/@as(f32, @floatFromInt(distance));
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
        else -from_left;
      },
      .own_energy => @as(f32, @floatFromInt(self.energy)) / 100
    };
  }
}
fn act(self: *Creature, random: std.rand.Random) void {
  for (self.brain.neurons.slice()) |neuron| {
    switch (neuron.type_tag) {
      .motor => {
        const neuron_kind: MotorNeuron = @enumFromInt(neuron.type_tag.getNeuronId());
        switch (neuron_kind) {
          .go_x => self.x += @intFromFloat(std.math.sign(neuron.value)),
          .go_y => self.y += @intFromFloat(std.math.sign(neuron.value)),
          .go_rnd => if (neuron.value > 0) self.go(random.enumValue(Direction)),
          .go_fwrd => if (neuron.value > 0) self.go(self.forward),
          .eat => {
            var iterator = IterateOnFood.init(self.x, self.y);
            while (iterator.next()) |i| {
              self.chomps += 1;
              self.energy += 10;
              global_state.foods[i] = global_state.foods[global_state.foods_len - 1];
              global_state.foods_len -= 1;
            }
          },
          .rotate => self.forward = self.forward.rotate(@as(i32, @intFromFloat(neuron.value))),
          .reproduce => self.replicates(random),
        }
      },
      inline else => {}
    }
  }
}
fn replicates(self: *Creature, random: std.rand.Random) void {
  if (global_state.creatures_len == global_state.max_entity_count) return;
  self.energy /= 2;
  var self_copy = genome_file.mutates(self.genome, random);
  var creature = Creature.init(self.x, self.y, self_copy);
  creature.go(random.enumValue(Direction));
  global_state.creatures[global_state.creatures_len] = creature;
  global_state.creatures_len += 1;
}
fn go(self: *Creature, direction: Direction) void {
  switch (direction) {
    .down => self.y +%= 1,
    .up => self.y -%= 1,
    .right => self.x +%= 1,
    .left => self.x -%= 1,
  }
  self.forward = direction;
}