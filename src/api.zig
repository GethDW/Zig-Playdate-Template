const std = @import("std");
const builtin = @import("builtin");
const raw = @import("playdate_raw");
pub const sprite = @import("api/sprite.zig");
pub const graphics = @import("api/graphics.zig");
pub const system = @import("api/system.zig");
pub const file = @import("api/filesystem.zig");
pub const lua = @import("api/lua.zig");
const plt = @import("api/plt.zig");

pub const sdk_version = @import("config").sdk_version;
pub fn sdkIsAtLeast(major: usize, minor: usize, patch: usize) bool {
    const version = std.SemanticVersion{
        .major = major,
        .minor = minor,
        .patch = patch,
    };
    return sdk_version.order(version) != .lt;
}
pub fn init(pd: *raw.PlaydateAPI) void {
    plt.init(pd);
    system.log = plt.pd.system_logToConsole;
    system.err = plt.pd.system_error;
}
