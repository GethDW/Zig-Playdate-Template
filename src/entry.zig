const std = @import("std");
const builtin = @import("builtin");
const is_simulated = @import("config").is_simulated;
const api = @import("playdate");
const raw = @import("playdate_raw");
const main = @import("@main");

fn call(comptime name: []const u8) void {
    if (@hasDecl(main, name)) {
        const f = @field(main, name);
        f() catch |e| {
            api.system.err("error: in " ++ name ++ " (%s)", @errorName(e).ptr);
            switch (builtin.mode) {
                .Debug, .ReleaseSafe => @panic(name ++ " failed"),
                else => {},
            }
        };
    }
}
pub export fn eventHandler(playdate: *raw.PlaydateAPI, event: raw.PDSystemEvent, _: u32) callconv(.C) c_int {
    switch (event) {
        .EventInit => {
            api.init(playdate);
            call("init");
            if (@hasDecl(main, "update")) {
                playdate.system.setUpdateCallback(update, null);
            }
        },
        .EventInitLua => call("initLua"),
        .EventLock => call("lock"),
        .EventUnlock => call("unluck"),
        .EventPause => call("pause"),
        .EventResume => call("resume"),
        .EventTerminate => call("terminate"),
        // TODO
        .EventKeyPressed, .EventKeyReleased => {},
        .EventLowPower => call("lowPower"),
    }
    return 0;
}

fn update(_: ?*anyopaque) callconv(.C) c_int {
    call("update");
    return 1;
}
