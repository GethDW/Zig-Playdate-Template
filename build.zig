const std = @import("std");

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{});

    const pdx = buildPDX(b, .{
        .name = "example",
        .root_source_file = .{ .path = "src/entry.zig" },
        .optimize = optimize,
        .pdxinfo = .{ .path = "assets/pdxinfo" },
    });

    {
        var src = try b.build_root.handle.openIterableDir("src", .{});
        defer src.close();
        var iter = src.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.eql(u8, std.fs.path.extension(entry.name), ".lua")) continue;
            const file_source = .{ .path = b.pathJoin(&.{ "src", entry.name }) };
            pdx.addFile(file_source, entry.name);
        }
    }

    {
        var assets = try b.build_root.handle.openIterableDir("assets", .{});
        defer assets.close();
        var iter = assets.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind != .file) continue;
            const file_source = .{ .path = b.pathJoin(&.{ "assets", entry.name }) };
            pdx.addFile(file_source, entry.name);
        }
    }

    b.getInstallStep().dependOn(&pdx.addInstall().step);

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&pdx.addRun().step);
    run_step.dependOn(b.getInstallStep());
}

const Build = std.Build;
const LazyPath = Build.LazyPath;
const Step = Build.Step;
const os_tag = @import("builtin").os.tag;
const lib_ext = switch (os_tag) {
    .windows => ".dll",
    .macos => ".dylib",
    .linux => ".so",
    else => @panic("Unsupported OS"),
};
pub const Options = struct {
    name: []const u8,
    root_source_file: LazyPath,
    optimize: std.builtin.OptimizeMode,
    pdxinfo: LazyPath,
    sdk_path: ?[]const u8 = null,
};
pub fn buildPDX(b: *Build, options: Options) *PlaydateExecutable {
    const link_map = comptime std.fs.path.dirname(@src().file).? ++ "/link_map.ld";
    const playdate_target = std.zig.CrossTarget.parse(.{
        .arch_os_abi = "thumb-freestanding-eabihf",
        .cpu_features = "cortex_m7-fp64-fp_armv8d16-fpregs64-vfp2-vfp3d16-vfp4d16",
    }) catch unreachable;

    const self = b.allocator.create(PlaydateExecutable) catch @panic("OOM");
    self.builder = b;
    self.sdk_path =
        options.sdk_path orelse
        self.builder.env_map.get("PLAYDATE_SDK_PATH") orelse
        @panic("missing sdk path");
    self.name = options.name;
    self.write = self.builder.addWriteFiles();
    self.write.step.name = self.builder.fmt("write {s}", .{self.name});
    self.host = self.builder.addSharedLibrary(.{
        .name = "host",
        .root_source_file = options.root_source_file,
        .optimize = options.optimize,
        .target = .{},
    });
    self.pd_exe = self.builder.addExecutable(.{
        .name = "pd",
        .root_source_file = options.root_source_file,
        .target = playdate_target,
        .optimize = options.optimize,
    });
    self.pd_exe.force_pic = true;
    self.pd_exe.link_emit_relocs = true;
    self.pd_exe.setLinkerScriptPath(.{ .path = link_map });
    if (options.optimize == .ReleaseFast) {
        self.pd_exe.omit_frame_pointer = true;
    }

    _ = self.write.addCopyFile(self.host.getOutputSource(), "pdex" ++ lib_ext);
    _ = self.write.addCopyFile(self.pd_exe.getOutputSource(), "pdex.elf");
    _ = self.write.addCopyFile(options.pdxinfo, "pdxinfo");

    const compiler_path = self.builder.pathJoin(&.{ self.sdk_path, "bin", if (os_tag == .windows) "pdc.exe" else "pdc" });
    const pdc = self.builder.addSystemCommand(&.{ compiler_path, "--skip-unknown" });
    pdc.setName(self.builder.fmt("pdc {s}", .{self.name}));
    pdc.addDirectorySourceArg(self.write.getDirectory());
    self.pdx = pdc.addOutputFileArg(self.builder.fmt("{s}.pdx", .{options.name}));

    return self;
}

pub const PlaydateExecutable = struct {
    builder: *Build,
    sdk_path: []const u8,
    name: []const u8,
    pdx: LazyPath,
    host: *Step.Compile,
    pd_exe: *Step.Compile,
    write: *Step.WriteFile,
    simulate: *Step.Run,

    pub fn addAnonymousModule(self: *PlaydateExecutable, name: []const u8, options: Build.CreateModuleOptions) void {
        self.host.addAnonymousModule(name, options);
        self.pd_exe.addAnonymousModule(name, options);
    }
    pub fn addModule(self: *PlaydateExecutable, name: []const u8, module: *Build.Module) void {
        self.host.addModule(name, module);
        self.pd_exe.addModule(name, module);
    }
    pub fn addRun(self: *PlaydateExecutable) *Step.Run {
        const simulator_path = switch (os_tag) {
            .linux => self.builder.pathJoin(&.{ self.sdk_path, "bin", "PlaydateSimulator" }),
            .macos => "open", // `open` focuses the window, while running the simulator directry doesn't.
            .windows => self.builder.pathJoin(&.{ self.sdk_path, "bin", "PlaydateSimulator.exe" }),
            else => @panic("Unsupported OS"),
        };
        const run_cmd = self.builder.addSystemCommand(&.{simulator_path});
        run_cmd.setName(self.builder.fmt("simulate {s}", .{self.name}));
        run_cmd.addDirectorySourceArg(self.pdx);
        return run_cmd;
    }
    pub fn addInstall(self: *PlaydateExecutable) *Step.InstallDir {
        return self.builder.addInstallDirectory(.{
            .source_dir = self.pdx,
            .install_dir = .prefix,
            .install_subdir = self.builder.fmt("{s}.pdx", .{self.name}),
        });
    }
    pub fn getOutput(self: *PlaydateExecutable) LazyPath {
        return self.pdx;
    }

    /// Adds a file to the directory used by `pdc`.
    pub fn addFile(self: *PlaydateExecutable, source: LazyPath, sub_path: []const u8) void {
        _ = self.write.addCopyFile(source, sub_path);
    }
};
