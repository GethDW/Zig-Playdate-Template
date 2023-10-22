# playdate-zig
A [Zig](https://ziglang.org) package for building games for the [Playdate](https://play.date).

## Usage
First, your `build.zig.zon` should look something like this:
```zig
.{
    .name = "example",
    .version = "0.0.0",
    .paths = .{ "." },
    .dependencies = .{
        .playdate = .{
            .url = "git+https://github.com/GethDW/playdate-zig#[LATEST_COMMIT]",
            .hash = "[HASH_OF_CONTENTS]", // Note: you can omit the `hash` field then run `zig build`
                                          // and the resulting error will tell you what the hash should be.
        }
    },
}
```
Then, in your `build.zig`:
```zig
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
    pdx.addFile(.{ .path = "assets/icon.png" }, "icon.png");

    pdx.install(b);

    const run_step = b.step("run", "Run in PlaydateSimulator");
    run_step.dependOn(&pdx.addRun().step);
    run_step.dependOn(b.getInstallStep);
}
```
This build script will use the `PLAYDATE_SDK_PATH` environment variable to locate the PlaydateSDK, but you can modify the above in a few ways to avoid this:
```zig
const playdate = b.dependency("playdate", .{
     .sdk_path = @as([]const u8, "/path/to/sdk"),
});
```
Or allow users of you build script to provide a path with:
```zig
const playdate = b.dependency("playdate", .{
     .sdk_path = b.options([]const u8, "sdk_path", "Path to PlaydateSDK") orelse b.env_map.get("PLAYDATE_SDK_PATH").?,
});
```
Now in `src/main.zig` you can make your game:
```zig
const pd = @import("playdate");
const Sprite = pd.sprite.Sprite;
const Bitmap = pd.graphics.Bitmap;

// pd.sprite.AnySprite can be used for sprites without userdata.
var spr: *Sprite(u32) = undefined;
pub fn init() !void {
    const allocator = pd.system.allocator();
    spr = try Sprite(u32).new();
    const x = try allocator.create(u32);
    spr.setUserdata(x);
    const image = try Bitmap.load("player");
    spr.setImage(image, .Unflipped);
    spr.add(); 
}
pub fn update() !void {
    // add your own code here.
}
pub fn terminate() !void {
    const bitmap = spr.getImage.?;
    bitmap.destroy();
    spr.destroy();
}
```

## WARNING
- Not everything has been tested
    - The underlying bindings to the C API are not auto-generated from the C headers, and so could be incorrect. They were originally made with `zig translate-c` by [DanB91](https://github.com/DanB91/Zig-Playdate-Template) and were then modified by Dan and myself. Please open a bug report if any issues arise.
- Not Officially Supported
    - While it works very well due to its interoperability with C, Zig is not officially supported on the Playdate.  If you are having any issues, feel free to open a bug report here.
- Be Mindful Of The Stack
    - You only get 10KB of stack space. That's it. Zig's standard library was not designed with this limitation in mind, so you're mileage may vary.

## Requirements
- Either macOS, Windows, or Linux. These are the only platforms supported by the SDK and so are the only ones supported by this project.
- [Zig](https://ziglang.org/download/). Since Zig is under very active development, this project will target the latest dev release for the time being.
- [Playdate SDK](https://play.date/dev/). With any luck this project can support different versions of the SDK at the same time. If you are running a release older than `2.0.0` and experience any issues because of that, please open a bug report here.


# Thanks
Thank go to [DabB91](https://github.com/DanB91) for the [original](https://github.com/DanB91/Zig-Playdate-Template) zig bindings to the playdate C API and the build script for compiling to the playdate hardware.
