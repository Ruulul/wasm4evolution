const w4 = @import("wasm4.zig");
const std = @import("std");
const Synapse = @import("neuron.zig").Synapse;
const Neuron = @import("neuron.zig").Neuron;
const SensorNeuron = @import("neuron.zig").SensorNeuron;
const MotorNeuron = @import("neuron.zig").MotorNeuron;
const Genome = @import("genome.zig").Genome;
const getGeneInfo = @import("genome.zig").getInfo;
const genome_length = @import("genome.zig").genome_length;

pub const Creature = @This();
pub const Position = u7;
pub const Direction = enum {
  up,
  down,
  left,
  right,
};

x: Position = undefined,
y: Position = undefined,
forward: Direction = .right,
genome: Genome = undefined,
brain: Brain = undefined,

pub fn getRandomGenome(random: std.rand.Random) Genome {
  var dna: Genome = undefined;
  for (&dna) |*gene| random.bytes(@ptrCast(gene));
  return dna;
}
pub fn init(x: Position, y: Position, genome: Genome) Creature {
  var self: Creature = .{};
  self.x = x;
  self.y = y;
  self.genome = genome;
  self.brain = Brain.init(genome);
  return self;
}
pub fn iterate(self: *Creature, random: std.rand.Random) void {
  self.senses(random);
  self.brain.think();
  self.act(random);
}
fn senses(self: *Creature, random: std.rand.Random) void {
  for (self.brain.neurons.slice()) |*neuron| {
    if (neuron.type_tag != .sensor) continue;
    neuron.value = switch (@as(SensorNeuron, @enumFromInt(neuron.type_tag.getNeuronId()))) {
      .pos_x => @as(f32, @floatFromInt(self.x)) 
      / @as(f32, @floatFromInt(w4.screen_size)),
      .pos_y => @as(f32, @floatFromInt(self.y))
      / @as(f32, @floatFromInt(w4.screen_size)),
      .rand => random.float(f32),
      .oscillator => @bitCast(@as(u32, @bitCast(neuron.value)) +% 1),
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
        }
      },
      inline else => {}
    }
  }
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