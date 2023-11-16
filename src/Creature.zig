const w4 = @import("wasm4.zig");
const std = @import("std");
const Synapse = @import("neuron.zig").Synapse;
const Neuron = @import("neuron.zig").Neuron;
const SensorNeuron = @import("neuron.zig").SensorNeuron;
const MotorNeuron = @import("neuron.zig").MotorNeuron;
const Gene = @import("neuron.zig").Gene;
const dna_length = 3;

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
dna: [dna_length]Gene = undefined,
brain: Brain = undefined,

pub fn getRandomDNA(random: std.rand.Random) [dna_length]Gene {
  var dna: [dna_length]Gene = undefined;
  for (&dna) |*gene| random.bytes(@ptrCast(gene));
  return dna;
}
pub fn init(x: Position, y: Position, dna: [dna_length]Gene) Creature {
  var self: Creature = .{};
  self.x = x;
  self.y = y;
  self.dna = dna;
  self.brain = Brain.init(dna);
  return self;
}
pub fn iterate(self: *Creature, random: std.rand.Random) void {
  self.senses();
  self.brain.think();
  self.act(random);
}
fn senses(self: *Creature) void {
  for (self.brain.neurons.slice()) |*neuron| {
    if (neuron.type_tag != .sensor) continue;
    switch (@as(SensorNeuron, @enumFromInt(neuron.type_tag.getNeuronId()))) {
      .pos_x => neuron.value = @as(f32, @floatFromInt(self.x)) 
      / @as(f32, @floatFromInt(w4.screen_size)),
      .pos_y => neuron.value = @as(f32, @floatFromInt(self.y))
      / @as(f32, @floatFromInt(w4.screen_size)),
    }
  }
}
fn act(self: *Creature, random: std.rand.Random) void {
  for (self.brain.neurons.slice()) |neuron| {
    switch (neuron.type_tag) {
      .motor => {
        const neuron_kind: MotorNeuron = @enumFromInt(neuron.type_tag.getNeuronId());
        if (neuron.value > 0) switch (neuron_kind) {
          .go_up => self.go(.up),
          .go_down => self.go(.down),
          .go_left => self.go(.left),
          .go_right => self.go(.right),
          .go_rnd => self.go(random.enumValue(Direction)),
          .go_fwrd => self.go(self.forward),
        };
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
    const Neurons = std.BoundedArray(Neuron, dna_length * 2);
    neurons: Neurons = undefined,
    synapses: [dna_length]Synapse = undefined,
    pub fn init(dna: [dna_length]Gene) Brain {
      var self: Brain = .{};
      self.neurons = Neurons.init(0) catch unreachable;
      for (dna, 0..) |gene, i| {
        const info = Synapse.getInfo(gene);
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