const pdapi = @import("../api.zig");
const graphics = pdapi.graphics;
const sprite = pdapi.sprite;

const raw = @import("playdate_raw");
pub var lua: *const raw.PlaydateLua = undefined;
pub fn init(pdlua: *const raw.PlaydateLua) void {
    lua = pdlua;
}

pub fn get(comptime T: type, pos: i32) T {
    return switch (@typeInfo(T)) {
        .Optional => |info| if (lua.argIsNil(pos) == 1) null else getNative(info.child, pos),
        else => get(T, pos),
    };
}

fn getNative(comptime T: type, pos: i32) T {
    switch (@typeInfo(T)) {
        .Bool => |_| return lua.getArgBool(pos) == 1,
        .Float => |_| return lua.getArgFloat(pos),
        .Int => |_| return @intCast(lua.getArgInt(pos)),
        else => switch (T) {
            sprite.Sprite => return lua.getSprite(pos).?,
            graphics.Bitmap => return lua.getBitmap(pos).?,
            [*:0]const u8 => return lua.getArgString(pos),
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
    if (lua.registerClass(
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
