const std = @import("std");

/// example usage:
/// ```zig
/// const std = @import("std");
/// const playdate_build = @import("playdate");
/// pub fn build(b: *std.Build) void {
/// 	const playdate = b.dependency("playdate", .{});
///
/// 	const optimize = b.standardOptimizeOption(.{});
///
/// 	const pdx = playdate_build.buildPDX(b, playdate, .{
/// 		.name = "example",
/// 		.root_source_file = .{ .path = "src/main.zig" },
/// 		.optimize = optimize,
/// 		.pdxinfo = .{ .path = "src/pdxinfo" },
/// 	});
/// 	pdx.addFile(.{ .path = "assets/icon.png" });
///
///		pdx.install(b);
///
/// 	const run_step = b.step("run", "Run the app");
/// 	run_step.dependOn(&pdx.addRun().step);
/// 	run_step.dependOn(b.getInstallStep());
/// }
/// ```
pub fn buildPDX(
    b: *Build,
    /// This should be the same as the dependency that
    /// this funcion was imported from.
    playdate_zig: *Build.Dependency,
    options: PlaydateExecutable.Options,
) *PlaydateExecutable {
    return PlaydateExecutable.create(
        b,
        playdate_zig.module("playdate_raw"),
        playdate_zig.module("playdate"),
        playdate_zig.path("link_map.ld"),
        playdate_zig.path("src/entry.zig"),
        options,
    );
}

pub fn build(b: *Build) !void {
    const optimize = b.standardOptimizeOption(.{});

    const raw_api = b.addModule("playdate_raw", .{
        .source_file = .{ .path = "src/api/raw.zig" },
    });
    const api = b.addModule("playdate", .{
        .source_file = .{ .path = "src/api.zig" },
        .dependencies = &.{.{ .name = "playdate_raw", .module = raw_api }},
    });

    const pdx = PlaydateExecutable.create(
        b,
        raw_api,
        api,
        LazyPath.relative("link_map.ld"),
        .{ .path = "src/entry.zig" },
        .{
            .name = "example",
            .root_source_file = .{ .path = "src/main.zig" },
            .optimize = optimize,
            .pdxinfo = .{ .path = "src/pdxinfo" },
        },
    );

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

    pdx.install(b);

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&pdx.addRun().step);
    run_step.dependOn(b.getInstallStep());
}

const Build = std.Build;
const LazyPath = Build.LazyPath;
const Step = Build.Step;
const Compile = Step.Compile;
pub const PlaydateExecutable = struct {
    builder: *Build,
    /// Path to PlaydateSDK
    sdk_path: []const u8,
    /// The name of the resulting pdx
    name: []const u8,
    /// The resulting pdx
    pdx: LazyPath,
    /// The pdc command used to make the pdx
    pdc: *Step.Run,
    /// The dynamic library used by PlaydateSimulator
    host: *Step.Compile,
    /// The binary used on the Playdate hardware
    pdex: *Step.Compile,
    /// The Source directory used in the pdc command
    write: *Step.WriteFile,

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
    pub fn create(
        b: *Build,
        raw_api: *Build.Module,
        api: *Build.Module,
        link_map: LazyPath,
        entry: LazyPath,
        options: Options,
    ) *PlaydateExecutable {
        const playdate_target = std.zig.CrossTarget.parse(.{
            .arch_os_abi = "thumb-freestanding-eabihf",
            .cpu_features = "cortex_m7-fp64-fp_armv8d16-fpregs64-vfp2-vfp3d16-vfp4d16",
        }) catch unreachable;

        const self = b.allocator.create(PlaydateExecutable) catch @panic("OOM");
        self.* = .{
            .builder = b,
            .sdk_path = if (options.sdk_path) |p| b.dupe(p) else self.builder.env_map.get("PLAYDATE_SDK_PATH") orelse
                @panic("missing sdk path"),
            .name = options.name,
            .write = self.builder.addWriteFiles(),
            .host = self.builder.addSharedLibrary(.{
                .name = "host",
                .root_source_file = entry,
                .target = .{},
                .optimize = options.optimize,
            }),
            .pdex = self.builder.addExecutable(.{
                .name = "pd",
                .root_source_file = entry,
                .target = playdate_target,
                .optimize = options.optimize,
            }),
            .pdx = undefined,
            .pdc = undefined,
        };
        const module_options = .{
            .source_file = options.root_source_file,
            .dependencies = &.{
                .{ .name = "playdate", .module = api },
                .{ .name = "playdate_raw", .module = raw_api },
            },
        };
        self.pdex.addAnonymousModule("@main", module_options);
        self.pdex.addModule("playdate_raw", raw_api);
        self.pdex.addModule("playdate", api);
        self.host.addAnonymousModule("@main", module_options);
        self.host.addModule("playdate_raw", raw_api);
        self.host.addModule("playdate", api);

        self.write.step.name = self.builder.fmt("write {s}", .{self.name});
        self.pdex.force_pic = true;
        self.pdex.link_emit_relocs = true;
        self.pdex.setLinkerScriptPath(link_map);
        if (options.optimize == .ReleaseFast) {
            self.pdex.omit_frame_pointer = true;
        }

        _ = self.write.addCopyFile(self.host.getOutputSource(), "pdex" ++ lib_ext);
        _ = self.write.addCopyFile(self.pdex.getOutputSource(), "pdex.elf");
        _ = self.write.addCopyFile(options.pdxinfo, "pdxinfo");

        const compiler_path = self.builder.pathJoin(&.{ self.sdk_path, "bin", if (os_tag == .windows) "pdc.exe" else "pdc" });
        self.pdc = self.builder.addSystemCommand(&.{compiler_path});
        self.pdc.step.dependOn(CheckSDKVersion.create(b, self.sdk_path));
        self.pdc.setName(self.builder.fmt("pdc {s}", .{self.name}));
        self.pdc.addDirectorySourceArg(self.write.getDirectory());
        self.pdx = self.pdc.addOutputFileArg(self.builder.fmt("{s}.pdx", .{options.name}));

        return self;
    }

    /// Run the pdx in PlaydateSimulator.
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

    /// Installs the pdx to the prefix directory.
    pub fn addInstall(self: *PlaydateExecutable) *Step.InstallDir {
        return self.builder.addInstallDirectory(.{
            .source_dir = self.pdx,
            .install_dir = .prefix,
            .install_subdir = self.builder.fmt("{s}.pdx", .{self.name}),
        });
    }

    pub fn install(self: *PlaydateExecutable, b: *Build) void {
        b.getInstallStep().dependOn(&self.addInstall().step);
    }

    pub fn getOutput(self: *PlaydateExecutable) LazyPath {
        return self.pdx;
    }

    /// Adds a file to the directory used by pdc.
    pub fn addFile(self: *PlaydateExecutable, source: LazyPath, sub_path: []const u8) void {
        _ = self.write.addCopyFile(source, sub_path);
    }
};

const CheckSDKVersion = struct {
    step: Step,
    sdk_path: []const u8,

    pub fn create(b: *Build, sdk_path: []const u8) *Step {
        const self = b.allocator.create(CheckSDKVersion) catch @panic("OOM");
        self.* = .{
            .step = Step.init(.{
                .id = .custom,
                .name = "version",
                .owner = b,
                .makeFn = makeFn,
            }),
            .sdk_path = sdk_path,
        };
        return &self.step;
    }

    fn makeFn(step: *Step, _: *std.Progress.Node) anyerror!void {
        const tested_version = std.SemanticVersion.parse("2.0.3") catch unreachable;
        const self = @fieldParentPtr(CheckSDKVersion, "step", step);
        const b = step.owner;
        const version_path = b.pathJoin(&.{ self.sdk_path, "VERSION.txt" });
        const file = std.fs.openFileAbsolute(version_path, .{}) catch |e|
            return step.fail("failed to check PlaydateSDK version: {s}", .{@errorName(e)});
        const txt = file.readToEndAlloc(b.allocator, 100) catch |e|
            return step.fail("failed to check PlaydateSDK version: {s}", .{@errorName(e)});
        const str = txt[0 .. std.mem.indexOfScalar(u8, txt, '\n') orelse txt.len];
        const version = std.SemanticVersion.parse(str) catch |e|
            return step.fail("invalid PlaydateSDK version {s}: {s}", .{ str, @errorName(e) });
        switch (version.order(tested_version)) {
            .gt, .eq => {},
            .lt => return step.fail("PlaydateSDK version is insufficient: found {}, needs {}", .{ version, tested_version }),
        }
    }
};
