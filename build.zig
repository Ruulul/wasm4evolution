const std = @import("std");

pub fn build(b: *std.Build) !void {
    const optimize: std.builtin.OptimizeMode = .ReleaseSmall;

    const lib = b.addExecutable(.{
        .name = "cart",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = .{ .cpu_arch = .wasm32, .os_tag = .freestanding  },
        .optimize = optimize,
    });

    lib.entry = .disabled;
    lib.initial_memory = 65536;
    lib.max_memory = 65536;
    lib.stack_size = 14752;

    // Export WASM-4 symbols
    lib.export_symbol_names = &[_][]const u8{"start", "update" };

    const runner = b.addExecutable(.{
        .name = "invoke",
        .root_source_file = .{ .path = "src/invoke.zig" },
    });

    b.installArtifact(lib);
    b.installArtifact(runner);

    const run_cmd = b.addRunArtifact(runner);
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.addArg(b.install_path);
    if (b.args) |args| run_cmd.addArgs(args);
    
    const run_step = b.step("run", "run the program");
    run_step.dependOn(&run_cmd.step);
}