const std = @import("std");
const config = @import("config.zig");
const genome_file = @import("genome.zig");
const Genome = genome_file.Genome;
const getGeneInfo = genome_file.getInfo;
const neuron_file = @import("neuron.zig");
const Neuron = neuron_file.Neuron;
const Synapse = neuron_file.Synapse;

const Brain = @This();
const Neurons = std.BoundedArray(Neuron, config.genome_length * 2);
neurons: Neurons = undefined,
synapses: [config.genome_length]Synapse = undefined,
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
fn addSynapse(self: *Brain, info: struct { Neuron.TypeTag, Neuron.TypeTag, i8 }, index: usize) void {
    const source_type = info[0];
    const target_type = info[1];
    const source_neuron = self.findOrAddNeuron(source_type);
    const target_neuron = self.findOrAddNeuron(target_type);
    self.synapses[index] = Synapse{
        .source = source_neuron,
        .target = target_neuron,
        .weight = @as(f32, @floatFromInt(info[2])) / 31,
    };
}
fn findOrAddNeuron(self: *Brain, type_tag: Neuron.TypeTag) usize {
    const neurons = self.neurons.slice();
    return for (neurons, 0..) |neuron, i| {
        if (neuron.type_tag.sameKind(type_tag)) break i;
    } else blk: {
        self.neurons.appendAssumeCapacity(Neuron{
            .type_tag = type_tag,
        });
        break :blk neurons.len;
    };
}
