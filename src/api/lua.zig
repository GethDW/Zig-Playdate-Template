const pdapi = @import("../api.zig");
const plt = @import("plt.zig");
const graphics = pdapi.graphics;
const sprite = pdapi.sprite;

const raw = @import("playdate_raw");

pub fn get(comptime T: type, pos: i32) T {
    return switch (@typeInfo(T)) {
        .Optional => |info| if (plt.pd.lua_argIsNil(pos) == 1) null else getNative(info.child, pos),
        else => get(T, pos),
    };
}

fn getNative(comptime T: type, pos: i32) T {
    switch (@typeInfo(T)) {
        .Bool => |_| return plt.pd.lua_getArgBool(pos) == 1,
        .Float => |_| return plt.pd.lua_getArgFloat(pos),
        .Int => |_| return @intCast(plt.pd.lua_getArgInt(pos)),
        else => switch (T) {
            sprite.Sprite => return plt.pd.lua_getSprite(pos).?,
            graphics.Bitmap => return plt.pd.lua_getBitmap(pos).?,
            [*:0]const u8 => return plt.pd.lua_getArgString(pos),
            else => @compileError("unsupported type in lua " ++ @typeName(T)),
        },
    }
}

pub const Reg = raw.LuaReg;
pub const State = raw.LuaState;
pub const ClassMethod = struct {
    []const u8,
    (fn () c_int),
};
pub fn registerClass(
    comptime name: []const u8,
    comptime methods: []const ClassMethod,
    comptime is_static: bool,
) error{RegisterClassFail}!void {
    comptime var regs: [methods.len:Reg.End]Reg = undefined;
    inline for (&regs, methods) |*reg, meth| {
        const method_name, const method = meth;
        reg.* = .{
            .name = @ptrCast(method_name ++ &[_]u8{0}),
            .func = struct {
                pub fn f(_: *State) callconv(.C) c_int {
                    return method();
                }
            }.f,
        };
    }

    var err: [*:0]const u8 = undefined;
    if (plt.pd.lua_registerClass(
        @ptrCast(name ++ &[_]u8{0}),
        &regs,
        null,
        @intFromBool(is_static),
        &err,
    ) == 0) {
        pdapi.system.log("error: %s", err);
        return error.RegisterClassFail;
    }
}
