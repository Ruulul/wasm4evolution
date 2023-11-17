const std = @import("std");
//
// WASM-4: https://wasm4.org/docs

// ┌───────────────────────────────────────────────────────────────────────────┐
// │                                                                           │
// │ Platform Constants                                                        │
// │                                                                           │
// └───────────────────────────────────────────────────────────────────────────┘

pub const screen_size: u32 = 160;

// ┌───────────────────────────────────────────────────────────────────────────┐
// │                                                                           │
// │ Memory Addresses                                                          │
// │                                                                           │
// └───────────────────────────────────────────────────────────────────────────┘
pub const pallete: *[4]u32 = @ptrFromInt(0x04);
pub const draw_colors: *u16 = @ptrFromInt(0x14);
pub const gamepad_1: *u8 = @ptrFromInt(0x16);
pub const gamepad_2: *u8 = @ptrFromInt(0x17);
pub const gamepad_3: *u8 = @ptrFromInt(0x18);
pub const gamepad_4: *u8 = @ptrFromInt(0x19);

pub const mouse_left: u8 = 1 << 0;
pub const mouse_right: u8 = 1 << 1;
pub const mouse_middle: u8 = 1 << 2;
pub const mouse = struct {
    pub const x: *const i16 = @ptrFromInt(0x1a);
    pub const y: *const i16 = @ptrFromInt(0x1c);
    pub const buttons: *const u8 = @ptrFromInt(0x1e);
};
pub const system_flags = struct {
    pub const state: *u8 = @ptrFromInt(0x1f);
    pub const value = enum(u8) {
        system_preserve_framebuffer = 1 << 0,
        system_hide_gamepad_overlay = 1 << 1,
    };
};
pub const SYSTEM_FLAGS: *u8 = @ptrFromInt(0x1f);
pub const NETPLAY: *const u8 = @ptrFromInt(0x20);
pub const FRAMEBUFFER: *[6400]u8 = @ptrFromInt(0xA0);

pub const button_1: u8 = 1 << 0;
pub const button_2: u8 = 1 << 1;
pub const button_left: u8 = 1 << 4;
pub const button_right: u8 = 1 << 5;
pub const button_up: u8 = 1 << 6;
pub const button_down: u8 = 1 << 7;

// ┌───────────────────────────────────────────────────────────────────────────┐
// │                                                                           │
// │ Drawing Functions                                                         │
// │                                                                           │
// └───────────────────────────────────────────────────────────────────────────┘

/// Copies pixels to the framebuffer.
pub extern fn blit(sprite: [*]const u8, x: i32, y: i32, width: u32, height: u32, flags: u32) void;

/// Copies a subregion within a larger sprite atlas to the framebuffer.
pub extern fn blitSub(sprite: [*]const u8, x: i32, y: i32, width: u32, height: u32, src_x: u32, src_y: u32, stride: u32, flags: u32) void;

pub const BLIT_2BPP: u32 = 1;
pub const BLIT_1BPP: u32 = 0;
pub const BLIT_FLIP_X: u32 = 2;
pub const BLIT_FLIP_Y: u32 = 4;
pub const BLIT_ROTATE: u32 = 8;

/// Draws a line between two points.
pub extern fn line(x1: i32, y1: i32, x2: i32, y2: i32) void;

/// Draws an oval (or circle).
pub extern fn oval(x: i32, y: i32, width: u32, height: u32) void;

/// Draws a rectangle.
pub extern fn rect(x: i32, y: i32, width: u32, height: u32) void;

/// Draws text using the built-in system font.
pub fn text(str: []const u8, x: i32, y: i32) void {
    textUtf8(str.ptr, str.len, x, y);
}
extern fn textUtf8(strPtr: [*]const u8, strLen: usize, x: i32, y: i32) void;

/// Draws a vertical line
pub extern fn vline(x: i32, y: i32, len: u32) void;

/// Draws a horizontal line
pub extern fn hline(x: i32, y: i32, len: u32) void;

// ┌───────────────────────────────────────────────────────────────────────────┐
// │                                                                           │
// │ Sound Functions                                                           │
// │                                                                           │
// └───────────────────────────────────────────────────────────────────────────┘

/// Plays a sound tone.
pub extern fn tone(frequency: u32, duration: u32, volume: u32, flags: u32) void;

pub const TONE_PULSE1: u32 = 0;
pub const TONE_PULSE2: u32 = 1;
pub const TONE_TRIANGLE: u32 = 2;
pub const TONE_NOISE: u32 = 3;
pub const TONE_MODE1: u32 = 0;
pub const TONE_MODE2: u32 = 4;
pub const TONE_MODE3: u32 = 8;
pub const TONE_MODE4: u32 = 12;
pub const TONE_PAN_LEFT: u32 = 16;
pub const TONE_PAN_RIGHT: u32 = 32;

// ┌───────────────────────────────────────────────────────────────────────────┐
// │                                                                           │
// │ Storage Functions                                                         │
// │                                                                           │
// └───────────────────────────────────────────────────────────────────────────┘

/// Reads up to `size` bytes from persistent storage into the pointer `dest`.
pub extern fn diskr(dest: [*]u8, size: u32) u32;

/// Writes up to `size` bytes from the pointer `src` into persistent storage.
pub extern fn diskw(src: [*]const u8, size: u32) u32;

// ┌───────────────────────────────────────────────────────────────────────────┐
// │                                                                           │
// │ Other Functions                                                           │
// │                                                                           │
// └───────────────────────────────────────────────────────────────────────────┘

/// Prints a message to the debug console.
pub fn trace(x: []const u8) void {
    traceUtf8(x.ptr, x.len);
}
extern fn traceUtf8(strPtr: [*]const u8, strLen: usize) void;

/// Use with caution, as there's no compile-time type checking.
///
/// * %c, %d, and %x expect 32-bit integers.
/// * %f expects 64-bit floats.
/// * %s expects a *zero-terminated* string pointer.
///
/// See https://github.com/aduros/wasm4/issues/244 for discussion and type-safe
/// alternatives.
pub extern fn tracef(x: [*:0]const u8, ...) void;

/// zig powered formatted print with type safety at compile time.
/// `extra_len` specifies how many characteres you will need at most, on addition to the format string length
/// 
/// look at `std.fmt.format` to see all format options available.
/// common formatting types:
/// - {}: default formatting (numbers and bools)
/// - {any}: default debug formatting (tuples, arrays, struct)
/// - {s}: format slice as string
/// - {d}: format number as decimal
/// - {x}: format number as hexadecimal
/// - {b}: format number as binary
/// - {d:0>8.2}: format number as decimal with 2 digits of precision, and align to the right
/// 
/// on custom types, you can specify a function in the format
/// ```
/// pub fn format(value: ?, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void
/// ```
/// where ? is the custom type.
pub fn print(comptime extra_len: usize, comptime fmt: []const u8, args: anytype) void {
  var str = [_]u8{ 0 } ** (fmt.len + extra_len);
  var stream = std.io.fixedBufferStream(&str);
  const writer = stream.writer();
  writer.print(fmt, args) catch |err| {
    trace("failed to print:");
    trace(@errorName(err));
    trace(fmt);
  };
  trace(&str);
}