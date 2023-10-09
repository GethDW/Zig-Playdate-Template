const pdapi = @import("../playdate_api_definitions.zig");
const system = pdapi.system;
const graphics = pdapi.graphics;

var vid: *const PlaydateVideo = undefined;
pub fn init(pdvid: *const PlaydateVideo) void {
    vid = pdvid;
}

pub const VideoPlayer = opaque {
    pub fn load(path: [*:0]const u8) error{LoadFail}!*VideoPlayer {
        return vid.loadVideo(path) orelse error.LoadFail;
    }

    pub fn free(self: *VideoPlayer) void {
        vid.freePlayer(self);
    }

    pub fn setContext(self: *VideoPlayer, bitmap: *graphics.Bitmap) error{ContextFail}!void {
        if (vid.setContext(self, bitmap) != 0) {
            system.log("error: %s", vid.getError());
            return error.LoadFail;
        }
    }

    pub fn useScreenContext(self: *VideoPlayer) void {
        vid.useScreenContext(self);
    }

    pub fn renderFrame(self: *VideoPlayer, frame: u16) error{RenderError}!void {
        if (vid.renderFrame(self, @intCast(frame)) != 0) {
            system.log("error: %s", vid.getError());
            return error.LoadFail;
        }
    }

    pub const Info = struct {
        width: u16,
        height: u16,
        framerate: f32,
        frame_count: u16,
        current_frame: u16,
    };
    pub fn getInfo(self: *const VideoPlayer) Info {
        var width: c_int, var height: c_int, var framerate: f32, var frame_count: c_int, var current_frame: c_int = .{undefined} ** 5;
        vid.getInfo(@ptrCast(@constCast(self)), &width, &height, &framerate, &frame_count, &current_frame);
        return Info{
            .width = @intCast(width),
            .height = @intCast(height),
            .framerate = framerate,
            .frame_count = @intCast(frame_count),
            .current_frame = @intCast(current_frame),
        };
    }

    pub fn getContext(self: *VideoPlayer) error{ContextFail}!*graphics.Bitmap {
        return vid.getContext(self) orelse error.ContextFail;
    }
};

pub const PlaydateVideo = extern struct {
    loadVideo: *const fn ([*:0]const u8) callconv(.C) ?*VideoPlayer,
    freePlayer: *const fn (*VideoPlayer) callconv(.C) void,
    setContext: *const fn (*VideoPlayer, *graphics.Bitmap) callconv(.C) c_int,
    useScreenContext: *const fn (*VideoPlayer) callconv(.C) void,
    renderFrame: *const fn (*VideoPlayer, c_int) callconv(.C) c_int,
    getError: *const fn (*VideoPlayer) callconv(.C) [*:0]const u8,
    getInfo: *const fn (*VideoPlayer, width: ?*c_int, height: ?*c_int, framerate: ?*f32, frame_count: ?*c_int, current_frame: ?*c_int) callconv(.C) void,
    getContext: *const fn (*VideoPlayer) callconv(.C) ?*graphics.Bitmap,
};
