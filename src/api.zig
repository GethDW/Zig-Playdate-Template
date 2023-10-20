const std = @import("std");
const builtin = @import("builtin");
const raw = @import("playdate_raw");
pub const sprite = @import("api/sprite.zig");
pub const graphics = @import("api/graphics.zig");
pub const system = @import("api/system.zig");
pub const filesystem = @import("api/filesystem.zig");
pub const lua = @import("api/lua.zig");
const plt = @import("api/plt.zig");

pub fn init(pd: *raw.PlaydateAPI) void {
    plt.init(pd);
    system.log = plt.pd.system_logToConsole;
    system.err = plt.pd.system_error;
}
