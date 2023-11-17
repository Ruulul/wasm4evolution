const std = @import("std");
const config = @import("config.zig");
const TypeTag = @import("neuron.zig").Neuron.TypeTag;
pub const Gene = [3]i8;
pub const Genome = [config.genome_length]Gene;

pub fn getRandomGenome(random: std.rand.Random) Genome {
  var dna: Genome = undefined;
  for (&dna) |*gene| random.bytes(@ptrCast(gene));
  return dna;
}
pub fn mutates(original: Genome, random: std.rand.Random) Genome {
  var new = original;
  for (&new) |*gene| {
    if (random.uintLessThan(u8, 100) <= 1) {
      const synapse = random.uintLessThan(usize, 3);
      const bit_to_fuzzle = random.uintAtMost(u3, 7);
      const bit_mask = @as(i8, 1) << bit_to_fuzzle;
      if (gene[synapse] & bit_mask != 0) 
        gene[synapse] |= bit_mask
      else gene[synapse] &= ~bit_mask;
    }
  }
  return new;
}
pub fn getInfo(gene: Gene) struct{TypeTag, TypeTag, i8} {
  const source_info: i8 = gene[0];
  const target_info: i8 = gene[1];
  const weight: i8 = gene[2];
  const source_tag: u8 = @abs(source_info);
  const target_tag: u8 = @abs(target_info);
  const source = if (source_info > 0) TypeTag{ .sensor = source_tag } else TypeTag{ .intern = source_tag };
  const target = if (target_info > 0) TypeTag{ .intern = target_tag } else TypeTag{ .motor = target_tag };
  return .{ source, target, weight };
}