const TypeTag = @import("neuron.zig").Neuron.TypeTag;
pub const Gene = [3]i8;
pub const genome_length = 3;
pub const Genome = [genome_length]Gene;


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