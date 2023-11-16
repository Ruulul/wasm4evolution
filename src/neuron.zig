const activateFn = @import("std").math.tanh;

pub const intern_neurons_max = 5;

fn nOfTags(comptime T: type) usize {
  return switch (@typeInfo(T)) {
    .Union => |u| u.fields.len,
    .Enum => |u| u.fields.len,
    inline else => @compileError("Invalid function call")
  };
}
pub const Neuron = struct {
  pub const TypeTag = union(enum(u8)) {
    sensor: u8,
    intern: u8,
    motor: u8,
    pub fn getCount(self: TypeTag) u8 {
      return switch (self) {
        .sensor => TypeCount.sensor,
        .intern => TypeCount.intern,
        .motor => TypeCount.motor,
      };
    }
    pub fn getNeuronId(self: TypeTag) u8 {
      return switch (self) {
        inline else => |v| v % self.getCount(),
      };
    }
    pub fn sameKind(a: TypeTag, b: TypeTag) bool {
      return if (@intFromEnum(a) == @intFromEnum(b)) 
        a.getNeuronId() == b.getNeuronId()
      else false;
    }
  };
  pub const TypeCount = struct {
    pub const sensor = SensorNeuron.count;
    pub const intern = intern_neurons_max;
    pub const motor = MotorNeuron.count;
  };
  value: f32 = 0,
  input: f32 = 0,
  type_tag: TypeTag,
  pub fn activate(neuron: *Neuron) void {
    neuron.value = activateFn(neuron.input);
    neuron.input = 0;
  }
};
pub const SensorNeuron = enum(u8) {
  pos_x,
  pos_y,
  pub const count = nOfTags(SensorNeuron);
};
pub const MotorNeuron = enum(u8) {
  go_up,
  go_down,
  go_left,
  go_right,
  go_rnd,
  go_fwrd,
  pub const count = nOfTags(MotorNeuron);
};

pub const Gene = [3]i8;

pub const Synapse = struct {
  source: usize,
  target: usize,
  weight: f32,
  pub fn getInfo(gene: Gene) struct{Neuron.TypeTag, Neuron.TypeTag, i8} {
    const source_info: i8 = gene[0];
    const target_info: i8 = gene[1];
    const weight: i8 = gene[2];
    const source_tag: u8 = @abs(source_info);
    const target_tag: u8 = @abs(target_info);
    const source = if (source_info > 0) Neuron.TypeTag{ .sensor = source_tag } else Neuron.TypeTag{ .intern = source_tag };
    const target = if (target_info > 0) Neuron.TypeTag{ .intern = target_tag } else Neuron.TypeTag{ .motor = target_tag };

    return .{ source, target, weight };
  }
};
