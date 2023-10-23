const pdapi = @import("../api.zig");
const plt = @import("plt.zig");
const system = pdapi.system;
const graphics = pdapi.graphics;

const raw = @import("playdate_raw");

pub const VideoPlayer = opaque {
    pub fn load(path: [*:0]const u8) error{LoadFail}!*VideoPlayer {
        return if (plt.pd.graphics_video_loadVideo(path)) |ptr| @ptrCast(ptr) else error.LoadFail;
    }

    pub fn destroy(self: *VideoPlayer) void {
        plt.pd.graphics_video_freePlayer(@ptrCast(self));
    }

    pub fn setContext(self: *VideoPlayer, bitmap: *graphics.Bitmap) error{ContextFail}!void {
        if (plt.pd.graphics_video_setContext(@ptrCast(self), bitmap) != 0) {
            system.log("error: %s", plt.pd.graphics_video_getError());
            return error.LoadFail;
        }
    }

    pub fn useScreenContext(self: *VideoPlayer) void {
        plt.pd.graphics_video_useScreenContext(@ptrCast(self));
    }

    pub fn renderFrame(self: *VideoPlayer, frame: u16) error{RenderError}!void {
        if (plt.pd.graphics_video_renderFrame(@ptrCast(self), @intCast(frame)) != 0) {
            system.log("error: %s", plt.pd.graphics_video_getError());
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
        plt.pd.graphics_video_getInfo(@ptrCast(@constCast(self)), &width, &height, &framerate, &frame_count, &current_frame);
        return Info{
            .width = @intCast(width),
            .height = @intCast(height),
            .framerate = framerate,
            .frame_count = @intCast(frame_count),
            .current_frame = @intCast(current_frame),
        };
    }

    pub fn getContext(self: *VideoPlayer) error{ContextFail}!*graphics.Bitmap {
        return plt.pd.graphics_video_getContext(@ptrCast(self)) orelse error.ContextFail;
    }
};
