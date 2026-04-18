const std = @import("std");
const rlz = @import("raylib_zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });
    const raylib_mod = raylib_dep.module("raylib");
    const raylib_artifact = raylib_dep.artifact("raylib");

    const resources_mod = b.createModule(.{
        .root_source_file = b.path("resources.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addImport("raylib", raylib_mod);
    exe_mod.addImport("resources", resources_mod);

    if (target.query.os_tag == .emscripten) {
        const wasm = b.addLibrary(.{
            .name = "index",
            .root_module = exe_mod,
        });

        const install_dir: std.Build.InstallDir = .{ .custom = "web" };
        const flags = rlz.emsdk.emccDefaultFlags(b.allocator, .{
            .optimize = optimize,
            .asyncify = true,
        });
        var settings = rlz.emsdk.emccDefaultSettings(b.allocator, .{
            .optimize = optimize,
        });
        settings.put("STACK_SIZE", "1048576") catch @panic("OOM");
        settings.put("INITIAL_MEMORY", "67108864") catch @panic("OOM");
        settings.put("ALLOW_MEMORY_GROWTH", "1") catch @panic("OOM");

        const emcc_step = rlz.emsdk.emccStep(b, raylib_artifact, wasm, .{
            .optimize = optimize,
            .flags = flags,
            .settings = settings,
            .install_dir = install_dir,
        });

        b.getInstallStep().dependOn(emcc_step);

        const emrun_step = rlz.emsdk.emrunStep(
            b,
            b.getInstallPath(install_dir, "index.html"),
            &.{},
        );
        emrun_step.dependOn(emcc_step);

        const run_step = b.step("run", "Run zig-rodents-revenge in browser");
        run_step.dependOn(emrun_step);
        return;
    }

    const exe = b.addExecutable(.{
        .name = "zig-rodents-revenge",
        .root_module = exe_mod,
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run zig-rodents-revenge");
    run_step.dependOn(&run_cmd.step);
}
