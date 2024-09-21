const std = @import("std");

pub fn build(b: *std.Build) void {
    // We build a binary for testing and the actual module for use
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "snek",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // For setting env vars using C
    exe.linkLibC();
    b.installArtifact(exe);

    // Module setup
    _ = b.addModule("snek", .{ .root_source_file = b.path("src/main.zig") });
    var lib_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .optimize = optimize,
    });

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&lib_tests.step);

    // Export the library module
    _ = b.addModule("snek", .{
        .root_source_file = b.path("src/lib.zig"),
    });
}
