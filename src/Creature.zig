const w4 = @import("wasm4.zig");
const std = @import("std");
const Synapse = @import("neuron.zig").Synapse;
const Neuron = @import("neuron.zig").Neuron;
const SensorNeuron = @import("neuron.zig").SensorNeuron;
const MotorNeuron = @import("neuron.zig").MotorNeuron;
const Genome = @import("genome.zig").Genome;
const getGeneInfo = @import("genome.zig").getInfo;
const genome_length = @import("genome.zig").genome_length;

const max_entities = @import("main.zig").max_entity_count;
const foods = &@import("main.zig").foods;
const foods_len = &@import("main.zig").foods_len;
const creatures = &@import("main.zig").creatures;
const creatures_len = &@import("main.zig").creatures_len;
const IterateOnPosition= @import("main.zig").IteratorOnPosition;
const IterateOnFood = IterateOnPosition(foods, foods_len);

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
energy: u8 = 100,
forward: Direction = .right,
genome: Genome = undefined,
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
  if (self.energy == 0) {
    if (random.boolean()) {
      self.energy = 200;
      self.replicates(random);
      self.energy = 0;
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
              w4.trace("chomp");
              self.energy += 50;
              foods[i] = foods[foods_len.* - 1];
              foods_len.* -= 1;
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
  if (creatures_len.* == max_entities) return w4.trace("failed to reproduce");
  self.energy /= 2;
  var self_copy = self.genome;
  for (&self_copy) |*gene| {
    if (random.uintLessThan(u8, 100) <= 1) {
      const synapse = random.uintLessThan(usize, 3);
      const bit_to_fuzzle = random.uintAtMost(u3, 7);
      const bit_mask = @as(i8, 1) << bit_to_fuzzle;
      if (gene[synapse] & bit_mask != 0) 
        gene[synapse] |= bit_mask
      else gene[synapse] &= ~bit_mask;
    }
  }
  var creature = Creature.init(self.x, self.y, self_copy);
  creature.go(random.enumValue(Direction));
  creatures[creatures_len.*] = creature;
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
pub const Brain = struct {
    const Neurons = std.BoundedArray(Neuron, genome_length * 2);
    neurons: Neurons = undefined,
    synapses: [genome_length]Synapse = undefined,
    pub fn init(genome: Genome) Brain {
      var self: Brain = .{};
      self.neurons = Neurons.init(0) catch unreachable;
      for (genome, 0..) |gene, i| {
        const info = getGeneInfo(gene);
        self.addSynapse(info, i);
      }
      return self;
    }
    pub fn think(self: *Brain) void {
      for (self.synapses) |synapse| {
        self.neurons.buffer[synapse.target].input += 
        self.neurons.buffer[synapse.source].value * synapse.weight;
      }
      for (self.neurons.slice()) |*neuron| neuron.activate();
    }
    fn addSynapse(self: *Brain, info: struct {Neuron.TypeTag, Neuron.TypeTag, i8}, index: usize) void {
      const source_type = info[0];
      const target_type = info[1];
      const source_neuron = self.findOrAddNeuron(source_type);
      const target_neuron = self.findOrAddNeuron(target_type);
      self.synapses[index] = Synapse{
        .source = source_neuron,
        .target = target_neuron,
        .weight = @as(f32, @floatFromInt( info[2])) / 31,
      };
    }
    fn findOrAddNeuron(self: *Brain, type_tag: Neuron.TypeTag) usize {
      const neurons = self.neurons.slice();
      return for (neurons, 0..) |neuron, i| {
        if (neuron.type_tag.sameKind(type_tag)) break i;
      } else blk: {
        self.neurons.appendAssumeCapacity(Neuron{.type_tag = type_tag,});
        break :blk neurons.len;
      };
    }
  };