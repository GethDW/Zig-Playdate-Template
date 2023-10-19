const std = @import("std");
const builtin = @import("builtin");
const raw = @import("playdate_raw");
pub const sprite = @import("api/sprite.zig");
pub const graphics = @import("api/graphics.zig");
pub const system = @import("api/system.zig");
pub const filesystem = @import("api/filesystem.zig");
pub const lua = @import("api/lua.zig");

pub fn init(pd: *raw.PlaydateAPI) void {
    system.init(pd.system);
    sprite.init(pd.sprite);
    graphics.init(pd.graphics);
    filesystem.init(pd.file);
    lua.init(pd.lua);
}
