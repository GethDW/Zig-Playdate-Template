const std = @import("std");
const builtin = @import("builtin");
const is_simulated = @import("config").is_simulated;
const pdapi = @import("playdate_api_definitions.zig");
const main = @import("main.zig");

fn call(comptime name: []const u8) void {
    if (@hasDecl(main, name)) {
        const f = @field(main, name);
        f() catch |e| {
            pdapi.system.err("error: in " ++ name ++ " (%s)", @errorName(e).ptr);
            switch (builtin.mode) {
                .Debug, .ReleaseSafe => @panic(name ++ " failed"),
                else => {},
            }
        };
    }
}
pub export fn eventHandler(playdate: *pdapi.PlaydateAPI, event: pdapi.system.Event, _: u32) callconv(.C) c_int {
    switch (event) {
        .Init => {
            pdapi.init(playdate);
            call("init");
            if (@hasDecl(main, "update")) {
                playdate.system.setUpdateCallback(update, null);
            }
        },
        .InitLua => call("initLua"),
        .Lock => call("lock"),
        .Unlock => call("unluck"),
        .Pause => call("pause"),
        .Resume => call("resume"),
        .Terminate => call("terminate"),
        // TODO
        .KeyPressed, .KeyReleased => {},
        .LowPower => call("lowPower"),
    }
    return 0;
}

fn update(_: ?*anyopaque) callconv(.C) c_int {
    call("update");
    return 1;
}
