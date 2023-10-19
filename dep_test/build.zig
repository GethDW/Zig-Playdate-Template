const std = @import("std");
const playdate_build = @import("playdate");

pub fn build(b: *std.Build) void {
    const playdate = b.dependency("playdate", .{});

    const optimize = b.standardOptimizeOption(.{});

    const pdx = playdate_build.buildPDX(b, playdate, .{
        .name = "example",
        .root_source_file = .{ .path = "src/main.zig" },
        .optimize = optimize,
        .pdxinfo = .{ .path = "src/pdxinfo" },
    });

    pdx.install(b);

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&pdx.addRun().step);
    run_step.dependOn(b.getInstallStep());
}
