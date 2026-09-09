const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zgui_dep = b.dependency("zGUI", .{
        .target = target,
        .optimize = optimize,
    });

    const mod = b.addModule("ray", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "ray",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "ray", .module = mod },
                .{ .name = "zGUI", .module = zgui_dep.module("zGUI") },
                .{ .name = "zGUI_glfw", .module = zgui_dep.module("zGUI_glfw") },
            },
        }),
    });
    exe.root_module.addAnonymousImport("app_font", .{
        .root_source_file = zgui_dep.path("assets/fonts/Inter-Regular.ttf"),
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}
