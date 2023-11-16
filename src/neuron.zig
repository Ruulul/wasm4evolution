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
  rand,
  oscillator,
  food_fwrd,
  food_lateral,
  food_below,
  own_energy,
  pub const count = nOfTags(SensorNeuron);
};
pub const MotorNeuron = enum(u8) {
  go_x,
  go_y,
  go_rnd,
  go_fwrd,
  rotate,
  eat,
  reproduce,
  pub const count = nOfTags(MotorNeuron);
};


pub const Synapse = struct {
  source: usize,
  target: usize,
  weight: f32,
};
