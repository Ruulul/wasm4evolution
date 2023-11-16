const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    const exe_folder = args[1];
    const mode = if (args.len > 2) args[2] else null;
    const exe_path = try std.mem.concat(allocator, u8, &.{ exe_folder, "/bin/cart.wasm" });
    defer allocator.free(exe_path);

    var process = std.ChildProcess.init(&.{ "w4", mode orelse "run", exe_path }, allocator);
    try process.spawn();
    _ = try process.wait();
}
